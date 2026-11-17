{
  config,
  lib,
  username,
  ...
}: let
  cfg = config.ciznia.virtualisation;
in {
  options.ciznia.virtualisation = {
    docker.enable = lib.mkEnableOption "docker";
    libvirt.enable = lib.mkEnableOption "libvirt + virt-manager";
    waydroid.enable = lib.mkEnableOption "waydroid (Android container)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.docker.enable {
      virtualisation.docker.enable = true;
      users.users.${username}.extraGroups = ["docker"];
    })
    (lib.mkIf cfg.libvirt.enable {
      virtualisation.libvirtd.enable = true;
      programs.virt-manager.enable = true;
      users.users.${username}.extraGroups = ["libvirtd"];
    })
    (lib.mkIf cfg.waydroid.enable {
      virtualisation.waydroid.enable = true;
    })
  ];
}
