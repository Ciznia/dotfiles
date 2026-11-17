# dunst runs this for every notification (the `log` rule in notifications.nix),
# with the details in DUNST_* variables. Appends one JSON line to the unread
# list, which notif-menu and the qtile bar read.
case "${DUNST_APP_NAME:-}" in
  display-profile | notif-menu) exit 0 ;; # our own hints, not worth keeping
esac

dir="${XDG_STATE_HOME:-$HOME/.local/state}/notifications"
mkdir -p "$dir"

# dunst numbers notifications from 1 again after a restart, so an id is only
# meaningful together with the dunst instance (boot + pid) that issued it.
boot_id=$(cat /proc/sys/kernel/random/boot_id)

entry=$(jq -cn \
  --arg key "$boot_id:$PPID:${DUNST_ID:-0}" \
  --arg boot_id "$boot_id" \
  --argjson dunst_pid "$PPID" \
  --argjson id "${DUNST_ID:-0}" \
  --argjson time "$(date +%s)" \
  --arg app "${DUNST_APP_NAME:-}" \
  --arg summary "${DUNST_SUMMARY:-}" \
  --arg body "${DUNST_BODY:-}" \
  --arg urgency "${DUNST_URGENCY:-}" \
  --arg desktop_entry "${DUNST_DESKTOP_ENTRY:-}" \
  --arg urls "${DUNST_URLS:-}" \
  '{key: $key, boot_id: $boot_id, dunst_pid: $dunst_pid, id: $id, time: $time,
    app: $app, summary: $summary, body: $body, urgency: $urgency,
    desktop_entry: $desktop_entry, urls: ($urls | split("\n") | map(select(. != "")))}')

(
  flock 9
  printf '%s\n' "$entry" >>"$dir/unread.jsonl"
) 9>"$dir/unread.lock"
