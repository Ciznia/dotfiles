{username, ...}: {
  # NixOS-WSL system. The nixos-wsl module and home-manager are wired by mkHost.
  wsl.enable = true;
  wsl.defaultUser = username;

  networking.hostName = "atlas";
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # WSL never starts a systemd *user* instance for `wsl` shell sessions (no
  # login/PAM session -> no user bus), so home-manager user services
  # (gpg-agent, the agent-preload timer) would never run. Lingering starts
  # user@UID at boot instead. NOTE: this makes the *first* `nixos-rebuild switch`
  # exit nonzero (user@UID can't start mid-activation) — the system still
  # switches; `wsl --terminate atlas` then reopen brings it up cleanly.
  users.users.${username}.linger = true;

  system.stateVersion = "26.05";
}
