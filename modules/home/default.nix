{
  # The home toolbox: every reusable home-manager feature module. Each defines
  # a `ciznia.<feature>.enable` flag and gates its config behind it, so importing
  # them all is inert until a recipe (home/*.nix) flips the flags.
  imports = [
    ./apps.nix
    ./cli.nix
    ./desktop
    ./dev.nix
    ./gaming.nix
    ./git.nix
    ./k8s.nix
    ./machine-keys.nix
    ./nvim.nix
    ./passwords.nix
    ./rbw.nix
    ./secrets.nix
    ./shell.nix
    ./terminal.nix
    ./theme.nix
    ./vscode
    ./zen.nix
  ];
}
