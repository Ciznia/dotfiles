{ inputs, system, pkgs_unstable, ... }: with inputs;
let
  username = "cizniarova";
in
{
  inherit system;

  specialArgs = {
    inherit username;
    hostname = "cizchine";
  };

  modules =
    let
      home-manager-conf = {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${username} = import ./home;
          extraSpecialArgs = {
            inherit username system ecsls ehcsls pkgs_unstable;
          };
        };
      };

      hosts-conf = {
        networking.stevenBlackHosts.enable = true;
      };

      mod-nixhardware-lst = with nixos-hardware.nixosModules; [
        common-pc-laptop
        common-pc-ssd
      ];
    in
    [
      ./system
      ./hardware-configuration.nix
    ] ++ [
      home-manager.nixosModules.home-manager
      home-manager-conf
      hosts.nixosModule
      hosts-conf
    ] ++ mod-nixhardware-lst;
}
