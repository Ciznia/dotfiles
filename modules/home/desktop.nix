{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.desktop;

  wallpaper = ../../assets/wallpaper.jpeg;
  lockVideo = ../../assets/lockscreen.mp4;

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
