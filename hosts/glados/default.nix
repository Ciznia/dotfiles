{
  lib,
  username,
  ...
}: {
  imports = [./hardware-configuration.nix];

  # Dual-boot (NixOS + Windows): GRUB with os-prober to pick up the Windows
  # entry. (GRUB and systemd-boot are mutually exclusive — pick one.)
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      grub = lib.mkDefault {
        enable = true;
        efiSupport = true;
        device = "nodev";
        gfxmodeEfi = "1920x1080x32";
        useOSProber = true;
      };
    };
  };

  networking.hostName = "glados";
  networking.networkmanager.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
  };

  # NVIDIA RTX 4060 Laptop (Ada) — PRIME offload: the iGPU drives the display,
  # the dGPU runs on demand via the `nvidia-offload` wrapper.
  services.xserver.videoDrivers = ["nvidia"];
  hardware = {
    graphics.enable = true;
    nvidia = {
      modesetting.enable = true;
      open = true; # recommended for Ada; flip to false if you hit issues
      nvidiaSettings = true;
      powerManagement.enable = true;
      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true; # provides `nvidia-offload`
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  time.timeZone = "Europe/Paris"; # update when you move
  i18n.defaultLocale = "en_US.UTF-8";

  # Keyboard: FR default + US secondary; toggle with Alt+Shift (rebind later).
  services.xserver.xkb = {
    layout = "fr,us";
    options = "grp:alt_shift_toggle";
  };
  console.keyMap = "fr";

  system.stateVersion = "26.05";
}
