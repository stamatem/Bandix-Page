#!/bin/busybox sh

TMP_BASE="/tmp/trafficpage"
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
    if (name && mac && ip && (tag == "traffic" || tag == "permanent")) {
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

/list tag/ {
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
    logger "Traffic-Page Host Registry Updated (RAM)"
fi

[ "$CHANGED" = "1" ] || exit 0

for ap in 10.99.100.2 10.99.100.3 10.99.100.4 10.99.100.5 10.99.100.6 10.99.100.7 10.99.100.8 10.99.100.9; do
    wget -qO- "http://$ap/cgi-bin/pull-hosts.sh" >/dev/null 2>&1 &
done

exit 0
