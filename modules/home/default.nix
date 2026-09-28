{
  # The home toolbox: every reusable home-manager feature module. Each defines
  # a `ciznia.<feature>.enable` flag and gates its config behind it, so importing
  # them all is inert until a recipe (home/*.nix) flips the flags.
  imports = [
    ./git.nix
    ./agent.nix
    ./desktop.nix
  ];
}
