#!/bin/bash
_output=work/output

get_srcinfo_value() {
  # $1: package name
  # $2: required parameter from the .SRCINFO (pkgver, pkgrel etc ...)
  egrep "[[:space:]]+"$2" = " "${_output}/$1/.SRCINFO" | cut -d "=" -f 2 | tr -d " "
}

clean_previous_versions() {
  pkgname=$1
  arch="x86_64" #let's hardcode this for now
  pkgver=`get_srcinfo_value $pkgname pkgver`
  pkgrel=`get_srcinfo_value $pkgname pkgrel`

  # Warning, packages like linux have several output packages
  # + cleaning linux-* removes linux-docs and linux-headers of the current version
  pkgfile="$pkgname-$pkgver-$pkgrel-$arch.pkg.tar.xz"
  find "$_output" -name "$pkgname-*-$arch.pkg.tar.xz" | grep -v "$pkgfile"
}

do_the_job() {
  echo
  echo "+-------------------------"
  echo "| Building $package"
  echo "+-------------------------"
  package="$1"
  [[ -x /work/package/$package/patch.sh ]] && /work/package/$package/patch.sh
  export CCACHE_DIR=/work/cache/ccache
  # Handle community/AUR package
  [[ -d "/work/$package/trunk" ]] && cd "/work/$package/trunk" || cd "/work/$package"
  PKGDEST=/work/output makepkg --syncdeps --noconfirm --skippgpcheck
  mkdir -p "/work/output/${package}"
  makepkg --printsrcinfo > "/work/output/${package}/".SRCINFO
  cp PKGBUILD "/work/output/${package}"
  # use the SRCINFO to find the current version and purge previous versions of the package
}

get_srcinfo_value "linux" "pkgver"
clean_previous_versions linux
