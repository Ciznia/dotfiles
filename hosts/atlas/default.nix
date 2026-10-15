{
  pkgs,
  username,
  ...
}: {
  # NixOS-WSL system. The nixos-wsl module and home-manager are wired by mkHost.
  wsl.enable = true;
  # The install's `nixos` user stays the WSL default (NixOS-WSL gives it uid
  # 1000, which it already owns) and the backup account; it must stay declared
  # or NixOS deletes it. Flip this to `username` once that account is ready;
  # until then `username` is a plain user declared below.
  wsl.defaultUser = "nixos";

  networking.hostName = "atlas";

  ciznia = {
    base.enable = true;
    fonts.enable = true; # for WSLg apps
    virtualisation.docker.enable = true;
  };

  wsl = {
    useWindowsDriver = true;
    startMenuLaunchers = true;
    # VS Code's "Remote - Tunnels" extension doesn't read
    # ~/.vscode-server/server-env-setup, so it needs these under /bin.
    extraBin = map (src: {inherit src;}) (with pkgs; [
      "${coreutils}/bin/uname"
      "${coreutils}/bin/rm"
      "${coreutils}/bin/mkdir"
      "${coreutils}/bin/mv"
      "${coreutils}/bin/dirname"
      "${coreutils}/bin/readlink"
      "${coreutils}/bin/wc"
      "${coreutils}/bin/date"
      "${coreutils}/bin/sleep"
      "${coreutils}/bin/cat"
      "${gnused}/bin/sed"
      "${gnutar}/bin/tar"
      "${gzip}/bin/gzip"
    ]);
  };

  # WSL never starts a systemd *user* instance for `wsl` shell sessions (no
  # login/PAM session -> no user bus), so home-manager user services
  # (gpg-agent) would never run. Lingering starts user@UID at boot instead.
  # NOTE: this makes the *first* `nixos-rebuild switch`
  # exit nonzero (user@UID can't start mid-activation) — the system still
  # switches; `wsl --terminate NixOS` then reopen brings it up cleanly.
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    linger = true;
  };

  system.stateVersion = "26.05";
}
