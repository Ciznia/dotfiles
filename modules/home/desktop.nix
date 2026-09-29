{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.desktop;

  lfsAsset = import ../lib/lfs-asset.nix pkgs;
  wallpaper = lfsAsset ../../assets/wallpaper.jpeg;
  lockVideo = lfsAsset ../../assets/lockscreen.mp4;
  wpctl = "${pkgs.wireplumber}/bin/wpctl";

  # xsecurelock runs this once per monitor, into $XSCREENSAVER_WINDOW. OpenGL +
  # hwdec: mpv's default (gpu-next on Vulkan) takes ~3 s plus shader compiles
  # before the first frame, and the lock looks blank meanwhile. Sound only from
  # the first monitor's copy, following the system sink (muted => silent).
  lockSaver = pkgs.writeShellScript "lock-video-saver" ''
    mute=yes
    [ "''${XSCREENSAVER_SAVER_INDEX:-0}" = 0 ] && mute=no
    exec ${pkgs.mpv}/bin/mpv --no-config --loop --no-osc --no-terminal \
      --no-input-default-bindings --mute=$mute \
      --vo=gpu --gpu-api=opengl --hwdec=auto-safe \
      --wid="$XSCREENSAVER_WINDOW" ${lockVideo}
  '';
in {
  # User half of the graphical stack (qtile session config, wallpaper, screen
  # lock). The greeter half is modules/nixos/desktop.nix.
  options.ciznia.desktop.enable = lib.mkEnableOption "qtile desktop (session config, wallpaper, screen lock)";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      feh # wallpaper
      rofi # app launcher
      alacritty # terminal
    ];

    # Lock after 15 min idle, on suspend and on `loginctl lock-session` (Super+L):
    # xss-lock follows the X screensaver timer and logind (xautolock would only
    # duplicate that timer). The video plays until the screen turns off 5 min
    # into the lock, i.e. at 20 min idle.
    services.screen-locker = {
      enable = true;
      inactiveInterval = 15;
      xautolock.enable = false;
      lockCmd = "${pkgs.xsecurelock}/bin/xsecurelock";
      lockCmdEnv = [
        "XSECURELOCK_SAVER=${lockSaver}"
        "XSECURELOCK_BLANK_TIMEOUT=300"
        "XSECURELOCK_BLANK_DPMS_STATE=off"
        # Plain asterisks rather than the default jumping-cursor prompt.
        "XSECURELOCK_PASSWORD_PROMPT=asterisks"
        "XSECURELOCK_SHOW_HOSTNAME=0"
        "XSECURELOCK_SHOW_USERNAME=0"
        "XSECURELOCK_SHOW_DATETIME=1"
        # These land in systemd Environment= lines: `%` needs doubling (else it
        # is a unit specifier) and values with spaces need quotes.
        "XSECURELOCK_DATETIME_FORMAT=%%H:%%M:%%S"
        "\"XSECURELOCK_FONT=JetBrainsMono Nerd Font:size=12\""
        "XSECURELOCK_AUTH_WARNING_COLOR=#d23c3d" # same red as the greeter
        # The lock grabs the keyboard, so volume keys (Fn+F1..F3) only work if
        # xsecurelock itself runs them.
        "\"XSECURELOCK_KEY_XF86AudioMute_COMMAND=${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle\""
        "\"XSECURELOCK_KEY_XF86AudioLowerVolume_COMMAND=${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%%-\""
        "\"XSECURELOCK_KEY_XF86AudioRaiseVolume_COMMAND=${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%%+\""
        "\"XSECURELOCK_KEY_XF86AudioMicMute_COMMAND=${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle\""
      ];
    };
    # Keep X's own DPMS blanking out of the way: its 10 min default would black
    # the screen before the lock.
    systemd.user.services.xss-lock.Service.ExecStartPost = "${pkgs.xset}/bin/xset dpms 1260 1260 1260";

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
          # Screen layout (profiles live in the host config, see services.autorandr).
          ${pkgs.autorandr}/bin/autorandr --change --default mobile || true
          # Wallpaper.
          ${pkgs.feh}/bin/feh --no-fehbg --bg-fill ${wallpaper} &
        '';
      };
    };
  };
}
