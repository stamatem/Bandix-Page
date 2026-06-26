pkgname=traffic-page
pkgver=1.0.1
pkgrel=0
pkgdesc="Bandix OpenWRT Web UI & Quota Management & DHCP Sync"
url="https://github.com/stamatem/Traffic-Page"
arch="noarch"
license="MIT"

depends="
grep
sed
jq
"
makedepends=""
subpackages=""

options="!check !tracedeps !strip"

install="traffic-page.post-install traffic-page.post-deinstall"

builddir="$PWD"

export ABUILD_DISABLE_TRACEDepS=1

package() {
    mkdir -p "$pkgdir/www"
    mkdir -p "$pkgdir/usr/bin"
    mkdir -p "$pkgdir/usr/share"
    mkdir -p "$pkgdir/etc/init.d"

    cp -r ./www/* "$pkgdir/www/"
    cp -r ./usr/bin/* "$pkgdir/usr/bin/"
    cp ./etc/init.d/traffic-accumulator "$pkgdir/etc/init.d/"

    chmod +x "$pkgdir/www/cgi-bin/"*
    chmod +x "$pkgdir/usr/bin/"*
    chmod +x "$pkgdir/etc/init.d/traffic-accumulator"
}
