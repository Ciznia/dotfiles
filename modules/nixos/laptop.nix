{
  config,
  lib,
  ...
}: {
  # Power management is TLP, from the nixos-hardware laptop preset (hosts/glados).
  options.ciznia.laptop.enable = lib.mkEnableOption "laptop hardware (bluetooth, flat touchpad/mouse acceleration)";

  config = lib.mkIf config.ciznia.laptop.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;

    services.libinput = {
      enable = true;
      mouse.accelProfile = "flat";
      touchpad.accelProfile = "flat";
    };
  };
}
