{ pkgs, ... }:
{
  home.packages = with pkgs; [ btop ];

  home.file.kubectl_config = {
    source = ./kuberc;
    target = ".config/kubectl/kuberc";
  };
}
