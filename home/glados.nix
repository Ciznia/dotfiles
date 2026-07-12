{...}: {
  imports = [./base.nix];

  # glados: native NixOS laptop, integrated home-manager.
  ciznia.desktop.enable = true; # qtile session + wallpaper + video lock (home half)

  home.stateVersion = "26.05";
}
