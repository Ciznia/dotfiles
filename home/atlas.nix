{
  lib,
  pkgs,
  ...
}: {
  imports = [./base.nix];

  # atlas is a recipient in .sops.yaml.
  ciznia.secrets = {
    enable = true;
    wakatime.enable = true;
  };

  # VS Code is the Windows app; Nix fills the server it runs in WSL.
  ciznia.vscode.server = {
    enable = true;
    # Pinned to the Windows app's build; bump with it (see modules/home/vscode.nix).
    pin.enable = true;
  };

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
