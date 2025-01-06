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
      # Project config file
      ".fast"
      "ecsls.toml"
      ".pre-commit-config.yaml"
      "compile_commands.json"

      # C commons
      ".cache"
      "*.gc??"
      "vgcore.*"

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
      # Nix buid
      "result"
      # IDE Folders
      ".idea"
      ".vscode"
      ".vs"
    ];
  };
}
