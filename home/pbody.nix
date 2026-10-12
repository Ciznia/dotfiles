{...}: {
  imports = [./base.nix];

  # pbody: Ubuntu on WSL, standalone home-manager. No qtile desktop here.
  ciznia.gaming.enable = true;

  targets.genericLinux.enable = true;

  home.username = "ciznia";
  home.homeDirectory = "/home/ciznia";
  home.stateVersion = "26.05";
}
