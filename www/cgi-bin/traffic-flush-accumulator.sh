#!/bin/busybox sh

FORCE=0
[ "$1" = "force" ] && FORCE=1

TMP_BASE="/tmp/trafficpage"

# uhttpd serves this directory as /data/.
WEB_BASE="/www/data"

mkdir -p "$TMP_BASE" "$WEB_BASE"

BUFFER="$TMP_BASE/traffic-buffer.json"
TMP="$TMP_BASE/traffic-buffer.json.tmp"

WEB_TOTALS_JSON="$WEB_BASE/traffic-totals.json"
WEB_TOTALS_TMP="$TMP_BASE/traffic-totals.json.tmp"

LOCK="$TMP_BASE/traffic.lock"
LAST_WRITE="$TMP_BASE/last_write"

INTERVAL=30
MAX_SIZE=65536

respond() {
    printf "Content-Type: application/json\r\n"
    printf "\r\n"
    printf "%s" "$1"
}

read_post_data() {
    if [ -n "$CONTENT_LENGTH" ]; then
        POST_DATA=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
    elif [ -t 0 ]; then
        POST_DATA=""
    else
        POST_DATA=$(cat)
    fi
}

extract_rows() {
    # Input format:
    # {"ts_ms":...,"devices":[{"mac":"...","total_rx_bytes":...,...}]}
    #
    # Emits:
    # mac<TAB>total_rx<TAB>total_tx<TAB>lan_rx<TAB>lan_tx<TAB>wan_rx<TAB>wan_tx
    awk '
        function find_num(s, key,    p, rest, c, i, ch, out) {
            p = index(s, "\"" key "\"")
            if (!p) {
                return 0
            }

            rest = substr(s, p + length(key) + 2)
            c = index(rest, ":")
            if (!c) {
                return 0
            }

            rest = substr(rest, c + 1)
            out = ""
            for (i = 1; i <= length(rest); i++) {
                ch = substr(rest, i, 1)
                if (ch ~ /[0-9]/) {
                    out = out ch
                } else if (out != "") {
                    break
                }
            }

            if (out == "") {
                return 0
            }
            return out + 0
        }

        function emit(rec,    m, mac, total_rx, total_tx, lan_rx, lan_tx, wan_rx, wan_tx) {
            m = match(rec, /[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]/)
            if (!m) {
                return
            }

            mac = tolower(substr(rec, RSTART, RLENGTH))
            total_rx = find_num(rec, "total_rx_bytes")
            total_tx = find_num(rec, "total_tx_bytes")
            lan_rx = find_num(rec, "lan_rx_bytes")
            lan_tx = find_num(rec, "lan_tx_bytes")
            wan_rx = find_num(rec, "wan_rx_bytes")
            wan_tx = find_num(rec, "wan_tx_bytes")

            printf "%s\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\n", mac, total_rx, total_tx, lan_rx, lan_tx, wan_rx, wan_tx
        }

        {
            json = json $0
        }

        END {
            gsub(/[ \t\r\n]+/, "", json)
            rest = json

            while (match(rest, /\{[^{}]*"mac":"[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]"[^{}]*\}/)) {
                emit(substr(rest, RSTART, RLENGTH))
                rest = substr(rest, RSTART + RLENGTH)
            }
        }
    '
}

extract_saved_rows() {
    # Reads the previous accumulator JSON and emits the internal state rows:
    # mac<TAB>last_total_rx<TAB>last_total_tx<TAB>last_lan_rx<TAB>last_lan_tx<TAB>last_wan_rx<TAB>last_wan_tx<TAB>acc_total_rx<TAB>acc_total_tx<TAB>acc_lan_rx<TAB>acc_lan_tx<TAB>acc_wan_rx<TAB>acc_wan_tx<TAB>updated
    awk '
        function find_num(s, key,    p, rest, c, i, ch, out) {
            p = index(s, "\"" key "\"")
            if (!p) {
                return 0
            }

            rest = substr(s, p + length(key) + 2)
            c = index(rest, ":")
            if (!c) {
                return 0
            }

            rest = substr(rest, c + 1)
            out = ""
            for (i = 1; i <= length(rest); i++) {
                ch = substr(rest, i, 1)
                if (ch ~ /[0-9]/) {
                    out = out ch
                } else if (out != "") {
                    break
                }
            }

            if (out == "") {
                return 0
            }
            return out + 0
        }

        function emit(rec,    m, mac) {
            m = match(rec, /[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]/)
            if (!m) {
                return
            }

            mac = tolower(substr(rec, RSTART, RLENGTH))

            printf "%s\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\n", \
                mac, \
                find_num(rec, "last_total_rx_bytes"), \
                find_num(rec, "last_total_tx_bytes"), \
                find_num(rec, "last_lan_rx_bytes"), \
                find_num(rec, "last_lan_tx_bytes"), \
                find_num(rec, "last_wan_rx_bytes"), \
                find_num(rec, "last_wan_tx_bytes"), \
                find_num(rec, "total_rx_bytes"), \
                find_num(rec, "total_tx_bytes"), \
                find_num(rec, "lan_rx_bytes"), \
                find_num(rec, "lan_tx_bytes"), \
                find_num(rec, "wan_rx_bytes"), \
                find_num(rec, "wan_tx_bytes"), \
                find_num(rec, "updated")
        }

        {
            json = json $0
        }

        END {
            gsub(/[ \t\r\n]+/, "", json)
            rest = json

            while (match(rest, /\{[^{}]*"mac":"[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]"[^{}]*\}/)) {
                emit(substr(rest, RSTART, RLENGTH))
                rest = substr(rest, RSTART + RLENGTH)
            }
        }
    '
}

read_post_data

[ -n "$POST_DATA" ] || {
    respond '{"status":"empty"}'
    exit 0
}

SIZE=$(printf "%s" "$POST_DATA" | wc -c)

[ "$SIZE" -le "$MAX_SIZE" ] || {
    respond '{"status":"too_large"}'
    exit 1
}

printf "%s" "$POST_DATA" | jsonfilter -e '@' >/dev/null 2>&1 || {
    respond '{"status":"invalid_json"}'
    exit 1
}

NOW=$(date +%s)
LAST=$(cat "$LAST_WRITE" 2>/dev/null || echo 0)

echo "$LAST" | grep -Eq '^[0-9]+$' || LAST=0

if [ "$FORCE" != "1" ] && [ $((NOW - LAST)) -lt $INTERVAL ]; then
    respond '{"status":"throttled"}'
    exit 0
fi

if [ -d "$LOCK" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0) ))
    [ "$AGE" -gt 30 ] && rm -rf "$LOCK"
fi

if ! mkdir "$LOCK" 2>/dev/null; then
    respond '{"status":"busy"}'
    exit 0
fi

cleanup() {
    rm -rf "$LOCK"
    rm -f "$TMP" "$WEB_TOTALS_TMP"
}
trap cleanup EXIT INT TERM

printf "%s" "$POST_DATA" > "$TMP" || {
    respond '{"status":"write_failed"}'
    exit 1
}

mv "$TMP" "$BUFFER" || {
    respond '{"status":"move_failed"}'
    exit 1
}

ROWS=$(printf "%s" "$POST_DATA" | extract_rows)

if [ -z "$ROWS" ]; then
    echo "$NOW" > "$LAST_WRITE"
    respond '{"status":"flushed","accumulator":"no_devices"}'
    exit 0
fi

{
    [ -f "$WEB_TOTALS_JSON" ] && extract_saved_rows < "$WEB_TOTALS_JSON"
    printf "%s\n" "$ROWS" | awk -F '\t' '{ print "NEW\t" $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 }'
} | awk -F '\t' -v now="$NOW" '
    function num(v) {
        if (v ~ /^[0-9]+$/) {
            return v + 0
        }
        return 0
    }

    function delta(new_value, old_value,    d) {
        d = new_value - old_value
        if (d < 0) {
            d = new_value
        }
        return d
    }

    function out(v) {
        return sprintf("%.0f", v + 0)
    }

    function print_device(mac,    total_bytes, lan_bytes, wan_bytes, last_total_bytes, last_lan_bytes, last_wan_bytes) {
        total_bytes = (acc_total_rx[mac] + 0) + (acc_total_tx[mac] + 0)
        lan_bytes = (acc_lan_rx[mac] + 0) + (acc_lan_tx[mac] + 0)
        wan_bytes = (acc_wan_rx[mac] + 0) + (acc_wan_tx[mac] + 0)
        last_total_bytes = (last_total_rx[mac] + 0) + (last_total_tx[mac] + 0)
        last_lan_bytes = (last_lan_rx[mac] + 0) + (last_lan_tx[mac] + 0)
        last_wan_bytes = (last_wan_rx[mac] + 0) + (last_wan_tx[mac] + 0)

        if (!first_json) {
            printf ","
        }
        first_json = 0

        printf "\n    {"
        printf "\"mac\":\"%s\",", mac
        printf "\"total_rx_bytes\":%s,", out(acc_total_rx[mac])
        printf "\"total_tx_bytes\":%s,", out(acc_total_tx[mac])
        printf "\"total_bytes\":%s,", out(total_bytes)
        printf "\"lan_rx_bytes\":%s,", out(acc_lan_rx[mac])
        printf "\"lan_tx_bytes\":%s,", out(acc_lan_tx[mac])
        printf "\"lan_bytes\":%s,", out(lan_bytes)
        printf "\"wan_rx_bytes\":%s,", out(acc_wan_rx[mac])
        printf "\"wan_tx_bytes\":%s,", out(acc_wan_tx[mac])
        printf "\"wan_bytes\":%s,", out(wan_bytes)
        printf "\"last_total_rx_bytes\":%s,", out(last_total_rx[mac])
        printf "\"last_total_tx_bytes\":%s,", out(last_total_tx[mac])
        printf "\"last_total_bytes\":%s,", out(last_total_bytes)
        printf "\"last_lan_rx_bytes\":%s,", out(last_lan_rx[mac])
        printf "\"last_lan_tx_bytes\":%s,", out(last_lan_tx[mac])
        printf "\"last_lan_bytes\":%s,", out(last_lan_bytes)
        printf "\"last_wan_rx_bytes\":%s,", out(last_wan_rx[mac])
        printf "\"last_wan_tx_bytes\":%s,", out(last_wan_tx[mac])
        printf "\"last_wan_bytes\":%s,", out(last_wan_bytes)
        printf "\"updated\":%s", out(updated[mac])
        printf "}"
    }

    $1 == "NEW" {
        mac = $2
        new_total_rx[mac] = num($3)
        new_total_tx[mac] = num($4)
        new_lan_rx[mac] = num($5)
        new_lan_tx[mac] = num($6)
        new_wan_rx[mac] = num($7)
        new_wan_tx[mac] = num($8)
        seen_new[mac] = 1
        next
    }

    NF >= 14 {
        mac = $1
        last_total_rx[mac] = num($2)
        last_total_tx[mac] = num($3)
        last_lan_rx[mac] = num($4)
        last_lan_tx[mac] = num($5)
        last_wan_rx[mac] = num($6)
        last_wan_tx[mac] = num($7)
        acc_total_rx[mac] = num($8)
        acc_total_tx[mac] = num($9)
        acc_lan_rx[mac] = num($10)
        acc_lan_tx[mac] = num($11)
        acc_wan_rx[mac] = num($12)
        acc_wan_tx[mac] = num($13)
        updated[mac] = num($14)
        order[++count] = mac
        known[mac] = 1
        next
    }

    END {
        for (mac in seen_new) {
            if (!known[mac]) {
                order[++count] = mac
                known[mac] = 1
            }

            acc_total_rx[mac] += delta(new_total_rx[mac], last_total_rx[mac])
            acc_total_tx[mac] += delta(new_total_tx[mac], last_total_tx[mac])
            acc_lan_rx[mac] += delta(new_lan_rx[mac], last_lan_rx[mac])
            acc_lan_tx[mac] += delta(new_lan_tx[mac], last_lan_tx[mac])
            acc_wan_rx[mac] += delta(new_wan_rx[mac], last_wan_rx[mac])
            acc_wan_tx[mac] += delta(new_wan_tx[mac], last_wan_tx[mac])

            last_total_rx[mac] = new_total_rx[mac]
            last_total_tx[mac] = new_total_tx[mac]
            last_lan_rx[mac] = new_lan_rx[mac]
            last_lan_tx[mac] = new_lan_tx[mac]
            last_wan_rx[mac] = new_wan_rx[mac]
            last_wan_tx[mac] = new_wan_tx[mac]
            updated[mac] = now
        }

        printf "{\n  \"ts_s\": %s,\n  \"devices\": [", now
        first_json = 1

        for (i = 1; i <= count; i++) {
            mac = order[i]
            if (!printed[mac]) {
                printed[mac] = 1
                print_device(mac)
            }
        }

        printf "\n  ]\n}\n"
    }
' > "$WEB_TOTALS_TMP" || {
    respond '{"status":"accumulator_failed"}'
    exit 1
}

mv "$WEB_TOTALS_TMP" "$WEB_TOTALS_JSON" || {
    respond '{"status":"accumulator_move_failed"}'
    exit 1
}

echo "$NOW" > "$LAST_WRITE"

respond '{"status":"flushed","accumulator":"updated"}'
exit 0
