{ ... }:
{
  programs.git = {
    enable = true;
    userName = "Ciznia";
    userEmail = "gabriel.hosquet" + "@" + "epitech.eu";

    extraConfig = {
      init = {
        defaultBranch = "main";
      };

      url = {
        "ssh://git@github.com/" = {
          insteadOf = "https://github.com/";
        };
      };
    };

    ignores = [
      # C commons
      ".cache"
      "compile_commands.json"
      ".pre-commit-config.yaml"
      ".fast"
      "*.gc??"
      "vgcore.*"
      "ecsls.toml"
      # C build
      "*.[oda]"
      # Python
      "venv"
      # Locked Files
      "*~"
      "#*#"
      # Mac folder
      ".DS_Store"
      # Direnv
      ".direnv"
      ".envrc"
      # Nix build
      "result"
      # IDE Folders
      ".idea"
      ".vscode"
      ".vs"
    ];
  };
}
