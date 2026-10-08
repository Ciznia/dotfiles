# Nix — system & user configuration

Nix owns everything declarative: the OS on NixOS hosts, and the **user
environment** (home-manager) on every host. Secrets (ssh/gpg/pass) belong to
[ANSIBLE.md](ANSIBLE.md).

## Hosts

| Name (`--flake .#<name>`) | Machine                      | Base         | HM mode        |
|---------------------------|------------------------------|--------------|----------------|
| `glados`                  | Laptop (dual-boot), RTX 4060 | native NixOS | integrated     |
| `atlas`                   | Same laptop, Windows side    | NixOS-WSL    | integrated     |
| `pbody`                   | Desktop, Windows side        | Ubuntu + Nix | **standalone** |

`glados` and `atlas` are the **same physical laptop** — native-NixOS boot vs.
Windows + NixOS-WSL. `wheatley` is **reserved** for the desktop's future
*native NixOS*. Names are Portal-themed (`atlas`/`pbody` = the Co-op bots).

```bash
sudo nixos-rebuild switch --flake .#glados      # native NixOS
sudo nixos-rebuild switch --flake .#atlas       # NixOS-WSL
home-manager    switch --flake .#ciznia@pbody   # Ubuntu + Nix (standalone)
```

## Principle: standalone-first home config

The home-manager configuration is written as if it always runs **standalone**:
embedded into the system build on NixOS hosts, activated on its own on
non-NixOS hosts. So home modules use **only** home-manager options
(`programs.*`, `home.*`, `xdg.*`, user units via `systemd.user.*`). Anything
system-level — system services, the X session, GPU drivers — lives in
`modules/nixos/` or the host config, and the base distro provides it on
standalone hosts.

## Everything is a gated feature (`ciznia.*` options)

Every module, nixos and home, defines a `ciznia.<feature>.enable` option and
gates its `config` behind it. Modules are imported everywhere and stay inert
until a flag is on.

- **`modules/{home,nixos}/` = the toolbox** — each feature defined once,
  host-agnostic.
- **`home/` and `hosts/` = the recipes** — per-host assembly that flips flags
  and sets host-specific values.

`home/base.nix` sets the shared baseline with **`lib.mkDefault`**, so any host
can turn a shared feature off with a plain `= false`. Without `mkDefault`, a
host's `= false` would be a conflict, not an override. Host-only features (the
desktop) default to off and are enabled by their host.

## Adding a new system

1. **Write the recipe** — `home/<name>.nix`: `imports = [ ./base.nix ]`, flip any
   `ciznia.*` flags, set host-specific values.
2. **Register it** in `flake.nix`:
   - **NixOS** → add `hosts/<name>/default.nix` (+ `hardware-configuration.nix`
     from `nixos-generate-config`; nothing extra for WSL beyond `wsl = true`):

     ```nix
     nixosConfigurations.<name> = mkHost { name = "<name>"; wsl = <bool>; };
     ```

   - **Non-NixOS** → add the standalone contract to `home/<name>.nix`
     (`targets.genericLinux.enable`, `home.username`, `home.homeDirectory`,
     see `home/pbody.nix`):

     ```nix
     homeConfigurations."ciznia@<name>" = mkHome { modules = [ ./home/<name>.nix ]; };
     ```

3. **Build** with the matching command under [Hosts](#hosts).

`targets.genericLinux.enable` is the essential part of the standalone contract:
without it you get locale warnings and nix-installed apps that don't integrate
with the host.

## Channels

Unstable is primary (home-manager tracks `master` to match). Stable 26.05 is
pinned as a fallback, exposed as `pkgs.stable.<name>` for when an unstable
package is broken.

## glados

### Desktop

X11 + SDDM + qtile + PipeWire, gated by `ciznia.desktop.enable`
(`modules/nixos/desktop.nix` for the system half, `modules/home/desktop.nix`
for the user half). X11 rather than Wayland because of the NVIDIA hybrid GPU
and qtile's more mature X11 backend; the Wayland qtile session is removed so
SDDM can't pick it.

- **GPU:** NVIDIA RTX 4060 in PRIME **offload** mode: the iGPU drives the panel,
  `nvidia-offload <cmd>` runs a program on the dGPU. Bus IDs `PCI:0:2:0` (Intel)
  and `PCI:1:0:0` (NVIDIA); check with `lspci -nnk | grep -EA3 'VGA|3D'` if a
  driver update misbehaves.
- **Assets** (`assets/`) are **Git-LFS** tracked. Nix builds the checkout as-is,
  so a clone without git-lfs feeds pointer files to the desktop: the wallpaper
  never paints and the session *looks* frozen. The build fails on a pointer
  instead; fix the clone with `git lfs install --local && git lfs pull`.

### Screens

`services.autorandr` holds two EDID-matched profiles: **docked** (laptop `eDP-1`
at 0x0, HP X27c `HDMI-1-0` at 1920x0, primary, 164.92 Hz) and **mobile**
(laptop only). They apply on hotplug, after suspend, at X start and at session
start. The HDMI port is on the NVIDIA GPU, reached through reverse PRIME.

To change a layout: arrange it with `xrandr`, then
`autorandr --save docked --force`. Profiles in `~/.config/autorandr` override
the same-named ones from the config. `autorandr --fingerprint` prints the EDIDs
for a new screen.

### Login and lock screen

- **Greeter:** SDDM with `sddm-astronaut` playing `assets/lockscreen.mp4`
  (silent). `modules/nixos/sddm-astronaut-layout.patch` moves the form to the
  bottom-left and a small clock to the top-right. Preview without logging out:
  `sddm-greeter-qt6 --test-mode --theme /run/current-system/sw/share/sddm/themes/sddm-astronaut-theme`
  (power buttons are hidden in test mode only). `nixos-rebuild switch` doesn't
  restart SDDM: a new greeter shows after a reboot.
- **Lock:** xss-lock + xsecurelock with the same video (mpv per monitor, sound
  from the first only, following the system volume). Locks at 15 min idle, on
  suspend and on `loginctl lock-session` (Super+L); the screen turns off 5 min
  into the lock. Volume and mic-mute keys work while locked.
- **Hibernate:** resumes from the 16G swap partition (`boot.resumeDevice`).

### Dual boot clock

Windows keeps the hardware clock in local time by default, NixOS in UTC. Both
sides use UTC here:

- NixOS: `time.hardwareClockInLocalTime = false`. An `/etc/adjtime` that
  already says `LOCAL` isn't rewritten by it: run `sudo timedatectl set-local-rtc 0`
  once (or delete `/etc/adjtime`).
- Windows, admin prompt, then reboot:
  `reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f`

### Secure Boot

`modules/nixos/secureboot.nix` wires [lanzaboote](https://github.com/nix-community/lanzaboote)
behind `ciznia.secureBoot.enable`. Lanzaboote replaces systemd-boot and signs
the boot stub and each generation with keys enrolled in the firmware. Windows
isn't in the menu (it has its own ESP on the other NVMe, and systemd-boot has
no os-prober): boot it from the firmware menu (**F11**).

Enrollment is one-time and imperative, since the keys must never reach the Nix
store. To redo it (e.g. after a reinstall):

```bash
# 1. Keys first: lanzaboote signs at install time, so a switch without them fails.
sudo nix run nixpkgs#sbctl -- create-keys

# 2. Switch with Secure Boot still off, reboot, check NixOS and Windows (F11) boot.
sudo nixos-rebuild switch --flake .#glados
sudo sbctl verify

# 3. Put the firmware in Setup Mode (below), boot NixOS, then enroll.
#    --microsoft is required: Windows Boot Manager is signed by Microsoft.
sudo sbctl enroll-keys --microsoft

# 4. Turn Secure Boot on in the firmware, then:
bootctl status                    # expect: Secure Boot: enabled (user)
```

**Setup Mode on this MSI:** the option is in a hidden BIOS menu. Inside the
BIOS, press **right Ctrl + right Shift + left Alt + F2**; the Copilot key works
as right Ctrl. Then, under Secure Boot, use Reset To Setup Mode.

## Key auto-loading (`ciznia.agent`)

`modules/home/agent.nix` runs the Ansible `--tags agent` flow as a systemd user
service, 30s after login and every 20h (under the 24h gpg-agent cache TTL). It
unlocks the gpg and ssh keys in gpg-agent from the vault, so nothing is typed;
details in [ANSIBLE.md](ANSIBLE.md#loading-the-key-at-startup). It needs
`.vault_pass` at `ciznia.agent.repoPath` (default `~/dotfiles`).

**WSL needs lingering.** `wsl` shells never start a systemd *user* instance, so
without `users.users.<name>.linger = true` (set on atlas) neither gpg-agent nor
this timer runs. Linger makes the first `nixos-rebuild switch` exit nonzero;
the system still switches, and `wsl --terminate atlas` + reopen brings it up.

## Testing

**Fresh NixOS-WSL bootstrap** — `scripts/test-nixos-wsl.ps1` (Windows
PowerShell) imports a clean NixOS-WSL, clones the repo, runs the keys playbook
and switches to a host, deleting the instance if any step fails. Push the
branch first:

```powershell
./scripts/test-nixos-wsl.ps1 -Branch <branch>
```

**Graphical VM** — boots `glados` in QEMU with modesetting instead of NVIDIA,
no host disks, and a throwaway password. It doesn't exercise Secure Boot or the
real bootloader.

```bash
nix run .#glados-vm               # login: ciznia / test
ssh ciznia@localhost -p 2222      # logs, when the session misbehaves
```

Runs from WSL (WSLg shows the window) or any Linux; slow without nested KVM.
For the agent timer inside the VM, clone the repo to `~/dotfiles` and add
`.vault_pass` first.

## Secrets boundary

Nix stays secret-free: it may reference non-secret identity (git email, the
signing-key fingerprint), never key material. Keys are provisioned by the
Ansible preflight.
