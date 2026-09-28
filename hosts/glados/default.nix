{
  lib,
  username,
  ...
}: {
  imports = [./hardware-configuration.nix];

  # Bootloader: lanzaboote (Secure Boot), which replaces systemd-boot rather
  # than layering on GRUB — see modules/nixos/secureboot.nix. Windows is NOT in
  # this menu: it lives on the other NVMe with its own ESP, and systemd-boot only
  # lists what's on its own ESP (there's no os-prober). Boot Windows from the
  # firmware boot menu instead (F11 on this MSI), which keeps its own ESP entry.
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

  # NVIDIA RTX 4060 Laptop (Ada) — PRIME offload: the iGPU drives the panel,
  # the dGPU runs on demand via the `nvidia-offload` wrapper. "nvidia" must be
  # listed: NixOS only enables the hardware.nvidia block below when it is (with
  # just "modesetting", nouveau grabbed the dGPU), and with offload it sets up
  # modesetting for the iGPU itself. The old post-login "freeze" blamed on this
  # was the LFS-pointer wallpaper (commit 1eb7fcc), not the driver.
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
        # The HDMI port is wired to the dGPU: reverse PRIME lets the iGPU's X
        # screen drive it (xrandr --setprovideroutputsource at X start).
        reverseSync.enable = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  time.timeZone = "Europe/Paris"; # update when you move
  # RTC in UTC, like Windows with RealTimeIsUniversal=1 (docs/NIX.md). This
  # only stops NixOS writing LOCAL: an existing /etc/adjtime still needs
  # `timedatectl set-local-rtc 0` once.
  time.hardwareClockInLocalTime = false;
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
