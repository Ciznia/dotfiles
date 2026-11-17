# Ciznia dotfiles

Personal configuration for my machines — a native NixOS laptop (dual-boot), the
same laptop's Windows side through NixOS-WSL, and an Ubuntu+Nix WSL (standalone
home-manager). Feel free to read, copy, or adapt anything here.

Everything is a **Nix flake**: per-host NixOS + home-manager configuration and
the dev environment. See [NIX.md](NIX.md).

## Requirements

- [Nix](https://nixos.org/download) with flakes enabled
  (`experimental-features = nix-command flakes`).

Everything else (gpg, sops, rbw, git-lfs, …) comes from `nix develop`. The
wallpaper and lock video are Git-LFS tracked: in a clone made without git-lfs,
run `git lfs install --local && git lfs pull` inside the dev shell.

## Usage

```bash
nix develop                                     # dev shell (gpg, sops, rbw, formatter, …)
nix fmt                                         # format the tree with alejandra

scripts/machine-keys.sh                         # this machine's ssh key + gpg subkey (once)

sudo nixos-rebuild switch --flake .#<host>      # NixOS hosts
home-manager    switch --flake .#ciznia@<host>  # standalone hosts
```
