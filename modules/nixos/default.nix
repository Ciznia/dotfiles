{
  # The NixOS toolbox: reusable system modules, each gated by a ciznia.* flag.
  # Pulled into every host by mkHost; inert until a host flips a flag.
  imports = [
    ./base.nix
    ./console
    ./desktop.nix
    ./fonts.nix
    ./gaming.nix
    ./laptop.nix
    ./secureboot.nix
    ./usb.nix
    ./virtualisation.nix
  ];
}
