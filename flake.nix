{
  description = "Ciznia dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs_unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    ecsls.url = "github:Sigmapitech/ecsls";
    ehcsls.url = "github:Sigmapitech/ehcsls";

    hosts.url = "github:StevenBlack/hosts";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    with inputs; let
      system = "x86_64-linux";
      cfg = {
        inherit system;
        config.allowUnfree = true;
      };

      pkgs = import nixpkgs.legacyPackages cfg;
      pkgs_unstable = import inputs.nixpkgs_unstable cfg;
    in
    {
      formatter.${system} = pkgs.nixpkgs-fmt;

      nixosConfigurations = {
        cizchine = nixpkgs.lib.nixosSystem
          (import ./cizchine.nix { inherit inputs system pkgs_unstable; });
      };
    };
}
