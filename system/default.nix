{ username, pkgs, ... }:
{
  imports = [
    ./polkit.nix
  ];

  catppuccin = {
    enable = true;
    flavor = "macchiato";
  };

  boot = {
    consoleLogLevel = 0;
    initrd.verbose = false;

    kernelPackages = pkgs.linuxKernel.packages.linux_6_6;
    loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        gfxmodeEfi = "1920x1280x32";
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

  programs = {
    command-not-found.enable = false;
    dconf.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    nix-ld = {
      enable = true;
      libraries = [ pkgs.glibc ];
    };
    noisetorch.enable = true;
    steam.enable = true;
    thunderbird.enable = true;
    zsh.enable = true;
  };

  security.rtkit.enable = true;
  services = {
    pulseaudio.enable = false;
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
    openssh.enable = true;
    tumbler.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    xserver = {
      enable = true;
      displayManager.startx.enable = true;
      xkb = {
        layout = "fr";
        extraLayouts.custom = {
          description = "qwerty with characters";
          languages = [ "eng" ];
          symbolsFile =
            let
              layout = (pkgs.callPackage ./qwerty-fr.nix { });
            in
            "${layout}/share/X11/xkb/symbols/us_qwerty-fr";
        };
      };
      windowManager.qtile.enable = true;
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "audio" "docker" "networkmanager" "libvirtd" "wheel" ];
    initialPassword = "hello";
  };

  fonts.packages = with pkgs; [
    apl386
    fira-code
    fira-code-symbols
    liberation_ttf
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    proggyfonts
  ];

  documentation.dev.enable = true;
  environment = {
    etc.issue.text = (builtins.readFile ./issuerc);
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
      alsa-utils
      modemmanager
      networkmanagerapplet
      playerctl

      git
      tree
      neovim
      wget

      libnotify
      virt-manager

      man-pages
      man-pages-posix

      gnumake
      gcc
      glibc
    ];
  };

  virtualisation = {
    docker = {
      enable = true;
      package = pkgs.docker;
    };

    libvirtd.enable = true;
  };

  zramSwap.enable = true;
}
