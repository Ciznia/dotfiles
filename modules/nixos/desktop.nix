{
  config,
  lib,
  pkgs,
  ...
}: let
  lfsAsset = import ../lib/lfs-asset.nix pkgs;
  greeterVideo = lfsAsset ../../assets/lockscreen.mp4;
  # Shown until the video starts playing (and if it never does).
  greeterPlaceholder = pkgs.runCommandLocal "greeter-placeholder.png" {} ''
    ${pkgs.ffmpeg-headless}/bin/ffmpeg -loglevel error -i ${greeterVideo} -frames:v 1 $out
  '';

  # Ready-made Qt6 theme that plays a video background (QtMultimedia); ours is
  # the lock video, silent (no audio output in the greeter).
  # Layout patch (the theme has no option for it): login form in the bottom-left
  # corner, a small clock + date in the top-right one.
  greeterTheme = (pkgs.sddm-astronaut.override {
    themeConfig = {
      Background = "${greeterVideo}";
      BackgroundPlaceholder = "${greeterPlaceholder}";
      CropBackground = "true";
      ScreenWidth = "1920";
      ScreenHeight = "1080";
      Font = "JetBrainsMono Nerd Font";
      HourFormat = "HH:mm:ss";
      # Same red accent as the lock screen (modules/home/desktop.nix).
      HoverUserIconColor = "#d23c3d";
      HoverPasswordIconColor = "#d23c3d";
      HoverSystemButtonsIconsColor = "#d23c3d";
      HoverSessionButtonTextColor = "#d23c3d";
      HoverVirtualKeyboardButtonTextColor = "#d23c3d";
      HideVirtualKeyboard = "true";
      # No blurred column behind the form: widgets sit straight on the video.
      PartialBlur = "false";
      FullBlur = "false";
      FormPosition = "left";
      FontSize = "10"; # smaller form (the patched clock scales up to match)
      HideLoginButton = "true"; # Enter logs in
    };
  }).overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        theme=$out/share/sddm/themes/sddm-astronaut-theme
        chmod -R u+w $theme
        patch -d $theme -p1 < ${./sddm-astronaut-layout.patch}
      '';
  });
in {
  # System half of the graphical stack: X11 + SDDM greeter + qtile + audio +
  # the PAM service the screen locker authenticates against. The user half
  # (qtile config, wallpaper, video lock) is modules/home/desktop.nix, gated by
  # the same-named home option. Only glados enables both.
  options.ciznia.desktop.enable = lib.mkEnableOption "graphical desktop (X11 + SDDM + qtile)";

  config = lib.mkIf config.ciznia.desktop.enable {
    services.xserver.enable = true;
    services.displayManager.sddm = {
      enable = true;
      theme = "sddm-astronaut-theme";
      # The greeter loads the theme's QML imports from these.
      extraPackages = [greeterTheme] ++ (with pkgs.kdePackages; [qtmultimedia qtsvg qtvirtualkeyboard]);
    };
    environment.systemPackages = [greeterTheme];

    services.xserver.windowManager.qtile = {
      enable = true;
      # The qtile package ships BOTH an X11 and a Wayland "qtile" session; SDDM
      # launches the Wayland one, but our desktop is X11 (feh wallpaper,
      # xss-lock/xsecurelock, systray all need X11, and wlroots also fails under
      # software rendering). Drop the Wayland session so only X11 is offered.
      package = pkgs.python3Packages.qtile.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            rm -f "$out/share/wayland-sessions/qtile.desktop"
          '';
      });
    };

    # Only the X11 "qtile" session remains now, so this is unambiguous.
    services.displayManager.defaultSession = "qtile";

    # PipeWire — the lock-screen video plays through the user sink, so audio
    # follows the system mute (see the saver in modules/home/desktop.nix).
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    # xsecurelock authenticates the unlock via this PAM service.
    security.pam.services.xsecurelock = {};

    fonts.packages = [pkgs.nerd-fonts.jetbrains-mono];
  };
}
