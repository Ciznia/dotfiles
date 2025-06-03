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
      push.autoSetupRemote = "true";
    };

    ignores = [
      # Project config file
      ".fast"
      ".pre-commit-config.yaml"
      "compile_commands.json"

      # C commons
      ".cache"
      "*.gc??"
      "vgcore.*"

      # Python
      "venv"
      "__pycache__"
      # Locked Files
      "*~"
      "#*#"
      # Mac folder
      ".DS_Store"
      # Direnv
      ".direnv"
      ".*env*"
      "venv"
      # Nix buid
      "result"
      # IDE Folders
      ".idea"
      ".vscode"
      ".vs"
    ];
  };
}
