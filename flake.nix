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
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    nixos-wsl,
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
        inherit (prev) system;
        config.allowUnfree = true;
      };
    };

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [stableOverlay];
      };

    # Standalone home-manager (non-NixOS hosts). NixOS hosts will embed the same
    # home/<host>.nix via home-manager.nixosModules instead — added once the
    # machines' hardware/WSL configs are available (see docs/NIX.md).
    mkHome = {
      system ? "x86_64-linux",
      modules,
    }:
      home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs system;
        extraSpecialArgs = {inherit inputs username;};
        inherit modules;
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
            home-manager.nixosModules.home-manager
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = [stableOverlay];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {inherit inputs username;};
              home-manager.users.${username} = import ./home/${name}.nix;
            }
          ]
          ++ lib.optional wsl inputs.nixos-wsl.nixosModules.default;
      };
  in {
    formatter = eachSystem (pkgs: pkgs.alejandra);

    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          # Ansible
          ansible
          ansible-lint
          cowsay

          # Gives a stable `python3` on PATH for
          # `ansible_python_interpreter: "{{ ansible_playbook_python }}"`,
          # instead of a hardcoded FHS path like /usr/bin/python3 that
          # doesn't exist on NixOS.
          python3

          # Nix
          alejandra

          # Other
          git
          git-lfs # LFS-backed assets (images/video/pdf)
          openssl # To generate passwords

          # Keys
          gnupg # gpg: import/list secret keys (keys role)
          openssh # ssh-keygen: one-time key generation for the vault
          pass # password store: re-encrypt on GPG rotation (pass role)
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
