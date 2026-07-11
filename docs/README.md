# Ciznia dotfiles

Personal configuration for my machines — a native NixOS desktop (dual-boot), a
NixOS-WSL laptop, and an Ubuntu+Nix WSL (standalone home-manager). Feel free to
read, copy, or adapt anything here.

The setup leans on **two tools**:

- **Nix flake** — the declarative core: the dev environment, and (planned)
  per-host NixOS + home-manager configuration. Architecture in
  [NIX.md](NIX.md). This is where the bulk of the config lives.
- **Ansible** — a thin **preflight** for the imperative, bootstrap-y bits that
  can't be committed as flat files, chiefly restoring my SSH/GPG identity from
  an encrypted vault. See [ANSIBLE.md](ANSIBLE.md).

## Structure

```txt
flake.nix        # inputs + outputs (dev shell, formatter, …)
flake.lock
ansible.cfg      # Ansible config (points at ansible/inventories/local)
ansible/         # preflight: playbooks, roles, inventory, vault
docs/
  NIX.md         # Nix architecture: hosts, home-manager, add-a-system
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

The flake currently provides the development shell and formatter. Per-host
system + home-manager configuration is the next step; the planned architecture
(hosts, standalone-vs-integrated home-manager, and how to add a machine) is
documented in [NIX.md](NIX.md). Once implemented, a machine rebuilds with:

```bash
sudo nixos-rebuild switch --flake .#<host>      # NixOS hosts (planned)
home-manager    switch --flake .#ciznia@<host>  # standalone hosts (planned)
```

### Ansible preflight

From the repo root, inside `nix develop`:

```bash
ansible-playbook ansible/playbooks/keys.yml
```

This restores the shared SSH/GPG identity from the vault. Full details —
running playbooks, viewing/editing the vault, and setting or rotating secrets —
are in [ANSIBLE.md](ANSIBLE.md).
