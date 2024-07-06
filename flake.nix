{
  description = "Ciznia dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";

    config = {
      ussename = "ciznia";
      hostname = "cizchine";
    };

    pkgs = import nixpkgs ({
      inherit system;
      config.allowUnfree = true;
    });
  in {
    formatter.${system} = pkgs.nixpkgs-fmt;
    nixosConfigurations.${config.hostname} = nixpkgs.lib.nixosSystem {
      specialArgs = config // { inherit pkgs; };

      modules = [
        ./system
        ./hardware-configuration.nix
      ] ++ [
        { networking.hostName = config.hostname; }
      ];
    };
  };
}
