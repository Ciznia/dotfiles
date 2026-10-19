# Screen layouts for the Super+P / Super+Shift+P chords (qtile controls.py).
#   display-profile show        notify the number -> autorandr profile map
#   display-profile load N      apply profile N
#   display-profile save N      save the current layout as profile N
#   display-profile arandr      open arandr (on the NVIDIA GPU when offload exists)
# PROFILES (number order) is set by the nix wrapper.

name() { # profile name for number $1
  local i=$(($1 - 1))
  if [ "$i" -lt "${#PROFILES[@]}" ]; then
    echo "${PROFILES[$i]}"
  else
    echo "profile$1"
  fi
}

hint() {
  notify-send -a display-profile -t 5000 \
    -h string:x-dunst-stack-tag:display-profile "$@"
}

case "${1:-}" in
  show)
    current=$(autorandr --current 2>/dev/null || true)
    lines=""
    for i in "${!PROFILES[@]}"; do
      n=$((i + 1))
      mark=""
      [ "${PROFILES[$i]}" = "$current" ] && mark="  (current)"
      lines+="$n  ${PROFILES[$i]}$mark"$'\n'
    done
    hint "Screens" "${lines}Enter  arandr (Super+P only)"
    ;;
  load)
    p=$(name "$2")
    if autorandr --load "$p"; then
      hint "Screens" "Loaded $p"
    else
      hint -u critical "Screens" "Could not load $p"
    fi
    ;;
  save)
    p=$(name "$2")
    if autorandr --save "$p" --force; then
      hint "Screens" "Saved the current layout as $p"
    else
      hint -u critical "Screens" "Could not save $p"
    fi
    ;;
  arandr)
    # Started from the iGPU, arandr doesn't see the HDMI port (wired to the
    # NVIDIA GPU); offloaded, it does.
    if command -v nvidia-offload >/dev/null; then
      exec nvidia-offload arandr
    fi
    exec arandr
    ;;
  *)
    echo "usage: display-profile show | load N | save N | arandr" >&2
    exit 2
    ;;
esac
