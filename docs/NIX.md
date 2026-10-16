# Nix — system & user configuration

Nix owns everything declarative: the OS on NixOS hosts, and the **user
environment** (home-manager) on every host. Tokens are sops-encrypted
(see [Secrets](#secrets)); ssh and gpg keys are per machine
(see [Machine keys](#machine-keys)).

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

What each host turns on:

| Flag                                                                     | glados | atlas | pbody |
|--------------------------------------------------------------------------|:------:|:-----:|:-----:|
| home: `git`, `rbw`, `machineKeys`, `shell`, `nvim`, `cli`, `dev`, `k8s`, `apps`, `theme` |   ✓    |   ✓   |   ✓   |
| home: `gaming`                                                           |   ✓    |       |   ✓   |
| home: `desktop` (qtile, kitty, dunst, lock)                              |   ✓    |       |       |
| nixos: `base`, `fonts`, `virtualisation.docker`                          |   ✓    |   ✓   |       |
| nixos: `console`, `desktop`, `gaming`, `laptop`, `usb`, `secureBoot`, `virtualisation.{libvirt,waydroid}` | ✓ | | |

`ciznia.shell.prompt` picks the prompt: `"atomic"` (oh-my-posh, default) or
`"sigma"` (oh-my-zsh theme). Theming is catppuccin macchiato
([catppuccin/nix](https://github.com/catppuccin/nix)), except where a program
keeps its own colors (kitty, dunst, the TTY palette, the SDDM greeter).

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
(`modules/nixos/desktop.nix` for the system half, `modules/home/desktop/`
for the user half; the qtile config is `modules/home/qtile/`). X11 rather than Wayland because of the NVIDIA hybrid GPU
and qtile's more mature X11 backend; the Wayland qtile session is removed so
SDDM can't pick it.

- **GPU:** NVIDIA RTX 4060 in PRIME **offload** mode: the iGPU drives the panel,
  `nvidia-offload <cmd>` runs a program on the dGPU. Bus IDs `PCI:0:2:0` (Intel)
  and `PCI:1:0:0` (NVIDIA); check with `lspci -nnk | grep -EA3 'VGA|3D'` if a
  driver update misbehaves.
- **Power:** TLP, from the nixos-hardware `common-pc-laptop` preset (with
  `common-pc-ssd` for weekly fstrim and `common-cpu-intel`).
- **Keys** that aren't obvious: Super+N opens the unread notifications,
  Super+P / Super+Shift+P handle screens (below), Super+L locks, Super+T
  toggles the touchpad, Super+Space drops down a terminal.
- **Assets** (`assets/`) are **Git-LFS** tracked. Nix builds the checkout as-is,
  so a clone without git-lfs feeds pointer files to the desktop: the wallpaper
  never paints and the session *looks* frozen. The build fails on a pointer
  instead; fix the clone with `git lfs install --local && git lfs pull`.

### Screens

`services.autorandr` holds two EDID-matched profiles: **docked** (laptop `eDP-1`
at 0x0, HP X27c `HDMI-1-0` at 1920x0, primary, 164.92 Hz) and **mobile**
(laptop only). They apply on hotplug, after suspend, at X start and at session
start. The HDMI port is on the NVIDIA GPU, reached through reverse PRIME.

Shortcuts, numbered by `ciznia.desktop.displayProfiles` (1 = docked,
2 = mobile; higher digits save/load `profile<N>`):

- **Super+P**, then a digit loads that profile, or **Enter** opens arandr. arandr
  runs through `nvidia-offload`: started on the iGPU it doesn't see the HDMI
  port.
- **Super+Shift+P**, then a digit saves the current layout under it
  (`autorandr --save <name> --force`).

Both show the profile map in a notification while waiting for the digit; Esc
cancels. Saved profiles land in `~/.config/autorandr` and override the
same-named ones from the config. `autorandr --fingerprint` prints the EDIDs
for a new screen.

### Notifications

dunst popups still time out, but every notification is also appended to
`~/.local/state/notifications/unread.jsonl`, so the list survives logout and
reboot. The bar shows the unread count; **Super+N** (or a click on the count)
lists them in rofi, to open one or mark it read.

"Open" shows the notification again while the dunst instance that received it
still holds it, so a click runs the sending app's own action. After a restart
of dunst (or a reboot) it opens the notification's first link, or launches the
app that sent it; the exact item can't be reopened then.

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

## WSL

**WSL needs lingering.** `wsl` shells never start a systemd *user* instance, so
without `users.users.<name>.linger = true` (set on atlas) gpg-agent and other
user services don't run. Linger makes the first `nixos-rebuild switch` exit nonzero;
the system still switches, and `wsl --terminate NixOS` + reopen brings it up.

**WSLg hides the default user's runtime dir.** WSLg mounts its own tmpfs over
`/run/user/<uid>` of the WSL default user, on top of systemd's: the user bus
(`systemctl --user`) and sops-nix's secrets vanish under it. On atlas the
`wslg-runtime-dir` unit drops that layer at boot, before `user@<uid>` starts
(or the user bus lands in the layer it removes), and re-links WSLg's Wayland and
PulseAudio sockets into systemd's dir. It only runs at boot (an open shell
holds sockets in WSLg's layer), so apply a change to it with
`switch-to-configuration boot` and `wsl --terminate NixOS`.

## Testing

**Fresh NixOS-WSL bootstrap** — `scripts/test-nixos-wsl.ps1` (Windows
PowerShell) imports a clean NixOS-WSL, clones the repo and switches to a host,
deleting the instance if any step fails. The instance is no sops recipient, so
its `sops-nix.service` fails; the switch itself doesn't. Push the
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

## Secrets

Tokens live encrypted in `secrets/secrets.yaml` (sops, key names in clear,
values encrypted) and are decrypted at login by sops-nix (`ciznia.secrets`, a
home-manager user service, `sops-nix.service`):

| Secret             | Lands at                                                  |
|--------------------|-----------------------------------------------------------|
| `wakatime_api_key` | `~/.wakatime.cfg`, rendered from a template (only with `ciznia.secrets.wakatime.enable`) |

Each machine has **its own age key** in `~/.config/sops/age/keys.txt`, never
committed, and `.sops.yaml` lists every machine's public key. A leaked key then
points at one machine, and removing it from `.sops.yaml` cuts that machine off.
Only turn `ciznia.secrets.enable` on for a host once it is a recipient.

**Adding a machine.** On the new machine:

```bash
nix develop                                   # sops + age
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt     # prints the public key (age1...)
```

Add that public key to `.sops.yaml`, then on a machine that already decrypts
re-encrypt the file for the new list, and push:

```bash
sops updatekeys secrets/secrets.yaml
```

Enable `ciznia.secrets` in the host's `home/<host>.nix` and switch.

**The first machine** has nothing to re-encrypt: add its key to `.sops.yaml`,
then `sops secrets/secrets.yaml` opens an empty file in `$EDITOR`. Fill in the
names above and save.

Recipients today: **atlas**.

**Editing** a value: `sops secrets/secrets.yaml` on any recipient machine.

Nix itself stays secret-free: it may reference non-secret identity (git email,
the signing-key fingerprint), never key material.

## Machine keys

Each machine has **its own ssh key and gpg signing subkey**, so retiring one
machine revokes only its keys. The gpg master key
(`A8A7205E2FD4672A77058657654E6EA7882F6671`) is never on a machine: it lives
in Vaultwarden (vault.hosquet.com, item `gpg master key`, armored in the notes)
and is only pulled into a throwaway keyring to certify a new subkey. Every
machine also gets the master's encryption subkey, for the password store.

On a new machine nothing needs remembering (`ciznia.machineKeys`): after the switch,
which only prints a reminder, the next interactive shell that finds no ssh key of this machine's own (none, or the old
sops link) or no gpg signing subkey of its own asks to run
`scripts/machine-keys.sh` (from `~/dotfiles`, see `ciznia.machineKeys.repo`).
Answer `y` and type the Vaultwarden password; the prompt stays silent once both
exist. Both keys come from the script in one go, so they reach GitHub together.
It can't run during the switch: activation has no terminal to ask in.

The script generates `~/.ssh/id_ed25519` (no passphrase) unless this machine
already has one, adds a signing subkey without expiry, keeps only the subkeys in
`~/.gnupg`, and writes the public key, with every machine's subkey, to
`keys/gpg.asc`. Then:

1. Add the printed ssh public key on GitHub.
2. Commit `keys/gpg.asc`, and on GitHub replace the gpg key with it. Already
   verified commits stay verified.

git signs with the master's fingerprint, without `!`, so gpg picks the newest
signing subkey whose secret is on the machine: its own. No per-host pin.

On the first machine, where the full master is still in the keyring and not yet
in Vaultwarden, the script uploads it first (`store-master` does only that).

**Retiring a machine:** delete its ssh key on GitHub, and revoke its subkey
(`gpg --edit-key`, `key N`, `revkey`, in a keyring with the master), then
publish `keys/gpg.asc` again.
