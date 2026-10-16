{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    nixos-wsl,
    lanzaboote,
    catppuccin,
    sops-nix,
    git-hooks,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;

    username = "ciznia";

    genSystems = lib.genAttrs ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    eachSystem = f: genSystems (system: f (import nixpkgs {inherit system;}));

    # Expose the pinned stable channel as pkgs.stable.* — an escape hatch for
    # when an unstable package is broken.
    stableOverlay = final: prev: {
      stable = import nixpkgs-stable {
        inherit (prev.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    };

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [stableOverlay];
      };

    homeSharedModules = [
      catppuccin.homeModules.catppuccin
      sops-nix.homeModules.sops
    ];

    # Standalone home-manager (non-NixOS hosts).
    mkHome = {
      system ? "x86_64-linux",
      modules,
    }:
      home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs system;
        extraSpecialArgs = {inherit inputs username;};
        modules = homeSharedModules ++ modules;
      };

    # Integrated NixOS host (native or WSL). Embeds the same home/<name>.nix via
    # home-manager, and pulls in the nixos-wsl module for WSL hosts.
    mkHost = {
      name,
      system ? "x86_64-linux",
      wsl ? false,
    }:
      lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs username;};
        modules =
          [
            ./hosts/${name}
            ./modules/nixos
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = [stableOverlay];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {inherit inputs username;};
              home-manager.sharedModules = homeSharedModules;
              home-manager.users.${username} = import ./home/${name}.nix;
            }
          ]
          ++ lib.optional wsl inputs.nixos-wsl.nixosModules.default;
      };
  in {
    formatter = eachSystem (pkgs: pkgs.alejandra);

    # `nix flake check` runs it; `nix develop` installs it as the git pre-commit hook.
    checks = genSystems (system: {
      pre-commit = git-hooks.lib.${system}.run {
        src = ./.;
        hooks.alejandra = {
          enable = true;
          excludes = ["hardware-configuration\\.nix$"]; # generated, kept as-is
        };
      };
    });

    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell {
        inherit (self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit) shellHook;
        packages = with pkgs; [
          # Nix
          alejandra

          # Other
          cowsay
          git
          git-lfs # LFS-backed assets (images/video/pdf)
          openssl # To generate passwords

          # Keys
          gnupg
          openssh # ssh-keygen
          pass # password store, until gopass replaces it
          rbw # Vaultwarden CLI: the gpg master key (scripts/machine-keys.sh)
          sops # edit secrets/secrets.yaml
          age # age-keygen: one key per machine (sops recipients)
        ];
      };
    });

    # Standalone home-manager targets (non-NixOS hosts):
    #   home-manager switch --flake .#ciznia@pbody
    homeConfigurations = {
      "${username}@pbody" = mkHome {modules = [./home/pbody.nix];};
    };

    # Integrated NixOS hosts:
    #   sudo nixos-rebuild switch --flake .#atlas
    nixosConfigurations = {
      atlas = mkHost {
        name = "atlas";
        wsl = true;
      };
      glados = mkHost {name = "glados";};
    };

    # Boot a host in QEMU to smoke-test before touching hardware:
    #   nix run .#glados-vm     (login: ciznia / test)
    apps.x86_64-linux.glados-vm = {
      type = "app";
      program = "${self.nixosConfigurations.glados.config.system.build.vm}/bin/run-glados-vm";
    };
  };
}
