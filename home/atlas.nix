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

  # Zen through WSLg, while trying it next to Firefox.
  ciznia.zen.enable = true;

  # VS Code is the Windows app; Nix fills the server it runs in WSL.
  ciznia.vscode.server = {
    enable = true;
    # Pinned to the Windows app's build; bump with it (see modules/home/vscode/default.nix).
    pin.enable = true;
  };

  # The Claude desktop app runs on Windows and reads its own ~/.claude.
  ciznia.claude.windows = {
    enable = true;
    configDir = "/mnt/c/Users/hosqu/.claude";
    context = ''
      # Windows side of atlas

      This session runs on the Windows host of atlas. The repos live in
      NixOS-WSL under `\\wsl.localhost\nixos\home\ciznia` (`~` there), and
      Windows has no key GitHub accepts.

      - Run git, cargo and nix inside WSL, as ciznia:
        `wsl.exe -d nixos -- bash -lc 'cd ~/<repo> && git ...'`. Git run from
        Windows on the `\\wsl.localhost` path fails with "dubious ownership".
      - Variables in that command expand in the Windows-side shell first: pass a
        script on stdin (`wsl.exe -d nixos -- bash -s <<'EOF' ... EOF`) when it
        uses `$`.
      - Python on Windows is `python3.14`; neither `python` nor `python3` is on PATH.
    '';
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
