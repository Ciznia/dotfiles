{lib, ...}: {
  imports = [../modules/home];

  # Shared baseline — enabled with mkDefault so any host recipe can turn a piece
  # off with a plain `= false` (see docs/NIX.md). git pulls in gpg + agent.
  ciznia.git.enable = lib.mkDefault true;

  # Auto-load ssh/gpg keys into the agent from the vault (login + every 20h).
  ciznia.agent.enable = lib.mkDefault true;
}
