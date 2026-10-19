{
  config,
  lib,
  pkgs,
  ...
}: let
  # Appends every notification to ~/.local/state/notifications/unread.jsonl.
  notifLog = pkgs.writeShellApplication {
    name = "notif-log";
    runtimeInputs = with pkgs; [coreutils jq util-linux];
    text = builtins.readFile ./scripts/notif-log.sh;
  };

  # Super+N / the bar counter: open or mark read what notif-log kept.
  notifMenu = pkgs.writeShellApplication {
    name = "notif-menu";
    runtimeInputs = with pkgs; [coreutils jq util-linux rofi dunst libnotify xdg-utils gtk3];
    text = builtins.readFile ./scripts/notif-menu.sh;
  };
in {
  # Popups still time out, but every notification also lands in an unread list
  # that survives logout and reboot until it is marked read (see the scripts).
  config = lib.mkIf config.ciznia.desktop.enable {
    home.packages = [notifMenu];

    # catppuccin's dunst drop-in would override the colors below.
    catppuccin.dunst.enable = false;

    services.dunst = {
      enable = true;
      settings = {
        global = {
          alignment = "left";
          always_run_script = true;
          # The default browser: Zen while trying it (modules/home/zen), else Firefox.
          browser =
            if config.ciznia.zen.enable
            then lib.getExe config.programs.zen-browser.finalPackage
            else "${pkgs.firefox}/bin/firefox";

          font = "JetBrainsMono Nerd Font Mono 10";
          frame_color = "#8AADF4";
          separator_color = "frame";

          icon_path = lib.mkForce "-"; # no icons (home-manager sets a default path)
          indicate_hidden = "yes";

          mouse_left_click = "do_action, close_current";
          mouse_middle_click = "do_action, close_current";
          mouse_right_click = "close_all";

          corner_radius = 4;
          frame_width = 2;
          horizontal_padding = 14;
          padding = 8;
          separator_height = 2;

          show_indicators = "yes";
          sticky_history = "no";
          vertical_alignment = "center";
          word_wrap = "yes";
        };

        urgency_low = {
          background = "#0D0D1680";
          foreground = "#8AADF4";
          timeout = 10;
        };

        urgency_normal = {
          background = "#0D0D1680";
          foreground = "#EED49F";
          timeout = 15;
        };

        urgency_critical = {
          background = "#0D0D1680";
          foreground = "#ED8796";
          timeout = 30;
        };

        # Matches every notification (appname is a glob).
        log = {
          appname = "*";
          script = "${notifLog}/bin/notif-log";
        };
      };
    };
  };
}
