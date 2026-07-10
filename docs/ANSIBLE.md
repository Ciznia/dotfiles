# Ansible

Ansible is the **preflight** half of this repo. Nix declares the system; Ansible
handles the few things that either can't be committed as plaintext or need to
run imperatively before/around a Nix switch. Right now that's exactly one thing:
restoring the shared **SSH** and **GPG** identity onto a machine.

Everything targets `localhost` (`connection: local`) — Ansible here provisions
the machine you invoke it on, not remote hosts.

## Layout

`ansible.cfg` and `.vault_pass` live at the **repo root**; everything else is
under `ansible/`, laid out per-inventory. Run every command **from the repo root**.

```txt
ansible.cfg                                     # repo root: inventory, roles_path, vault
.vault_pass                                     # repo root: vault password (git-ignored)
ansible/
  inventories/local/
    hosts.yml                                   # localhost, connection: local
    host_vars/localhost.yml                     # pins ansible_python_interpreter
    group_vars/all/all.yml                      # non-secret vars (public key, email…)
    group_vars/all/all.vault.yml                # ENCRYPTED secrets
    group_vars/all/all.vault.yml.example        # template (not auto-loaded)
  playbooks/keys.yml                            # SSH + GPG + password store
  roles/keys/tasks/{ssh,gpg,agent}.yml          # SSH key, rotation-aware GPG, ssh-add
  roles/pass/                                   # re-encrypt pass store on rotation
```

`ansible.cfg` points at `inventories/local/hosts.yml`, so its `group_vars` /
`host_vars` auto-load.

## Running a playbook

Enter the devshell first so `ansible`, `gpg`, and `ssh-keygen` are on PATH:

```bash
nix develop
```

Then, from the repo root:

```bash
ansible-playbook ansible/playbooks/keys.yml            # apply
ansible-playbook ansible/playbooks/keys.yml --check    # dry-run, change nothing
ansible-playbook ansible/playbooks/keys.yml --diff     # show what would change
```

**Tags** let you apply a subset:

| `--tags …` | Runs                                               |
|------------|----------------------------------------------------|
| `ssh`      | SSH key only                                       |
| `gpg`      | GPG import **+** pass re-encrypt (a full rotation) |
| `pass`     | pass re-encrypt only                               |
| `keys`     | SSH + GPG, no pass                                 |
| `agent`    | ssh-add the key into the running agent (startup)   |

```bash
ansible-playbook ansible/playbooks/keys.yml --tags ssh
ansible-playbook ansible/playbooks/keys.yml --tags gpg   # rotate GPG end to end
ansible-playbook ansible/playbooks/keys.yml --tags agent # load key into agent at login
```

The `agent` tasks are tagged `never`, so a normal run (no tags, or `--tags
keys/ssh/gpg/pass`) never touches the agent — only an explicit `--tags agent`
runs them.

**Vault password.** `ansible.cfg` reads it from `.vault_pass` (git-ignored, one
line, `chmod 600`). If that file doesn't exist, either create it or comment out
`vault_password_file` in `ansible.cfg` and add `--ask-vault-pass` to the commands
above.

## Working with the vault

The vault is a single encrypted file,
`ansible/inventories/local/group_vars/all/all.vault.yml`, committed
encrypted-at-rest. It holds the `vault_*` variables (private keys); the matching
non-secret values live beside it in `all.yml`.

```bash
# view — decrypt to stdout, read-only
ansible-vault view ansible/inventories/local/group_vars/all/all.vault.yml

# edit — open $EDITOR on the decrypted content, re-encrypt on save
ansible-vault edit ansible/inventories/local/group_vars/all/all.vault.yml

# create — first time only
ansible-vault create ansible/inventories/local/group_vars/all/all.vault.yml

# rekey — change the vault password
ansible-vault rekey ansible/inventories/local/group_vars/all/all.vault.yml
```

These find the password via `.vault_pass` too; add `--ask-vault-pass` if you
don't use that file.

## Playbooks

### `keys.yml` — SSH, GPG & password store

Restores the **shared** identity — the same private keys on every machine
(NixOS, NixOS-WSL, …), sourced from the vault — and keeps the `pass` store in
sync with it. It runs two roles:

- **`keys`** (tasks split into `ssh.yml` / `gpg.yml`):
  - *SSH* — ensures `~/.ssh` (`0700`), writes the private key to
    `~/.ssh/id_ed25519` (`0600`) from `vault_ssh_private_key`, and the public key
    to `id_ed25519.pub` (`0644`) from `ssh_public_key`.
  - *GPG* — **rotation-aware**: reads the vaulted key's fingerprint (without
    importing) and compares it to the keyring; imports only when they differ,
    then marks the key ultimately trusted. This covers both first install and
    rotation to a new key for the same identity.
  - *agent* (`--tags agent` only) — loads the SSH key into the running
    ssh-agent with `ssh-add`, feeding the passphrase from
    `vault_ssh_passphrase` via an `SSH_ASKPASS` helper so nothing is typed.
    Idempotent (skips if the key's fingerprint is already in `ssh-add -l`) and
    tagged `never`, so only an explicit `--tags agent` runs it. See
    [Loading the key at startup](#loading-the-key-at-startup).
- **`pass`** — keeps `~/.password-store` encrypted to the *current* GPG
  fingerprint. It compares the store's `.gpg-id` to the live key and runs
  `pass init <FPR>` only when they differ, so after a GPG rotation the whole
  store is re-encrypted to the new key. On a shared store the first host
  re-encrypts and pushes; the rest skip once synced.

The playbook only ever **reads** the vault — it never writes back to it. The
SSH key is written *by content* (a re-run reconciles it with the vault), so all
three concerns are fully idempotent.

Variables it uses:

| Variable                                               | Defined in                | Secret? |
|--------------------------------------------------------|---------------------------|---------|
| `ssh_key_type`, `ssh_public_key`, `gpg_email`          | `all.yml`                 | no      |
| `vault_ssh_private_key`, `vault_gpg_private_key`       | `all.vault.yml`           | yes     |
| `vault_ssh_passphrase`, `vault_gpg_passphrase`         | `all.vault.yml`           | yes     |
| `ansible_python_interpreter`                           | `host_vars/localhost.yml` | no      |
| `password_store_dir` (default `~/.password-store`)     | `roles/pass/defaults`     | no      |
| `ssh_askpass_path` (default `~/.ssh/.ansible-askpass`) | `roles/keys/defaults`     | no      |

> **`pass` prerequisites.** Initialize the store with the **fingerprint**
> (`pass init <FPR>`), not the email — an email `.gpg-id` always resolves to the
> newest key and would hide a rotation. And because `pass init` re-encrypts by
> *decrypting* each entry, the GPG agent must be able to unlock the key
> (passphrase prompt / cached agent) when the role runs.

#### Setting the secrets (first machine)

Do this once; afterwards every machine just runs the playbook.

1. Generate (or reuse) the keys — inside `nix develop`:

   ```bash
   ssh-keygen -t ed25519 -C "hosquetgabriel@gmail.com" -f ./id_ed25519
   gpg --full-generate-key            # identity: hosquetgabriel@gmail.com
   ```

2. Put the **public** SSH key into `all.yml` (`ssh_public_key`) — public keys
   aren't secret.

3. Seal the **private** keys into the vault:

   ```bash
   ansible-vault create ansible/inventories/local/group_vars/all/all.vault.yml
   ```

   Paste `vault_ssh_private_key` and `vault_gpg_private_key` as literal `|`
   blocks — see `all.vault.yml.example` for the shape. Get the values from:

   ```bash
   cat ./id_ed25519
   gpg --armor --export-secret-keys hosquetgabriel@gmail.com
   ```

4. Delete the plaintext artifacts: `rm ./id_ed25519 ./id_ed25519.pub*`. The vault is now the
   source of truth and is safe to commit.

#### Rotating the secrets

Both keys rotate by editing the vault and re-running — the roles detect the
change and reconcile the host.

**SSH** — generate a new keypair, update both halves, re-run:

```bash
ssh-keygen -t ed25519 -C "gabriel@ciznia" -f ./id_ed25519
ansible-vault edit ansible/inventories/local/group_vars/all/all.vault.yml   # replace vault_ssh_private_key
# update ssh_public_key in all.yml to the new .pub
ansible-playbook ansible/playbooks/keys.yml --tags ssh                      # overwrites ~/.ssh/id_ed25519
rm ./id_ed25519*
```

Because the SSH role writes by content, the re-run replaces the on-disk key.
Register the new public key wherever the old one was trusted (GitHub,
`authorized_keys`, …) and revoke the old one.

**GPG** (and the password store) — generate a new key, put its armored secret
into the vault, and re-run with the `gpg` tag:

```bash
gpg --full-generate-key                                                     # new key, same identity
gpg --armor --export-secret-keys hosquetgabriel@gmail.com                   # → vault_gpg_private_key
ansible-vault edit ansible/inventories/local/group_vars/all/all.vault.yml   # replace vault_gpg_private_key
ansible-playbook ansible/playbooks/keys.yml --tags gpg                      # import new key + pass init
```

The `gpg` tag runs the GPG import (fingerprint differs → imports and trusts the
new key) **and** the `pass` role (re-encrypts the store to the new fingerprint).
On a shared password store, run this on one host, push the store, then re-run
elsewhere — the others import the key and see the store already migrated, so
they skip `pass init`. Finally, publish the new public key and revoke the old
one as usual. The old secret key is left in the keyring; delete it by hand if
you want (`gpg --delete-secret-and-public-key <old-fingerprint>`).

#### Loading the key at startup

The `agent` tasks add the SSH key to the running ssh-agent using
`vault_ssh_passphrase`, so you never type it. Run just that slice:

```bash
ansible-playbook ansible/playbooks/keys.yml --tags agent
```

How it works: a throwaway `SSH_ASKPASS` helper (mode `0700`, holds no secret —
it only echoes `$SSH_PASSPHRASE` from the environment) feeds the passphrase to
`ssh-add` via `SSH_ASKPASS_REQUIRE=force`, then is deleted. It's idempotent —
if the key's fingerprint is already in `ssh-add -l`, it does nothing.

To run it every login, have your NixOS config invoke that command from the user
session — e.g. a `systemd` **user** service (or your shell profile). Two things
that environment must provide:

- **`SSH_AUTH_SOCK`** — the agent must already be running and its socket
  exported, so `ssh-add` talks to it. (`programs.ssh.startAgent`, a
  `gpg-agent` with `enableSshSupport`, or a user `ssh-agent` service.)
- **The vault password** — the run has to decrypt `vault_ssh_passphrase`, so
  `.vault_pass` (or `--ask-vault-pass`) must be reachable by that service.

Sketch of a user service:

```ini
[Service]
Type=oneshot
WorkingDirectory=%h/git/dotfiles
ExecStart=ansible-playbook ansible/playbooks/keys.yml --tags agent
```

## Troubleshooting

- **`ansible.cfg` ignored / "Ansible is being run in a world writable
  directory"** — on `/mnt/c` under WSL, directories often default to `0777`, and
  Ansible refuses to load `ansible.cfg` from a world-writable directory. Fix the
  **directory** (not the file): `chmod 755 .`. Directories need their `x` bit —
  `chmod 600` strips it and locks you out of the folder entirely.

- **`vault password file … Exec format error`** — Ansible treats an
  *executable* `vault_password_file` as a script to run. On `/mnt/c` the file is
  often `0777`. Drop the exec bit: `chmod 600 .vault_pass`.

- **`agent` tag does nothing / "No ssh-agent reachable"** — `SSH_AUTH_SOCK`
  isn't set in the environment running ansible. Start the agent first, or run
  from a session/service that exports the socket.
