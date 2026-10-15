{
  config,
  pkgs,
  username,
  ...
}: {
  # NixOS-WSL system. The nixos-wsl module and home-manager are wired by mkHost.
  wsl.enable = true;
  # `username` is the WSL default user, so Explorer (\\wsl.localhost\NixOS)
  # browses as it. NixOS-WSL gives the default user uid 1000; the install's
  # `nixos` user is no longer declared, so NixOS removes it (its home stays).
  wsl.defaultUser = username;

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
  # isNormalUser, uid 1000 and wheel come from wsl.defaultUser.
  users.users.${username}.linger = true;

  # WSLg mounts its own tmpfs over the default user's /run/user/<uid>, on top
  # of the one systemd made for user@<uid>: that hides the user bus
  # (`systemctl --user` fails) and sops-nix's decrypted secrets. At boot, drop
  # WSLg's layer and recreate its links (Wayland, PulseAudio) in systemd's dir.
  systemd.services.wslg-runtime-dir = let
    dir = "/run/user/${toString config.users.users.${username}.uid}";
    wslg = "/mnt/wslg/runtime-dir";
  in {
    description = "Unhide ${dir} from WSLg's overmount";
    wantedBy = ["multi-user.target"];
    after = ["user@${toString config.users.users.${username}.uid}.service"];
    # Only at boot: once shells hold sockets in WSLg's layer, unmounting it
    # would cut them off (see docs/NIX.md, WSL).
    restartIfChanged = false;
    path = [pkgs.util-linux pkgs.coreutils];
    # Not oneshot: WSL may only mount its layer once boot is done, so waiting
    # for it must not hold boot (and the first shell) up.
    serviceConfig.Type = "exec";
    script = ''
      # WSL mounts its layer shortly after boot: wait for the second mount.
      for _ in $(seq 120); do
        if [ "$(findmnt -n -o TARGET ${dir} | wc -l)" -ge 2 ]; then
          umount -l ${dir}
          break
        fi
        sleep 1
      done
      if [ -d ${wslg} ]; then
        ln -sfn ${wslg}/wayland-0 ${dir}/wayland-0
        ln -sfn ${wslg}/wayland-0.lock ${dir}/wayland-0.lock
        mkdir -p ${dir}/pulse
        ln -sfn ${wslg}/pulse/native ${dir}/pulse/native
        ln -sfn ${wslg}/pulse/pid ${dir}/pulse/pid
        chown -h ${username}:users ${dir}/pulse
      fi
    '';
  };

  system.stateVersion = "26.05";
}
