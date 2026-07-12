{
  # The NixOS toolbox: reusable system modules, each gated by a ciznia.* flag.
  # Pulled into every host by mkHost; inert until a host flips a flag.
  imports = [
    ./desktop.nix
  ];
}
