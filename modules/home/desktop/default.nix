{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.desktop;

  lfsAsset = import ../../lib/lfs-asset.nix pkgs;
  wallpaper = lfsAsset ../../../assets/wallpaper.jpeg;
  lockVideo = lfsAsset ../../../assets/lockscreen.mp4;
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

  # Super+P / Super+Shift+P (qtile controls.py): number -> autorandr profile.
  displayProfile = pkgs.writeShellApplication {
    name = "display-profile";
    # arandr from stable: it fails to build on the pinned unstable (setuptools).
    runtimeInputs = with pkgs; [autorandr stable.arandr libnotify];
    text = ''
      PROFILES=(${lib.escapeShellArgs cfg.displayProfiles})
      ${builtins.readFile ./scripts/display-profile.sh}
    '';
  };
in {
  # User half of the graphical stack (qtile session config, wallpaper, screen
  # lock, notifications). The greeter half is modules/nixos/desktop.nix.
  imports = [./notifications.nix];

  options.ciznia.desktop = {
    enable = lib.mkEnableOption "qtile desktop (session config, wallpaper, screen lock)";

    displayProfiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["docked" "mobile"];
      description = ''
        autorandr profiles behind the digits of Super+P (load) and
        Super+Shift+P (save): the first is 1, and so on. Digits past the list
        use "profile<N>".
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    ciznia.terminal.enable = lib.mkDefault true; # kitty

    home.packages = with pkgs; [
      displayProfile
      feh # wallpaper
      rofi # app launcher, window switcher (Alt+Tab)
      wmctrl
      picom # compositor, started by autostart.sh
      brightnessctl
      pulsemixer # Super+V
      xclip
      xinput # touchpad toggle (Super+T)
      dconf
    ];

    services.flameshot = {
      enable = true;
      settings.General.uiColor = "#1435c7";
    };

    home.pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      name = "Catppuccin-Macchiato-Dark-Cursors";
      package = pkgs.catppuccin-cursors.macchiatoDark;
      size = 24;
    };

    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
    qt = {
      enable = true;
      platformTheme.name = "kvantum";
      style.name = "kvantum";
    };

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
      # qtile config. Its startup hook runs autostart.sh (below), which carries
      # the nix store paths so the python files can stay path-agnostic.
      "qtile/config.py".source = ../qtile/config.py;
      "qtile/bar.py".source = ../qtile/bar.py;
      "qtile/controls.py".source = ../qtile/controls.py;
      "qtile/colors.py".source = ../qtile/colors.py;

      "picom/picom.conf".source = ./picom.conf;

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
          # Compositor (config: ~/.config/picom/picom.conf).
          ${pkgs.picom}/bin/picom -f --backend xrender &
        '';
      };
    };
  };
}
