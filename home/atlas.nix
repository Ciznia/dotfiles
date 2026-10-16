{
  lib,
  pkgs,
  ...
}: {
  imports = [./base.nix];

  # atlas has its own ssh and gpg keys, in secrets/atlas.yaml (only atlas's age
  # key opens it). Both public keys must be on GitHub before switching to new ones.
  ciznia.secrets = {
    enable = true;
    host = "atlas";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9Lkz/3C5KYqv067hsSPmXTNCJ02rMwp+ymczfrJg9B ciznia@atlas";
  };
  ciznia.git.signingKey = "65F760D15A304908430413A797B33F9DA33E7624";

  # atlas: NixOS-WSL, integrated home-manager. username/homeDirectory come from
  # the system user (ciznia, via wsl.defaultUser), so no standalone contract.

  # VS Code's remote server sources this file: it needs wget on PATH, and
  # `code --wait` as the editor in its terminals.
  home.file.".vscode-server/server-env-setup".text = ''
    export PATH=$PATH:${lib.makeBinPath [pkgs.wget]}
    export EDITOR="code --wait"
  '';

  home.stateVersion = "26.05";
}
