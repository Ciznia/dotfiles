{
  description = "Ciznia dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vera-clang = {
      url = "github:Sigmapitech/vera-clang";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    ecsls = {
      url = "github:Sigmapitech/ecsls";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        utils.follows = "flake-utils";
        # Cannot use nested vera-clang.inputs.nixpkgs.follows
        # See https://github.com/NixOS/nix/issues/5790
        vera-clang.follows = "vera-clang";
      };
    };
  };

  outputs = { nixpkgs, home-manager, ecsls, ... }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs ({
      inherit system;
      config.allowUnfree = true;
    });

    config = {
      username = "ciznia";
      hostname = "cizchine";
    };

    home-manager-config = {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${config.username} = import ./home;
          extraSpecialArgs = config // {
            inherit system pkgs;

            lsps = { inherit ecsls; };
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
