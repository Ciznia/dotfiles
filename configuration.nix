# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, ... }:

{
  wsl = {
    defaultUser = "ciznia";
    enable = true;
    useWindowsDriver = true;
    startMenuLaunchers = true;
    extraBin = [
      # VS Code's "Remote - Tunnels" extension does not respect `~/.vscode-server/server-env-setup`, so we need to provide these binaries under `/bin`.
      { src = "${pkgs.coreutils}/bin/uname"; }
      { src = "${pkgs.coreutils}/bin/rm"; }
      { src = "${pkgs.coreutils}/bin/mkdir"; }
      { src = "${pkgs.coreutils}/bin/mv"; }

      { src = "${pkgs.coreutils}/bin/dirname"; }
      { src = "${pkgs.coreutils}/bin/readlink"; }
      { src = "${pkgs.coreutils}/bin/wc"; }
      { src = "${pkgs.coreutils}/bin/date"; }
      { src = "${pkgs.coreutils}/bin/sleep"; }
      { src = "${pkgs.coreutils}/bin/cat"; }
      { src = "${pkgs.gnused}/bin/sed"; }
      { src = "${pkgs.gnutar}/bin/tar"; }
      { src = "${pkgs.gzip}/bin/gzip"; }
    ];
  };
  programs.zsh.enable = true;
  users.users.ciznia.shell = pkgs.zsh;
  programs.dconf.enable = true;
  services.resolved.extraConfig = builtins.readFile ./resolv.conf;
  programs.nix-ld = {
    enable = true;
    libraries = [ pkgs.glibc pkgs.zlib ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
