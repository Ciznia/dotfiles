{ config, username, pkgs, ... }:
{
  imports = [ ./polkit.nix ];

  boot = {
    consoleLogLevel = 0;
    initrd = {
      verbose = false;
    };

    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        gfxmodeEfi = "1920x1080x32";
        useOSProber = true;
      };
    };
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 90d";
    };
    optimise.automatic = true;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "@wheel" ];
      keep-outputs = true;
      keep-derivations = true;
      auto-optimise-store = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  networking = {
    networkmanager.enable = true;
    firewall.enable = false;
  };

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    earlySetup = true;
    useXkbConfig = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-116n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    colors = [
      "11111E" # Black
      "E12541" # red
      "14C67B" # green
      "FFAC7D" # yellow
      "7270FF" # blue
      "FD8DFF" # magenta
      "75DFED" # cyan
      "A4B1E3" # white

      "474B77" # light black
      "DE6876" # light red
      "63D961" # light green
      "FFDA8D" # light yellow
      "AAA9FA" # light blue
      "E5A5FB" # light magenta
      "BEEDF8" # light cyan
      "DBE2FB" # light white
    ];
  };

  hardware = {
    pulseaudio.enable = false;
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
      ];

    };

    nvidia = {
      modesetting.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      powerManagement.enable = false;
      powerManagement.finegrained = false;

      open = false;
      nvidiaSettings = true;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };

        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  programs = {
    command-not-found.enable = false;
    dconf.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    steam.enable = true;
    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
      ];
    };

    thunderbird.enable = true;

    zsh.enable = true;
    noisetorch.enable = true;

    nix-ld = {
      enable = true;
      libraries = [ pkgs.glibc ];
    };
  };

  security.rtkit.enable = true;
  services = {
    auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
        };

        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };

    libinput = {
      enable = true;
      mouse.accelProfile = "flat";
      touchpad.accelProfile = "flat";
    };

    gvfs.enable = true;
    tumbler.enable = true;
    openssh.enable = true;

    picom = {
      enable = true;
      fade = true;
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    xserver = {
      enable = true;
      displayManager.startx.enable = true;
      xkb.layout = "fr";
      videoDrivers = [ "nvidia" ];

      windowManager.qtile = {
        enable = true;
      };
    };

    upower.enable = true;
  };

  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "audio" "docker" "networkmanager" "libvirtd" "wheel" ];
    initialPassword = "hello";
  };

  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    dina-font
    fira-code
    fira-code-symbols
    liberation_ttf
    mplus-outline-fonts.githubRelease
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    proggyfonts
    apl386
  ];

  virtualisation = {
    docker = {
      enable = true;
      package = pkgs.docker;
    };

    libvirtd.enable = true;
  };

  documentation.dev.enable = true;
  environment = {
    pathsToLink = [ "/share/nix-direnv" ];
    sessionVariables = {
      MOZ_USE_XINPUT2 = "1";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };

    shells = [ pkgs.zsh ];
    systemPackages = with pkgs; [
      firefox

      alsa-utils
      modemmanager
      networkmanagerapplet
      playerctl

      git
      htop
      tree
      vim
      vscode
      vifm
      wget

      gnumake
      glibc
      gcc
      bear
      python3Packages.compiledb

      libnotify
      virt-manager

      man-pages
      man-pages-posix

      zip
      unzip
    ];
  };

  system = {
    copySystemConfiguration = false;
    stateVersion = "24.05";
  };

  qt.style = "adwaita-dark";
  xdg.portal = {
    enable = true;
    config.common.default = "*";
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
  };
}
