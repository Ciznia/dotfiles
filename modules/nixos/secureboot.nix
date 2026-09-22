{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Secure Boot via lanzaboote: signs the systemd-boot stub + each generation's
  # kernel/initrd with your own enrolled key, so the firmware only boots what
  # you signed. Lanzaboote REPLACES the systemd-boot module (not layered on top
  # of it), so its module is imported unconditionally here (inert until
  # enabled) and forces `boot.loader.systemd-boot.enable` off when active.
  #
  # UNTESTED on real hardware — this only wires the Nix side. Enrolling keys is
  # a one-time, imperative, on-the-machine step (see docs/NIX.md) that can't be
  # expressed here, and the `glados-vm` QEMU smoke test does NOT exercise real
  # UEFI Secure Boot (no OVMF/TPM there) — only a real boot proves this works.
  imports = [inputs.lanzaboote.nixosModules.lanzaboote];

  options.ciznia.secureBoot.enable = lib.mkEnableOption "Secure Boot (signed boot chain via lanzaboote)";

  config = lib.mkIf config.ciznia.secureBoot.enable {
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    environment.systemPackages = [pkgs.sbctl]; # `sbctl status` / `sbctl verify`
  };
}
