#!/bin/busybox sh

TMP_BASE="/tmp/trafficpage"
BUFFER="$TMP_BASE/traffic-buffer.json"
ACCUMULATOR="/www/cgi-bin/traffic-flush-accumulator.sh"
TOTALS_JSON="/www/data/traffic-totals.json"
USERS_FILE="/www/data/users.json"
QUOTA="/usr/bin/traffic-quota"
LOG="$TMP_BASE/traffic-accumulator-process.log"

DEFAULT_INTERVAL_MINUTES="${INTERVAL_MINUTES:-1}"

mkdir -p "$TMP_BASE"

write_interval_log() {
    printf "interval=%ss\n" "$1" > "$LOG"
}

get_interval_seconds() {
    MINUTES="$DEFAULT_INTERVAL_MINUTES"

    if [ -f "$USERS_FILE" ]; then
        CONFIG_MINUTES=$(jq -r '._refresh // empty' "$USERS_FILE" 2>/dev/null)
        [ -n "$CONFIG_MINUTES" ] && MINUTES="$CONFIG_MINUTES"
    fi

    echo "$MINUTES" | grep -Eq '^[0-9]+$' || MINUTES=1
    [ "$MINUTES" -lt 1 ] && MINUTES=1
    [ "$MINUTES" -gt 60 ] && MINUTES=60

    echo $((MINUTES * 60))
}

LAST_INTERVAL_SECONDS=""

while :; do
    INTERVAL_SECONDS=$(get_interval_seconds)

    if [ "$INTERVAL_SECONDS" != "$LAST_INTERVAL_SECONDS" ]; then
        write_interval_log "$INTERVAL_SECONDS"
        LAST_INTERVAL_SECONDS="$INTERVAL_SECONDS"
    fi

    if [ -s "$BUFFER" ]; then
        /bin/busybox sh "$ACCUMULATOR" force < "$BUFFER" >/dev/null 2>&1
        STATUS=$?

        if [ "$STATUS" -eq 0 ] && [ -s "$TOTALS_JSON" ]; then
            if [ -x "$QUOTA" ]; then
                "$QUOTA" >/dev/null 2>&1
            fi
        fi
    fi

    sleep "$INTERVAL_SECONDS"
done
