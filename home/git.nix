{ ... }:
{
  programs.git = {
    enable = true;
    userName = "Ciznia";
    userEmail = "gabriel.hosquet" + "@" + "epitech.eu";

    extraConfig.url = {
      init = {
        defaultBranch = "main";
      };

      "ssh://git@github.com/" = {
        insteadOf = "https://github.com/";
      };
    };

    ignores = [
      # C commons
      ".cache"
      "compile_commands.json"
      ".fast"
      "*.gc??"
      "vgcore.*"
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
      # Nix buid
      "result"
      # IDE Folders
      ".idea"
      ".vscode"
      ".vs"
    ];
  };
}
