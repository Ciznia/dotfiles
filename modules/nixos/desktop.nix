{
  config,
  lib,
  pkgs,
  ...
}: {
  # System half of the graphical stack: X11 + SDDM greeter + qtile + audio +
  # the PAM service the screen locker authenticates against. The user half
  # (qtile config, wallpaper, video lock) is modules/home/desktop.nix, gated by
  # the same-named home option. Only glados enables both.
  #
  # UNTESTED: written without a graphical machine to run it on — verify on real
  # glados. TODO: custom SDDM QML theme playing assets/lockscreen.mp4 (the
  # greeter-video half); default SDDM theme for now.
  options.ciznia.desktop.enable = lib.mkEnableOption "graphical desktop (X11 + SDDM + qtile)";

  config = lib.mkIf config.ciznia.desktop.enable {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;

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
