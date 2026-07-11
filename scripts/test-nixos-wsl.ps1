<#
.SYNOPSIS
  Spin up a throwaway NixOS-WSL instance, bootstrap the dotfiles end to end
  (clone -> ansible keys playbook -> nixos-rebuild switch), and tear the
  instance down if ANY step fails.

.DESCRIPTION
  Run from Windows PowerShell (not from inside WSL). The instance is a clean
  NixOS-WSL rootfs, so this exercises the real first-boot path a reset atlas
  would take.

  Prerequisites:
    * The branch you want to test is PUSHED to the repo, with flake.lock
      committed (nixos-rebuild --flake needs the lock).
    * The repo is cloneable over HTTPS (public, or you'll be prompted to auth).
    * .vault_pass exists locally (it's git-ignored, so it's injected by hand).

.EXAMPLE
  ./scripts/test-nixos-wsl.ps1 -Branch great-reset
#>
[CmdletBinding()]
param(
  [string]$Name = 'nixos-test',
  [string]$Repo = 'https://github.com/ciznia/dotfiles.git',
  [string]$Branch = 'main',
  [string]$HostAttr = 'atlas',
  [string]$Tarball = '',  # empty -> download the latest NixOS-WSL rootfs
  [string]$VaultPass = 'C:\Users\hosqu\git\dotfiles\.vault_pass',
  [switch]$RemoveOnSuccess
)

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'  # make `wsl -l -q` output parseable UTF-8

$installDir = Join-Path $env:LOCALAPPDATA "WSL\$Name"
$created = $false

# Convert the Windows vault path to its /mnt/<drive> form for use inside WSL.
$vaultWsl = '/mnt/' + $VaultPass.Substring(0, 1).ToLower() + ($VaultPass.Substring(2) -replace '\\', '/')

function Remove-Instance {
  Write-Host "==> Removing WSL instance '$Name'" -ForegroundColor Yellow
  wsl --terminate $Name 2>$null | Out-Null
  wsl --unregister $Name 2>$null | Out-Null
  if (Test-Path $installDir) { Remove-Item -Recurse -Force $installDir -ErrorAction SilentlyContinue }
}

# Run a bash login command inside the instance as root; throw on nonzero exit.
function Invoke-InWsl([string]$Script, [String]$User = 'root') {
  wsl -d $Name -u $User -- bash -lc $Script
  if ($LASTEXITCODE -ne 0) { throw "WSL step failed (exit $LASTEXITCODE): $Script" }
}

try {
  if (-not (Test-Path $VaultPass)) { throw "Vault password file not found: $VaultPass" }

  # Nuke any leftover instance of the same name.
  if ((wsl -l -q) -contains $Name) {
    Write-Host "==> Existing '$Name' found — removing first"
    Remove-Instance
  }

  # Fetch the NixOS-WSL rootfs (override with -Tarball if the asset name changed).
  if (-not $Tarball) {
    $Tarball = Join-Path $env:TEMP 'nixos.wsl'
    Write-Host "==> Downloading latest NixOS-WSL rootfs -> $Tarball"
    Invoke-WebRequest -UseBasicParsing `
      -Uri 'https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl' `
      -OutFile $Tarball
  }

  Write-Host "==> Importing '$Name'"
  New-Item -ItemType Directory -Force -Path $installDir | Out-Null
  wsl --import $Name $installDir $Tarball --version 2
  if ($LASTEXITCODE -ne 0) { throw 'wsl --import failed' }
  $created = $true

  $flakes = "export NIX_CONFIG='experimental-features = nix-command flakes'"

  # Clone over HTTPS (no ssh key yet) and inject the git-ignored vault password.
  Write-Host "==> Cloning $Repo ($Branch)"
  Invoke-InWsl "$flakes; export GIT_LFS_SKIP_SMUDGE=1; nix shell nixpkgs#git --command git clone -b '$Branch' '$Repo' /root/dotfiles"
  Invoke-InWsl "cp '$vaultWsl' /root/dotfiles/.vault_pass && chmod 600 /root/dotfiles/.vault_pass"

  # Ansible preflight: restore ssh/gpg identity from the vault.
  Write-Host '==> Running the ansible keys playbook'
  Invoke-InWsl "$flakes; cd /root/dotfiles && nix develop --command ansible-playbook ansible/playbooks/keys.yml"

  # Build + switch the NixOS config.
  Write-Host "==> nixos-rebuild switch --flake .#$HostAttr"
  Invoke-InWsl "$flakes; cd /root/dotfiles && nixos-rebuild switch --flake .#$HostAttr"

  Write-Host "==> SUCCESS: '$Name' bootstrapped and switched to #$HostAttr" -ForegroundColor Green
  if ($RemoveOnSuccess) {
    Remove-Instance
    Write-Host '    (removed)'
    return
  }
  Write-Host "    Kept for inspection.  Enter it: wsl -d $Name   |   Remove it: wsl --unregister $Name"
  Write-Host '    Now entering the instance as default user (ciznia) and re-running clone + ansible keys playbook to verify the user can bootstrap itself).'
  Invoke-InWsl "$flakes; export GIT_LFS_SKIP_SMUDGE=1; nix shell nixpkgs#git --command git clone -b '$Branch' '$Repo' /home/ciznia/dotfiles" 'ciznia'
  Invoke-InWsl "$flakes; cd /home/ciznia/dotfiles && nix develop --command ansible-playbook ansible/playbooks/keys.yml" 'ciznia'
  Invoke-InWsl 'ssh -T git@github.com' 'ciznia'
}
catch {
  Write-Host "==> FAILED: $($_.Exception.Message)" -ForegroundColor Red
  if ($created) { Remove-Instance }
  exit 1
}
