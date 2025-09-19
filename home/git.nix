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
      push = {
        autoSetupRemote = true;
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
      "__pycache__"
      # Web
      "node_modules"
      "dist"
      "build"
      "out"
      ".vite"
      ".next"
      ".cursor"
      # Direnv
      ".direnv"
      ".envrc"
      # Environment files
      "*env*"
      # Locked Files
      "*~"
      "#*#"
      # Mac folder
      ".DS_Store"
      # Nix build
      "result"
      # IDE Folders
      ".idea"
      ".vscode"
      ".vs"
    ];
  };
}
