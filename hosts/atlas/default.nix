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
  # of the one systemd made for user@<uid>: whatever user@<uid> then creates
  # (the user bus, sops-nix's secrets) lands in WSLg's layer or under it. So
  # before user@<uid> starts, drop WSLg's layer and recreate its links (Wayland,
  # PulseAudio) in systemd's dir.
  systemd.services.wslg-runtime-dir = let
    uid = toString config.users.users.${username}.uid;
    dir = "/run/user/${uid}";
    wslg = "/mnt/wslg/runtime-dir";
  in {
    description = "Unhide ${dir} from WSLg's overmount";
    wantedBy = ["user@${uid}.service"];
    after = ["user-runtime-dir@${uid}.service"];
    before = ["user@${uid}.service"];
    # Only at boot: once shells hold sockets in WSLg's layer, unmounting it
    # would cut them off (see docs/NIX.md, WSL).
    restartIfChanged = false;
    path = [pkgs.util-linux pkgs.coreutils];
    # Once per boot, not again on a user@<uid> restart.
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # WSL mounts its layer within seconds of systemd's: wait for it.
      for _ in $(seq 20); do
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

  # Right after that unmount, user@<uid> can fail to spawn once ("Device or
  # resource busy") and systemd doesn't retry it on its own.
  systemd.services."user@${toString config.users.users.${username}.uid}" = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  system.stateVersion = "26.05";
}
