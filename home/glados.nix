{...}: {
  imports = [./base.nix];

  # glados: native NixOS laptop, integrated home-manager. The desktop stack
  # (qtile, SDDM video, xsecurelock) is added next, gated by ciznia.desktop.
  home.stateVersion = "26.05";
}
