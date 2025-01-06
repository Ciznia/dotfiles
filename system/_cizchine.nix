{ pkgs, lib, ... }: {
  boot.loader.grub.gfxmodeEfi = lib.mkForce "1920x1200x32";

  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        amdvlk
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        libvdpau-va-gl
        nvidia-vaapi-driver
        vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        vaapiVdpau
        vulkan-validation-layers
        mesa.drivers
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
      powerManagement.enable = false;
      powerManagement.finegrained = false;
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  system = {
    copySystemConfiguration = false;
    stateVersion = "24.05";
  };
}
