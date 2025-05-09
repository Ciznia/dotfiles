{ pkgs, ... }:

{
  wsl = {
    defaultUser = "ciznia";
    enable = true;
    useWindowsDriver = true;
    startMenuLaunchers = true;

    # VS Code's "Remote - Tunnels" extension
    # does not respect `~/.vscode-server/server-env-setup`,
    # so we need to provide these binaries under `/bin`.
    extraBin = let
      inherit (pkgs.lib) getExe getExe';

      single-bins = map getExe (with pkgs; [ gnutar gnused gzip ]);
      coreutils-bin = map (getExe' pkgs.coreutils) [
        "uname" "rm" "mkdir" "mv"
        "dirname" "readlink" "wc" "date"
        "sleep" "cat"
      ];
    in map (v: { src = v; }) (coreutils-bin ++ single-bins);
  };

  programs = {
    dconf.enable = true;
    nix-ld = {
      enable = true;
      libraries = [ pkgs.glibc pkgs.zlib ];
    };
    zsh.enable = true;
  };

  users.users.ciznia.shell = pkgs.zsh;
  services.resolved.extraConfig = builtins.readFile ./resolv.conf;

  system.stateVersion = "24.11"; # initial version for compatibility
}
