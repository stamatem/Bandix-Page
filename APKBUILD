pkgname=bandix-page
pkgver=1.5.0
pkgrel=0
pkgdesc="Bandix OpenWRT Web UI"
url="https://github.com/stamatem/Bandix-Page"
arch="noarch"
license="MIT"

depends="
grep
sed
"
makedepends=""
subpackages=""

options="!check !tracedeps !strip"

install="bandix-page.post-install bandix-page.post-deinstall"

builddir="$PWD"

export ABUILD_DISABLE_TRACEDepS=1

package() {
    mkdir -p "$pkgdir/www"
    mkdir -p "$pkgdir/www/cgi-bin"
    mkdir -p "$pkgdir/www/data"
    mkdir -p "$pkgdir/usr/bin"

    cp -r ./www/* "$pkgdir/www/"
    cp -r ./usr/bin/* "$pkgdir/usr/bin/"
    cp -r www/data/* "$pkgdir"/www/data/

    chmod +x "$pkgdir/www/cgi-bin/"*
    chmod +x "$pkgdir/usr/bin/"*
    chmod +x "$pkgdir/www/data/"*
}
