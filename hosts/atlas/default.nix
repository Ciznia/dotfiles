{username, ...}: {
  # NixOS-WSL system. The nixos-wsl module and home-manager are wired by mkHost.
  wsl.enable = true;
  wsl.defaultUser = username;

  networking.hostName = "atlas";
  nix.settings.experimental-features = ["nix-command" "flakes"];

  system.stateVersion = "26.05";
}
