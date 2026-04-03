pkgname=bandix-page
pkgver=1.0.0
pkgrel=0
pkgdesc="Bandix OpenWRT Web UI"
url="https://github.com/yourusername/Bandix-Page"
arch="noarch"
license="MIT"
options="!check"

install="bandix-page.post-install"

builddir="$PWD"

package() {
    mkdir -p "$pkgdir/www"
    mkdir -p "$pkgdir/www/cgi-bin"
    mkdir -p "$pkgdir/www/data"
    mkdir -p "$pkgdir/usr/bin"
    mkdir -p "$pkgdir/etc/init.d"

    cp -r ./www/* "$pkgdir/www/"
    cp -r ./usr/bin/* "$pkgdir/usr/bin/"
    cp -r ./etc/init.d/* "$pkgdir/etc/init.d/"

    chmod +x "$pkgdir/www/cgi-bin/"*
    chmod +x "$pkgdir/usr/bin/"*
    chmod +x "$pkgdir/etc/init.d/"*
}
