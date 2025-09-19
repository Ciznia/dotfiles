{
  description = "Ciznia dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    vera-clang = {
      url = "github:Sigmapitech/vera-clang";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    catppuccin = {
      type = "github";
      owner = "catppuccin";
      repo = "nix";
    };

    ecsls.url = "github:Sigmapitech/ecsls";

    ehcsls.url = "github:Sigmapitech/ehcsls";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wsl-nixos = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:nix-community/NixOS-WSL";
    };
  };

  outputs =
    { nixpkgs
    , home-manager
    , nixos-hardware
    , flake-utils
    , pre-commit-hooks
    , ecsls
    , ehcsls
    , catppuccin
    , wsl-nixos
    , ...
    }:
    let
      username = "ciznia";
      system = "x86_64-linux";

      pkgs = import nixpkgs ({
        inherit system;
        config.allowUnfree = true;
      });

      home-manager-config = {
        home-manager = {
          useUserPackages = true;
          users.${username}.imports = [
            catppuccin.homeModules.catppuccin
            ./home
          ];

          extraSpecialArgs = {
            inherit catppuccin username system ecsls ehcsls pkgs;
          };
        };
      };

    in
    flake-utils.lib.eachSystem [ system ]
      (system: rec {
        formatter = pkgs.nixpkgs-fmt;

        checks.pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks.nixpkgs-fmt = {
            enable = true;
            name = pkgs.lib.mkForce "Nix files format";
          };
        };

        devShells.default = pkgs.mkShell {
          inherit (checks.pre-commit-check) shellHook;
          packages = [ pkgs.python312Packages.qtile ];
        };

        packages = {
          screenshot-system = import ./screenshot.nix {
            inherit nixpkgs pkgs home-manager-config;
            inherit (home-manager.nixosModules) home-manager;
          };

          qwerty-fr = pkgs.callPackage ./system/qwerty-fr.nix { };
        };
      })
    // (
      let
        nhw-mod = nixos-hardware.nixosModules;

        mk-base-paths = hostname:
          let
            key = pkgs.lib.toLower hostname;
          in
          [
            ./system/_${key}.nix
            ./hardware/${key}.hardware-configuration.nix
          ];


        mk-system = hostname: specific-modules:
          nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit catppuccin username;
            };

            modules = [ ./system ] ++ (mk-base-paths hostname) ++ [
              { networking.hostName = hostname; }
              { nixpkgs.hostPlatform = system; }
            ] ++ [
              catppuccin.nixosModules.catppuccin
              home-manager.nixosModules.home-manager
              home-manager-config
            ] ++ specific-modules;
          };
      in
      {
        nixosConfigurations = {
          Sigmachine = mk-system "Sigmachine" (with nhw-mod; [
            common-pc-laptop
            common-cpu-intel
            common-pc-ssd
          ]);

          Bacon = mk-system "Bacon" (with nhw-mod; [
            common-cpu-intel
            common-pc-ssd
          ]);

          Toaster = mk-system "Toaster" [ ];

          Cizchine = mk-system "Cizchine" (with nhw-mod; [
            common-pc-laptop
            common-cpu-intel
            common-pc-ssd
          ]);

	  WSL = nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit catppuccin username;
            };

            modules = [ ./configuration.nix ] ++ [
              { networking.hostName = "WSL"; }
              { nixpkgs.hostPlatform = system; }
            ] ++ [
	            wsl-nixos.nixosModules.wsl
              catppuccin.nixosModules.catppuccin
              home-manager.nixosModules.home-manager
              home-manager-config
            ];
          };
        };
      }
    );
}
