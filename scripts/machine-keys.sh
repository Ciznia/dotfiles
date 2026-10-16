#!/usr/bin/env bash
# Gives this machine its own identity: a local ssh key, and a gpg signing
# subkey certified by the master key, which lives only in Vaultwarden (rbw).
# The machine keeps the subkeys, never the master. See docs/NIX.md, Machine keys.
#
#   scripts/machine-keys.sh                # on each machine (safe to re-run)
#   scripts/machine-keys.sh store-master   # only the upload of a full local master
set -euo pipefail

MASTER=A8A7205E2FD4672A77058657654E6EA7882F6671
ITEM="gpg master key" # Vaultwarden item, the armored secret key in its notes
REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
PUBKEY=$REPO/keys/gpg.asc # public key with every machine's subkey
REAL_GNUPGHOME=${GNUPGHOME:-$HOME/.gnupg}
SSH_KEY=$HOME/.ssh/id_ed25519

die() {
  echo "error: $*" >&2
  exit 1
}

# The master's secret part in $GNUPGHOME: full, stub (subkeys only) or none.
primary_secret() {
  local serial
  serial=$(gpg --batch --with-colons --list-secret-keys "$MASTER" 2>/dev/null |
    awk -F: '$1 == "sec" { print "x" $15; exit }') || true
  case $serial in
    "") echo none ;;
    "x#") echo stub ;;
    *) echo full ;;
  esac
}

# Fingerprints of the subkeys whose secret is here and whose capabilities
# match $1 (s: sign, e: encrypt), newest last.
secret_subkeys() {
  gpg --batch --with-colons --list-secret-keys "$MASTER" 2>/dev/null |
    awk -F: -v cap="$1" '
      $1 == "sec" { want = 0 }
      $1 == "ssb" { want = ($12 ~ cap && $15 != "#"); created = $6 }
      $1 == "fpr" && want { print created, $10; want = 0 }
    ' | sort -n | awk '{ print $2 }'
}

# A scratch keyring on tmpfs, wiped on exit.
scratch_gnupghome() {
  tmp=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/machine-keys.XXXXXX")
  trap 'gpgconf --homedir "$tmp" --kill all 2>/dev/null; rm -rf "$tmp"' EXIT
  export GNUPGHOME=$tmp
}

store_master() {
  [ "$(primary_secret)" = full ] || die "no full secret key $MASTER in $REAL_GNUPGHOME"
  if rbw get "$ITEM" >/dev/null 2>&1; then
    die "'$ITEM' already exists in Vaultwarden"
  fi

  local home=$REAL_GNUPGHOME
  scratch_gnupghome
  GNUPGHOME=$home gpg --batch --armor --export-secret-keys "$MASTER" >"$tmp/master.asc"

  # rbw add takes the item from $VISUAL, else $EDITOR: first line the password (left
  # empty), the rest the notes.
  # shellcheck disable=SC2016 # $1 is the file rbw passes to the editor
  printf '#!/bin/sh\n{ echo; cat "%s"; } > "$1"\n' "$tmp/master.asc" >"$tmp/editor"
  chmod +x "$tmp/editor"
  VISUAL=$tmp/editor EDITOR=$tmp/editor rbw add "$ITEM"
  rbw sync

  rbw get --field notes "$ITEM" | gpg --batch --import
  [ "$(primary_secret)" = full ] || die "the copy in Vaultwarden is not the full secret key"
  echo "Stored $MASTER in Vaultwarden as '$ITEM'."
}

setup_ssh() {
  # A link is what the old shared key (sops) left behind.
  if [ -L "$SSH_KEY" ] || [ ! -e "$SSH_KEY" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    rm -f "$SSH_KEY" "$SSH_KEY.pub"
    ssh-keygen -q -t ed25519 -N "" -C "ciznia@$(hostname)" -f "$SSH_KEY"
  fi
}

setup_gpg() {
  if [ "$(primary_secret)" = stub ] && [ -n "$(secret_subkeys s)" ]; then
    sub=$(secret_subkeys s | tail -1)
    return
  fi

  rbw unlocked >/dev/null 2>&1 || rbw unlock
  rbw sync
  if ! rbw get "$ITEM" >/dev/null 2>&1; then
    # First machine: the full master is still in this keyring. A subshell, so
    # its scratch keyring is wiped before ours is made.
    (store_master)
  fi

  local home=$REAL_GNUPGHOME
  scratch_gnupghome
  rbw get --field notes "$ITEM" | gpg --batch --import
  [ ! -f "$PUBKEY" ] || gpg --batch --import "$PUBKEY"
  [ "$(primary_secret)" = full ] || die "'$ITEM' in Vaultwarden is not the full secret key $MASTER"

  gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-add-key "$MASTER" ed25519 sign never
  sub=$(secret_subkeys s | tail -1)

  # The new signing subkey plus the encryption subkey(s), for the password store.
  local keys=("$sub!")
  for enc in $(secret_subkeys e); do keys+=("$enc!"); done
  gpg --batch --pinentry-mode loopback --passphrase '' \
    --armor --export-secret-subkeys "${keys[@]}" >"$tmp/subkeys.asc"
  mkdir -p "$(dirname "$PUBKEY")"
  gpg --batch --armor --export "$MASTER" >"$PUBKEY"

  # The master's secret goes (Vaultwarden has it), the subkeys come back.
  export GNUPGHOME=$home
  if [ "$(primary_secret)" != none ]; then
    gpg --batch --yes --delete-secret-keys "$MASTER"
  fi
  gpg --batch --import "$tmp/subkeys.asc" "$PUBKEY"
  echo "$MASTER:6:" | gpg --batch --import-ownertrust
  [ "$(primary_secret)" = stub ] || die "expected only subkeys of $MASTER in $home"
}

case ${1:-} in
  store-master) store_master ;;
  "")
    # gpg first: it is the part that can fail (Vaultwarden), and the ssh key
    # should only appear together with the subkey.
    setup_gpg
    setup_ssh
    cat <<EOF

ssh public key, for GitHub (Settings > SSH keys):
  $(cat "$SSH_KEY.pub")

gpg signing subkey: $sub (git picks it, no pin needed)
  If keys/gpg.asc changed, commit it and replace the gpg key on GitHub with it.
EOF
    ;;
  *) die "usage: $0 [store-master]" ;;
esac
