{lib, ...}: {
  imports = [../modules/home];

  # Shared baseline — enabled with mkDefault so any host recipe can turn a piece
  # off with a plain `= false` (see docs/NIX.md). git pulls in gpg + gpg-agent.
  ciznia = {
    git.enable = lib.mkDefault true;

    shell.enable = lib.mkDefault true;
    nvim.enable = lib.mkDefault true;
    cli.enable = lib.mkDefault true;
    dev.enable = lib.mkDefault true;
    k8s.enable = lib.mkDefault true;
    apps.enable = lib.mkDefault true;
    theme.enable = lib.mkDefault true;
  };
}
