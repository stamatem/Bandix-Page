#!/bin/busybox sh

TMP_BASE="/tmp/bandixpage"
mkdir -p "$TMP_BASE"

OUT="$TMP_BASE/devices.txt"
TMP="$TMP_BASE/devices.new"

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

if cmp -s "$TMP" "$OUT"; then
    rm -f "$TMP"
else
    mv "$TMP" "$OUT"
    logger "Bandix-Page Host Registry Updated (RAM)"
fi

# ✅ ALWAYS notify APs
for ap in 192.168.2.2 192.168.2.3; do
    wget -qO- http://$ap/cgi-bin/pull-hosts.sh >/dev/null 2>&1 &
done
