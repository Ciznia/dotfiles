# Nix — system & user configuration

Architecture of the Nix side and how to add a machine. Companion to
[ANSIBLE.md](ANSIBLE.md), which owns secrets (ssh/gpg/pass). Nix owns everything
declarative: the OS on NixOS hosts, and the **user environment** (home-manager)
on every host.

> Status: implemented for `atlas`, `glados` (base system), and `pbody`. The
> `glados` **desktop stack** (qtile / SDDM / lock) is still to build — see below.

## Principle: standalone-first home config

The home-manager configuration is written as if it always runs **standalone**.
On NixOS hosts it is embedded into the system build; on non-NixOS hosts
(Ubuntu + Nix) it is activated on its own. Consequences:

- Home modules use **only** home-manager options (`programs.*`, `home.*`,
  `xdg.*`, `fonts.*`, and **user** units via `systemd.user.*`) — never a NixOS
  option. Anything needing **system-level** config — *system* services
  (`services.*`, `systemd.services`), the qtile X session, GPU drivers — lives in
  `modules/nixos/` and simply doesn't exist on standalone hosts; the base distro
  provides that layer.
  - Note the user/system split: the agent loader is a `systemd.user` timer (a
    home option, so it's portable), while its `users.users.<name>.linger` toggle
    is system-level and lives in the host config.
- A non-NixOS host opts into a small **standalone contract** (below).

This keeps the user environment portable to any future non-NixOS machine.

## Hosts

| Name (`--flake .#<name>`) | Machine                      | Base         | HM mode        |
|---------------------------|------------------------------|--------------|----------------|
| `glados`                  | Laptop (dual-boot), RTX 4060 | native NixOS | integrated     |
| `atlas`                   | Same laptop, Windows side    | NixOS-WSL    | integrated     |
| `pbody`                   | Desktop, Windows side        | Ubuntu + Nix | **standalone** |

`glados` and `atlas` are the **same physical laptop** — native-NixOS boot vs.
Windows + NixOS-WSL. `pbody` is the separate desktop (currently offline).
`wheatley` is **reserved** for that desktop's future *native NixOS*. Names are
Portal-themed (`atlas`/`pbody` = the Co-op bots).

### Desktop stack (`glados`)

The `glados` **base** is implemented in `hosts/glados/` — GRUB (dual-boot with
os-prober), NVIDIA PRIME offload, and the FR/US keyboard. The **graphical stack
below is still to build**: it will live behind `ciznia.desktop.enable` (only
`glados` flips it on). Locked decisions:

- **Display server:** X11. Wayland is a later migration — NVIDIA laptop-hybrid
  \+ qtile's more mature X11 backend make X11 the pragmatic first target.
- **WM:** qtile (X11 backend).
- **Greeter:** SDDM, custom QML theme playing `assets/lockscreen.mp4`. Greeter
  audio is **muted** — pre-login has no user session whose mute state to follow.
- **Lock:** `xsecurelock` running `mpv` (looping `assets/lockscreen.mp4`), wired
  to idle/suspend via `xss-lock`. Audio goes through the user's sink, so it
  **follows the system mute** automatically (no `--mute`, no forced volume).
- **Wallpaper:** `assets/wallpaper.jpeg` (4K source, downscaled to the FHD panel).
- **GPU:** NVIDIA RTX 4060 Laptop (hybrid). `hardware.nvidia.prime` in
  **offload** mode (iGPU drives the display; dGPU on demand via `prime-run`):
  - `intelBusId  = "PCI:0:2:0";`
  - `nvidiaBusId = "PCI:1:0:0";`
  (verify with `lspci -nnk | grep -EA3 'VGA|3D'` if a driver update misbehaves).
- **Assets** live in `assets/` and are **Git-LFS** tracked.

Activation:

```bash
sudo nixos-rebuild switch --flake .#glados      # native NixOS
sudo nixos-rebuild switch --flake .#atlas       # NixOS-WSL
home-manager    switch --flake .#ciznia@pbody   # Ubuntu + Nix (standalone)
```

## The standalone contract (non-NixOS hosts)

A `type = "home"` recipe opts into the bits NixOS would otherwise provide:

```nix
# home/pbody.nix (illustrative)
{ ... }: {
  imports = [ ./base.nix ];
  targets.genericLinux.enable = true;   # locale + XDG + nix-profile integration on Ubuntu
  home.username      = "ciznia";
  home.homeDirectory = "/home/ciznia";
  home.stateVersion  = "26.05";
}
```

`targets.genericLinux.enable` is the essential one — without it you get locale
warnings and nix-installed apps that don't integrate with the host. `allowUnfree`
and the stable overlay are applied where the standalone `pkgs` is built (in
`mkHome`), since standalone HM constructs its own `pkgs`.

## Inputs & channels

Unstable is primary; stable (26.05) is pinned as a fallback, exposed through an
overlay as `pkgs.stable.*` for when an unstable package is broken.

```nix
inputs = {
  nixpkgs.url        = "github:NixOS/nixpkgs/nixos-unstable";   # primary
  nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";      # pinned fallback
  home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
  nixos-wsl    = { url = "github:nix-community/NixOS-WSL";     inputs.nixpkgs.follows = "nixpkgs"; };
};
# overlay: final: prev: { stable = import nixpkgs-stable { inherit (prev) system; config.allowUnfree = true; }; }
```

Use unstable by default; reach for `pkgs.stable.<name>` only when the unstable
build is broken. (Unstable requires tracking home-manager `master`, as above.)

## Layout

```txt
flake.nix            # inputs + inline helpers (mkPkgs/mkHome/mkHost, stable overlay) + outputs
flake.lock
hosts/
  atlas/default.nix                 # NixOS-WSL system (+ user linger)
  glados/default.nix                # GRUB, NVIDIA offload, keyboard
  glados/hardware-configuration.nix
modules/home/        # the home toolbox (gated ciznia.* modules)
  default.nix        # aggregator
  git.nix            # ciznia.git — git + gpg + gpg-agent (one flag)
  agent.nix          # ciznia.agent — auto-load keys from the vault (systemd timer)
home/                # the recipes (per-host assembly)
  base.nix           # shared baseline (mkDefault flags)
  atlas.nix          # NixOS-WSL
  glados.nix         # native NixOS (desktop stack later)
  pbody.nix          # Ubuntu+Nix standalone
scripts/
  test-nixos-wsl.ps1 # throwaway-instance bootstrap test (Windows)
assets/              # wallpaper + lockscreen video (Git-LFS)
docs/                # NIX.md, ANSIBLE.md, README.md
```

The `mkHost` / `mkHome` helpers and the `stable` overlay currently live inline
in `flake.nix`; extracting them to `lib/` + `overlays/` is a later cleanup. A
`modules/nixos/` toolbox will appear when the desktop stack needs system modules.

## Everything is a gated feature (`ciznia.*` options)

Every module — nixos and home — has the same shape: it **defines an enable
option and gates its `config` behind it**. Modules are imported *everywhere*;
their `config` only activates when the flag is on.

```nix
# modules/home/zsh.nix — the uniform template
{ config, lib, pkgs, ... }: {
  options.ciznia.zsh.enable = lib.mkEnableOption "zsh shell";
  config = lib.mkIf config.ciznia.zsh.enable {
    programs.zsh.enable = true;
    # …plugins, aliases, etc.
  };
}
```

Two folders, two jobs:

- **`modules/{home,nixos}/` = the toolbox** — each feature defined once,
  host-agnostic, gated by a `ciznia.*` flag.
- **`home/` (and `hosts/`) = the recipes** — per-host assembly that flips flags
  on/off and sets host-specific values.

### Shared vs override — and disabling a shared module

`home/base.nix` sets the shared baseline with **`lib.mkDefault`**, which is what
lets a host **override — including disable —** any of it:

```nix
# home/base.nix — shared baseline
{ lib, ... }: {
  imports = [ ../modules/home ];            # all home modules (gated, inert until enabled)
  ciznia.git.enable   = lib.mkDefault true; # shared: on by default…
  ciznia.agent.enable = lib.mkDefault true;
}

# a host that doesn't want the vault auto-loader (e.g. no vault there yet)
{ lib, ... }: {
  imports = [ ./base.nix ];
  ciznia.agent.enable = false;              # …disabled here (plain value beats mkDefault)
}
```

So yes: because shared defaults use `mkDefault`, any host can switch a shared
feature **off** with a plain `= false`.

> **Gotcha.** This only works with `mkDefault` in the base. If the base set a
> bare `= true`, a host's `= false` is a *conflict*, not an override. Use
> `lib.mkForce` only for the rare case of overriding a non-default value that an
> upstream (non-`ciznia`) module already set.

Host-only features (the GUI/qtile stack) skip the base entirely: their flag
defaults to `false` (via `mkEnableOption`), and only `glados` sets
`ciznia.desktop.enable = true`.

### The home modules, concretely

- `modules/home/git.nix` (`ciznia.git`) — git identity + commit signing, plus
  the `programs.gpg` and `services.gpg-agent` it depends on (one flag: signed
  commits need the key, the agent, and a pinentry). gpg-agent also serves ssh
  (`enableSshSupport`).
- `modules/home/agent.nix` (`ciznia.agent`) — auto-loads the ssh/gpg keys from
  the vault at login and every 20h (see below).
- Shells, editor, and the desktop stack land here later as their own gated
  modules.

`base.nix` enables `git` + `agent` by default; every host currently takes the
baseline as-is (`atlas`, `glados`, `pbody`).

## Adding a new system

1. **Write the recipe** — `home/<name>.nix`: `imports = [ ./base.nix ]`, flip any
   `ciznia.*` flags, set host-specific values.
2. **Pick the mode** and register it in `flake.nix`:
   - **NixOS** → add `hosts/<name>/default.nix` (+ a `hardware-configuration.nix`
     from `nixos-generate-config`; nothing extra for WSL beyond `wsl = true`):

     ```nix
     nixosConfigurations.<name> = mkHost { name = "<name>"; wsl = <bool>; };
     ```

   - **Non-NixOS** → add the standalone contract to `home/<name>.nix`
     (`targets.genericLinux.enable`, `home.homeDirectory`):

     ```nix
     homeConfigurations."ciznia@<name>" = mkHome { modules = [ ./home/<name>.nix ]; };
     ```

3. **Build:**
   - NixOS → `sudo nixos-rebuild switch --flake .#<name>`
   - Standalone → `home-manager switch --flake .#ciznia@<name>`

## Key auto-loading (`ciznia.agent`)

Signed commits and ssh need the keys unlocked in the agent — without typing
passphrases. `modules/home/agent.nix` runs the Ansible `--tags agent` flow via a
**systemd user service + timer**:

- Fires **30s after login** and **every 20h** — 4h under the 24h gpg-agent
  `max-cache-ttl`, so a machine left up for days never silently loses the cached
  passphrase (with a window to notice before it would).
- Presets the gpg passphrase (`gpg-preset-passphrase`) and ssh key (`ssh-add`)
  straight from the vault.
- On NixOS-WSL, `users.users.ciznia.linger = true` keeps the user systemd
  instance (and this timer) alive with no shell open.

Prereqs: keys already deployed (a full `keys.yml` run) and `.vault_pass` present
at `ciznia.agent.repoPath` (default `~/dotfiles`).

## Testing on a throwaway instance

`scripts/test-nixos-wsl.ps1` (run from **Windows PowerShell**) imports a fresh
NixOS-WSL, clones the repo, runs the keys playbook, and `nixos-rebuild switch`es
to a host — deleting the instance if any step fails. Push your branch first.

```powershell
./scripts/test-nixos-wsl.ps1 -Branch <branch>
```

## Secrets boundary

Nix stays secret-free: it declares config and may *reference* non-secret
identity (git `userEmail`, the signing-key fingerprint, default shell). Key
material (ssh/gpg/pass) is provisioned by the Ansible preflight — see
[ANSIBLE.md](ANSIBLE.md). Declarative Nix secrets (sops-nix / agenix) are a
possible later addition, out of scope for now.
