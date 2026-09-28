{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.desktop;

  # The assets are Git-LFS tracked. In a clone without git-lfs they are ~130-byte
  # pointer files, and Nix copies the checkout as-is — feh then fails to load the
  # wallpaper, X's root window is never painted, and the session looks frozen
  # (stale SDDM image, windows leaving trails). Fail the build loudly instead.
  lfsAsset = src:
    pkgs.runCommandLocal (baseNameOf src) {} ''
      if head -c 64 ${src} | grep -aq '^version https://git-lfs'; then
        echo "error: ${baseNameOf src} is a Git LFS pointer, not the real file." >&2
        echo "Fetch it with 'git lfs install --local && git lfs pull' in the repo, then rebuild." >&2
        exit 1
      fi
      cp ${src} $out
    '';

  wallpaper = lfsAsset ../../assets/wallpaper.jpeg;
  lockVideo = lfsAsset ../../assets/lockscreen.mp4;

  # xsecurelock saver: play the lock video into its window ($XSCREENSAVER_WINDOW).
  # No --mute / no forced volume, so audio follows the system sink (muted => silent).
  lockSaver = pkgs.writeShellScript "lock-video-saver" ''
    exec ${pkgs.mpv}/bin/mpv --no-config --loop --no-osc --no-terminal \
      --no-input-default-bindings --wid="$XSCREENSAVER_WINDOW" ${lockVideo}
  '';
in {
  # User half of the graphical stack (qtile session config, wallpaper, video
  # lock). UNTESTED — verify on real glados.
  options.ciznia.desktop.enable = lib.mkEnableOption "qtile desktop (session config, wallpaper, video lock)";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      feh # wallpaper
      mpv # lock-screen video
      xsecurelock # screen locker
      xss-lock # lock on idle/suspend
      rofi # app launcher
      alacritty # terminal
    ];

    xdg.configFile = {
      # Editable qtile config. Its startup hook runs autostart.sh (below), which
      # carries the nix store paths so config.py can stay path-agnostic.
      "qtile/config.py".source = ./qtile/config.py;

      "qtile/autostart.sh" = {
        executable = true;
        text = ''
          #!/bin/sh
          # Paint a solid root background first: SDDM starts X with none, so if
          # the wallpaper ever fails to load, exposed areas still get cleared.
          ${pkgs.xsetroot}/bin/xsetroot -solid '#1e1e2e'
          # Wallpaper.
          ${pkgs.feh}/bin/feh --no-fehbg --bg-fill ${wallpaper} &
          # Lock on idle/suspend + on `loginctl lock-session`, with the video saver.
          XSECURELOCK_SAVER=${lockSaver} XSECURELOCK_BLANK_TIMEOUT=-1 \
            ${pkgs.xss-lock}/bin/xss-lock -- ${pkgs.xsecurelock}/bin/xsecurelock &
        '';
      };
    };
  };
}
