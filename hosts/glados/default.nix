{
  lib,
  pkgs,
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

  # Screens: autorandr picks a layout by EDID — on hotplug (udev), after
  # suspend, at X start (below) and at session start (qtile autostart). The HP
  # X27c sits right of the laptop and is the primary. A user `autorandr --save
  # docked` lands in ~/.config/autorandr and overrides the same-named profile
  # here.
  services.autorandr = {
    enable = true;
    defaultTarget = "mobile";
    profiles = let
      fingerprint = {
        laptop = "00ffffffffffff0006af8f9700000000031e0104a526167803707593585a942920505400000001010101010101010101010101010101ce8f80b6703888403020a5007ed710000018ec3b80b6703888403020a5007ed710000018000000fd003c90b0b025010a202020202020000000fe004231373348414e30342e39200a007a";
        hp = "00ffffffffffff00220e343701010101251f0103803c22782e1125ad5061a525165054a10800d1c081c0a9c09500b300810081800101023a801871382d40582c450055502100001e000000fd003ca51ed232000a202020202020000000fc00485020583237630a2020202020000000ff00434e43313337313930330a2020016a020336f148903f400403020155230907078301000067030c001000004267d85dc4017880006d1a000002013ca5ed0000000000e2006b089b80a070384d403020350055502100001a5a8780a070384d403020350055502100001a0474801871382d40582c450055502100001e2a4480a0703827403020350055502100001a00cd";
      };
      panel = {
        enable = true;
        mode = "1920x1080";
        rate = "144.03";
      };
    in {
      docked = {
        fingerprint = {
          eDP-1 = fingerprint.laptop;
          HDMI-1-0 = fingerprint.hp;
        };
        config = {
          eDP-1 = panel // {position = "0x0";};
          HDMI-1-0 = {
            enable = true;
            primary = true;
            mode = "1920x1080";
            rate = "164.92";
            position = "1920x0";
          };
        };
      };
      mobile = {
        fingerprint.eDP-1 = fingerprint.laptop;
        config.eDP-1 = panel // {
          primary = true;
          position = "0x0";
        };
      };
    };
  };
  # The reverse PRIME setup ends in `xrandr --auto`, which mirrors the screens;
  # lay them out properly before the greeter shows.
  services.xserver.displayManager.setupCommands = lib.mkAfter ''
    ${pkgs.autorandr}/bin/autorandr --change --default mobile || true
  '';

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
