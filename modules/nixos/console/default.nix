{
  config,
  lib,
  pkgs,
  ...
}: {
  options.ciznia.console.enable = lib.mkEnableOption "TTY look (terminus font, palette, /etc/issue)";

  config = lib.mkIf config.ciznia.console.enable {
    catppuccin.tty.enable = false; # own palette below
    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-116n.psf.gz";
      packages = [pkgs.terminus_font];
      colors = [
        "11111E" # black
        "E12541" # red
        "14C67B" # green
        "FFAC7D" # yellow
        "7270FF" # blue
        "FD8DFF" # magenta
        "75DFED" # cyan
        "A4B1E3" # white

        "474B77" # light black
        "DE6876" # light red
        "63D961" # light green
        "FFDA8D" # light yellow
        "AAA9FA" # light blue
        "E5A5FB" # light magenta
        "BEEDF8" # light cyan
        "DBE2FB" # light white
      ];
    };

    environment.etc.issue.text = builtins.readFile ./issue;
  };
}
