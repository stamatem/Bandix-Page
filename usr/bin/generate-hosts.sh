#!/bin/busybox sh

TMP_BASE="/tmp/bandixpage"
mkdir -p "$TMP_BASE"

OUT="$TMP_BASE/devices.txt"
TMP="$TMP_BASE/devices.new"
LOCK="$TMP_BASE/generate-hosts.lock"

if ! mkdir "$LOCK" 2>/dev/null; then
    exit 0
fi

cleanup() {
    rm -rf "$LOCK"
    rm -f "$TMP"
}
trap cleanup EXIT INT TERM

awk '
function flush() {
    if (name && mac && ip && (tag == "bandix" || tag == "permanent")) {
        print name " " mac " " ip
    }
}

/^config host/ {
    flush()
    name=""; mac=""; ip=""; tag=""
    next
}

/option name/ {
    name=$3
    gsub("'"'"'", "", name)
}

/option mac/ {
    mac=$3
    gsub("'"'"'", "", mac)
}

/list mac/ {
    mac=$3
    gsub("'"'"'", "", mac)
}

/option ip/ {
    ip=$3
    gsub("'"'"'", "", ip)
}

/option tag/ {
    tag=$3
    gsub("'"'"'", "", tag)
}

END {
    flush()
}
' /etc/config/dhcp > "$TMP"

CHANGED=0

if cmp -s "$TMP" "$OUT"; then
    rm -f "$TMP"
else
    mv "$TMP" "$OUT"
    CHANGED=1
    logger "Bandix-Page Host Registry Updated (RAM)"
fi

[ "$CHANGED" = "1" ] || exit 0

for ap in 192.168.2.2 192.168.2.3; do
    wget -qO- "http://$ap/cgi-bin/pull-hosts.sh" >/dev/null 2>&1 &
done

exit 0
