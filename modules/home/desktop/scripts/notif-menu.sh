# Unread notifications (Super+N or the bar counter): pick one to open it or
# mark it read. The list survives logout and reboot (notif-log writes it).
file="${XDG_STATE_HOME:-$HOME/.local/state}/notifications/unread.jsonl"
lock="${file%.jsonl}.lock"

with_lock() { # with_lock <command...>: run it holding the list's lock
  (
    flock 9
    "$@"
  ) 9>"$lock"
}

drop_key() { # rewrite the list without the entry whose key is $1
  local tmp
  tmp=$(mktemp "$file.XXXXXX")
  jq -c --arg k "$1" "select(.key != \$k)" "$file" >"$tmp" && mv "$tmp" "$file"
}

clear_all() { : >"$file"; }

open_entry() { # open_entry <json line>
  local e="$1" id pid url entry app
  id=$(jq -r .id <<<"$e")
  pid=$(jq -r .dunst_pid <<<"$e")

  # Still held by the dunst instance that showed it: show it again, so a click
  # runs the sender's own action (only possible while that app still runs).
  if [ "$(jq -r .boot_id <<<"$e")" = "$(cat /proc/sys/kernel/random/boot_id)" ] &&
    [ -d "/proc/$pid" ] &&
    dunstctl history | jq -e --argjson id "$id" '[.data[0][].id.data] | index($id)' >/dev/null; then
    dunstctl history-pop "$id"
    return
  fi

  # Otherwise: its first link, or the app that sent it.
  url=$(jq -r '.urls[0] // empty' <<<"$e")
  entry=$(jq -r '.desktop_entry' <<<"$e")
  app=$(jq -r '.app' <<<"$e")
  if [ -n "$url" ]; then
    setsid -f xdg-open "$url"
  elif [ -n "$entry" ] && gtk-launch "$entry" 2>/dev/null; then
    :
  elif [ -n "$app" ] && gtk-launch "${app,,}" 2>/dev/null; then
    :
  else
    notify-send -a notif-menu "Nothing to open" "No link or app recorded for: $(jq -r .summary <<<"$e")"
  fi
}

while :; do
  [ -s "$file" ] || {
    rofi -e "No unread notifications"
    exit 0
  }

  # Newest first; one line each.
  mapfile -t entries < <(tac "$file")
  labels=$(printf '%s\n' "${entries[@]}" | jq -r '
    "\(.time | strflocaltime("%d/%m %H:%M"))  \(.app // "?"): \(.summary)\(if .body != "" then " - " + (.body | gsub("\n"; " ")) else "" end)"')
  if [ "${#entries[@]}" -gt 1 ]; then
    labels="Mark all as read"$'\n'"$labels"
  fi

  choice=$(rofi -dmenu -i -no-custom -format i -p "unread (${#entries[@]})" <<<"$labels") || exit 0
  if [ "${#entries[@]}" -gt 1 ]; then
    if [ "$choice" = 0 ]; then
      with_lock clear_all
      exit 0
    fi
    choice=$((choice - 1))
  fi
  e=${entries[$choice]:-}
  [ -n "$e" ] || continue
  key=$(jq -r .key <<<"$e")

  action=$(printf '%s\n' "Open" "Mark as read" "Back" |
    rofi -dmenu -i -no-custom -p "$(jq -r .summary <<<"$e")") || exit 0
  case "$action" in
    "Open")
      with_lock drop_key "$key"
      open_entry "$e"
      exit 0
      ;;
    "Mark as read") with_lock drop_key "$key" ;;
  esac
done
