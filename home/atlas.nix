{...}: {
  imports = [./base.nix];

  # atlas: NixOS-WSL, integrated home-manager. username/homeDirectory come from
  # the system user (ciznia, via wsl.defaultUser), so no standalone contract.
  home.stateVersion = "26.05";
}
