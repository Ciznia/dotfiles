{
  config,
  lib,
  ...
}: {
  # The games themselves are home packages (modules/home/gaming.nix).
  options.ciznia.gaming.enable = lib.mkEnableOption "Steam (+ 32-bit audio for it)";

  config = lib.mkIf config.ciznia.gaming.enable {
    programs.steam.enable = true;
    services.pipewire.alsa.support32Bit = true;
  };
}
