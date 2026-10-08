# Ciznia dotfiles

Personal configuration for my machines — a native NixOS laptop (dual-boot), the
same laptop's Windows side through NixOS-WSL, and an Ubuntu+Nix WSL (standalone
home-manager). Feel free to read, copy, or adapt anything here.

The setup leans on **two tools**:

- **Nix flake** — the declarative core: per-host NixOS + home-manager
  configuration and the dev environment. See [NIX.md](NIX.md).
- **Ansible** — a thin **preflight** for what can't be committed as flat
  files, chiefly restoring my SSH/GPG identity from an encrypted vault. See
  [ANSIBLE.md](ANSIBLE.md).

## Requirements

- [Nix](https://nixos.org/download) with flakes enabled
  (`experimental-features = nix-command flakes`).
- [git-lfs](https://git-lfs.com/) for the wallpaper and lock video.

## Usage

```bash
nix develop                                     # dev shell (ansible, gpg, openssh, formatter, …)
nix fmt                                         # format the tree with alejandra

ansible-playbook ansible/playbooks/keys.yml     # restore the SSH/GPG identity (inside nix develop)

sudo nixos-rebuild switch --flake .#<host>      # NixOS hosts
home-manager    switch --flake .#ciznia@<host>  # standalone hosts
```
