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

  # WSL writes /etc/resolv.conf once, at its start, from whatever network
  # Windows has then, and the Cisco VPN lets no DNS server through but TH
  # Köln's own: connecting or leaving the VPN afterwards left no working
  # resolver. (`dnsTunneling` does nothing under virtioproxy.) So a fixed list
  # instead, with systemd-resolved staying on whichever server answers:
  # TH Köln's on the VPN, the public ones off it.
  wsl.wslConf.network.generateResolvConf = false;
  networking.nameservers = ["139.6.1.2" "139.6.1.3" "1.1.1.1" "9.9.9.9"];
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "false";
      # The list above is the whole list.
      FallbackDNS = "";
    };
  };

  # With `networkingMode=virtioproxy` in Windows' .wslconfig (what lets WSL out
  # through the Cisco VPN), WSL routes all TCP for 127.0.0.1 to Windows and
  # only brings back the ports it saw being bound. It misses listeners that
  # asked for port 0, such as the VS Code server, so they refuse every
  # connection made from inside WSL. Dropping the rule keeps loopback TCP in
  # Linux; the cost is that `localhost` here no longer reaches Windows' ports.
  systemd.services.wsl-loopback-tcp = {
    description = "Keep loopback TCP inside WSL";
    wantedBy = ["multi-user.target"];
    # The rule is WSL's, made once per boot: nothing to redo on a switch.
    restartIfChanged = false;
    path = [pkgs.iproute2 pkgs.gnugrep pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # WSL may add the rule a moment after systemd starts. In the other
      # networking modes it never comes, and this leaves things as they are.
      for _ in $(seq 10); do
        if ip rule show priority 1 | grep -q 'ipproto tcp lookup 127'; then
          ip rule del priority 1 ipproto tcp lookup 127
          break
        fi
        sleep 1
      done
    '';
  };

  system.stateVersion = "26.05";
}
