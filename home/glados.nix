{...}: {
  imports = [./base.nix];

  # glados: native NixOS laptop, integrated home-manager.
  ciznia = {
    desktop = {
      enable = true; # qtile session + wallpaper + video lock (home half)
      displayProfiles = ["docked" "mobile"]; # services.autorandr in hosts/glados
    };
    gaming.enable = true;
  };

  # Prism Launcher on the NVIDIA GPU.
  home.shellAliases.prismlauncher = "nvidia-offload prismlauncher";

  home.stateVersion = "26.05";
}
