{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.agent;
in {
  options.ciznia.agent = {
    enable = lib.mkEnableOption "auto-load ssh/gpg keys into the agent from the vault";

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/dotfiles";
      description = "Dotfiles repo path — where ansible.cfg and .vault_pass live.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Runs `ansible-playbook … --tags agent`, which ssh-adds the key and presets
    # the gpg passphrase from the vault (no prompt). Assumes the keys are already
    # on disk (a full `keys.yml` run) and .vault_pass is present at repoPath.
    systemd.user.services.agent-preload = {
      Unit = {
        Description = "Load ssh/gpg keys into the agent from the Ansible vault";
        After = ["gpg-agent.socket"];
      };
      Service = {
        Type = "oneshot";
        WorkingDirectory = cfg.repoPath;
        Environment = [
          "PATH=${lib.makeBinPath [pkgs.ansible pkgs.openssh pkgs.gnupg]}"
          # Point ssh-add at gpg-agent's ssh socket (enableSshSupport).
          "SSH_AUTH_SOCK=%t/gnupg/S.gpg-agent.ssh"
        ];
        ExecStart = "${pkgs.ansible}/bin/ansible-playbook ansible/playbooks/keys.yml --tags agent";
      };
    };

    # Re-run at login and every 20h — 4h under the 24h gpg-agent max-cache-ttl,
    # so a machine left up for days never silently loses the cached passphrase
    # (and there's a window to notice/fix before it would expire).
    systemd.user.timers.agent-preload = {
      Unit.Description = "Refresh the agent key cache before the gpg-agent TTL expires";
      Timer = {
        OnStartupSec = "30s"; # shortly after login (agent up)
        OnUnitActiveSec = "20h"; # then every 20h
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
