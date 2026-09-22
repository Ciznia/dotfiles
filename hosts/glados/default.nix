{
  lib,
  username,
  ...
}: {
  imports = [./hardware-configuration.nix];

  # Bootloader: lanzaboote (Secure Boot), which replaces systemd-boot rather
  # than layering on GRUB — see modules/nixos/secureboot.nix. Dual-boot with
  # Windows doesn't need os-prober here: /boot is the pre-existing Windows ESP
  # (see hardware-configuration.nix), and systemd-boot auto-discovers any other
  # *.efi already on that same ESP, Windows Boot Manager included.
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "glados";
  networking.networkmanager.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  ciznia.desktop.enable = true; # X11 + SDDM + qtile + audio + lock (system half)
  ciznia.secureBoot.enable = true; # signed boot chain (lanzaboote) — see docs/NIX.md

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
  };

  # NVIDIA RTX 4060 Laptop (Ada) — PRIME offload: the iGPU drives the display,
  # the dGPU runs on demand via the `nvidia-offload` wrapper. The driver here
  # must be the IGPU's (modesetting), not nvidia — nvidia has no display output
  # in offload mode, so `videoDrivers = ["nvidia"]` starts X against a GPU with
  # nothing to scan out to, which is what froze the session after SDDM login.
  services.xserver.videoDrivers = ["modesetting"];
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

  # `nixos-rebuild build-vm --flake .#glados` (or `nix run .#glados-vm`) boots
  # this config in QEMU to smoke-test the desktop before touching hardware.
  # These overrides apply ONLY to the VM image — never to a real switch.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096; # MB
      cores = 4;
    };

    # A password to log into SDDM / a TTY in the VM.
    users.users.${username}.initialPassword = "test";

    # QEMU has no NVIDIA GPU — modesetting on the virtual GPU. This also disables
    # the whole hardware.nvidia block (gated on nvidia being in videoDrivers).
    services.xserver.videoDrivers = lib.mkForce ["modesetting"];

    # The host's real disks aren't in the VM: don't auto-mount /boot, drop swap.
    fileSystems."/boot".options = lib.mkForce ["noauto"];
    swapDevices = lib.mkForce [];

    # SSH into the VM to read logs when the graphical session misbehaves:
    #   ssh ciznia@localhost -p 2222   (password: test)
    services.openssh.enable = true;
    services.openssh.settings.PasswordAuthentication = true;
    virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
  };

  system.stateVersion = "26.05";
}
