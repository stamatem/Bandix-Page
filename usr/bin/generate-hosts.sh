#!/bin/sh

OUT="/tmp/devices.txt"
TMP="/tmp/devices.new"

awk '
function flush() {
    if (name && mac && (tag == "bandix" || tag == "permanent")) {
        print name " " mac
    }
}

/^config host/ {
    flush()
    name=""; mac=""; tag=""
    next
}

/option name/ {
    name=$3
    gsub("'"'"'", "", name)
}

/list mac/ {
    mac=$3
    gsub("'"'"'", "", mac)
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
    logger "bandix host registry updated (RAM)"
fi

# ✅ ALWAYS notify APs
for ap in 192.168.2.2 192.168.2.3; do
    wget -qO- http://$ap/cgi-bin/pull-hosts.sh >/dev/null 2>&1 &
done
