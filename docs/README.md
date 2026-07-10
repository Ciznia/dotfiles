# Ciznia dotfiles

Personal configuration for my machines — a NixOS desktop (dual-boot) and
NixOS-WSL. Feel free to read, copy, or adapt anything here.

The setup leans on **two tools**:

- **Nix flake** — the declarative core: the dev environment today, and system
  configuration going forward. This is where the bulk of the config lives.
- **Ansible** — a thin **preflight** for the imperative, bootstrap-y bits that
  can't be committed as flat files, chiefly restoring my SSH/GPG identity from
  an encrypted vault. See [docs/ANSIBLE.md](docs/ANSIBLE.md).

## Structure

```txt
flake.nix        # inputs + outputs (dev shell, formatter, …)
flake.lock
ansible.cfg      # Ansible config (points at ansible/inventories/local)
ansible/         # preflight: playbooks, roles, inventory, vault
docs/
  ANSIBLE.md     # Ansible usage: playbooks, vault, secrets
```

## Requirements

- [Nix](https://nixos.org/download) with flakes enabled
  (`experimental-features = nix-command flakes`).

## Usage

### Nix flake

```bash
nix develop      # enter the dev shell (ansible, gpg, openssh, formatter, …)
nix fmt          # format the tree with alejandra
```

The flake currently provides the development shell and formatter. System
configuration (`nixosConfigurations` for the desktop and WSL) is the intended
next step; once present, a machine rebuilds with:

```bash
sudo nixos-rebuild switch --flake .#<host>    # planned
```

### Ansible preflight

From the repo root, inside `nix develop`:

```bash
ansible-playbook ansible/playbooks/keys.yml
```

This restores the shared SSH/GPG identity from the vault. Full details —
running playbooks, viewing/editing the vault, and setting or rotating secrets —
are in [docs/ANSIBLE.md](docs/ANSIBLE.md).
