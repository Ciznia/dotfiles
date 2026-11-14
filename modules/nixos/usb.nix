{
  config,
  lib,
  pkgs,
  ...
}: {
  # Plug a stick in, open it in Thunar: udisks2 mounts it (as the user, after a
  # polkit check), gvfs shows it in the file manager, tumbler draws thumbnails.
  options.ciznia.usb.enable = lib.mkEnableOption "removable drives (udisks2, gvfs, Thunar, exFAT/NTFS)";

  config = lib.mkIf config.ciznia.usb.enable {
    services.udisks2.enable = true;
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    programs.thunar.enable = true;

    boot.supportedFilesystems = ["exfat" "ntfs"];
    environment.systemPackages = with pkgs; [exfatprogs ntfs3g];

    # Graphical polkit agent: answers the password prompts (mounting a system
    # disk, pkexec, ...) in the X session.
    security.polkit.enable = true;
    systemd.user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}
