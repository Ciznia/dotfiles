{username, ...}: {
  # NixOS-WSL system. The nixos-wsl module and home-manager are wired by mkHost.
  wsl.enable = true;
  wsl.defaultUser = username;

  networking.hostName = "atlas";
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Keep ciznia's systemd *user* instance running even with no login session
  # open, so the agent-preload timer (login + every 20h) keeps refreshing the
  # key cache in the background. Without lingering, user services/timers only
  # run while a shell/session is active. (Declarative `loginctl enable-linger`.)
  users.users.${username}.linger = true;

  system.stateVersion = "26.05";
}
