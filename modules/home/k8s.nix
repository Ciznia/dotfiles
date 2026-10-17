{
  config,
  lib,
  pkgs,
  ...
}: {
  options.ciznia.k8s.enable = lib.mkEnableOption "kubernetes tools (kubectl, minikube)";

  config = lib.mkIf config.ciznia.k8s.enable {
    home.packages = with pkgs; [kubectl minikube];
    xdg.configFile."kubectl/kuberc".source = ./k8s/kuberc;
  };
}
