{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;

    genSystems = lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

    eachSystem = f:
      genSystems (system:
        f (import nixpkgs {
          inherit system;
        }));
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
          openssl # To generate passwords

          # Keys
          gnupg # gpg: import/list secret keys (keys role)
          openssh # ssh-keygen: one-time key generation for the vault
          pass # password store: re-encrypt on GPG rotation (pass role)
        ];
      };
    });
  };
}
