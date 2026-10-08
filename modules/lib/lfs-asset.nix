# Copy a Git-LFS tracked asset into the store, failing the build if it's still
# a pointer file. In a clone without git-lfs the assets are ~130-byte pointers
# and Nix copies the checkout as-is — feh then can't load the wallpaper, X's
# root window is never painted and the session looks frozen.
pkgs: src:
pkgs.runCommandLocal (baseNameOf src) {} ''
  if head -c 64 ${src} | grep -aq '^version https://git-lfs'; then
    echo "error: ${baseNameOf src} is a Git LFS pointer, not the real file." >&2
    echo "Fetch it with 'git lfs install --local && git lfs pull' in the repo, then rebuild." >&2
    exit 1
  fi
  cp ${src} $out
''
