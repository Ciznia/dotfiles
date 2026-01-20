{ pkgs, lib, ... }: {
  boot.loader.grub.gfxmodeEfi = lib.mkForce "1920x1200x32";

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        libvdpau-va-gl
        nvidia-vaapi-driver
        intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        libva-vdpau-driver
        vulkan-validation-layers
        mesa
      ];
    };

    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = false;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };

        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
      powerManagement.enable = true;
      powerManagement.finegrained = true;
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  services.blueman.enable = true;

  system = {
    copySystemConfiguration = false;
    stateVersion = "24.05";
  };
}
