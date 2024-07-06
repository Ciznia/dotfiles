{
  description = "Ciznia dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager}: let
    system = "x86_64-linux";

    config = {
      username = "ciznia";
      hostname = "cizchine";
    };

    pkgs = import nixpkgs ({
      inherit system;
      config.allowUnfree = true;
    });

    home-manager-config = {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${config.username} = import ./home;
          extraSpecialArgs = config // {
            inherit system pkgs;
          };
      };
    };
  in {
    formatter.${system} = pkgs.nixpkgs-fmt;
    nixosConfigurations.${config.hostname} = nixpkgs.lib.nixosSystem {
      specialArgs = config // { inherit pkgs; };

      modules = [
        ./system
        ./hardware-configuration.nix
      ] ++ [
        { networking.hostName = config.hostname; }
      ] ++ [
        home-manager.nixosModules.home-manager
        home-manager-config
      ];
    };
  };
}
