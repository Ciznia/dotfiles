{
  config,
  lib,
  pkgs,
  ...
}: {
  options.ciznia.k8s.enable = lib.mkEnableOption "kubernetes cli (kubectl)";

  config = lib.mkIf config.ciznia.k8s.enable {
    home.packages = with pkgs; [kubectl];
    xdg.configFile."kubectl/kuberc".source = ./k8s/kuberc;
  };
}
