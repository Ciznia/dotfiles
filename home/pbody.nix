{...}: {
  imports = [./base.nix];

  targets.genericLinux.enable = true;

  home.username = "ciznia";
  home.homeDirectory = "/home/ciznia";
  home.stateVersion = "26.05";
}
