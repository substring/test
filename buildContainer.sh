#!/bin/bash
_output=/work/output
export CCACHE_DIR=/work/cache/ccache


get_srcinfo_value() {
  grep "^$2" "${_output}/$1/.SRCINFO"
}

clean_previous_versions() {
  pkgname=$1
  arch="x86_64" #let's hardcode this for now
  pkgver=`grep "^pkgver" ${_output}/$package/.SRCINFO} | cut -d '=' -f 2`
}

do_the_job() {
  echo "+-------------------------"
  echo "| Building $package"
  echo "+-------------------------"
  
  package="$1"
  
  if [[ -x /work/package/$package/patch.sh ]] ; then
    /work/package/$package/patch.sh || return 1
  fi
  
  # Handle community/AUR package
  [[ -d "/work/$package/trunk" ]] && cd "/work/$package/trunk" || cd "/work/$package"
  
  PKGDEST=/work/output makepkg --syncdeps --noconfirm --skippgpcheck
  
  # rc=13 if the package was already built -> skip that error
  rc=$?
  if [[ $rc != 0 && $rc != 13 ]] ; then
    echo "rc= $rc"
    return 2
  elif [[ $rc == 13 ]] ; then
    echo "Output package already exists, can recover and keep going..."
  fi
  
  # TODO: if we've exited just above, the following folder would always exist, could cause some confusion
  mkdir -p "/work/output/${package}"
  makepkg --printsrcinfo > "/work/output/${package}/".SRCINFO
  cp PKGBUILD "/work/output/${package}"
  
  # use the SRCINFO to find the current version and purge previous versions of the package
  echo
}

# Need to update, that's arch philosophy. The db from the image build can be outdated
sudo pacman -Sy

# Native arch packages
# Should be more dynamic
#~ for package in linux mame; do
while read package ; do
  echo "$package"
  echo $package | grep -q "^#" && continue
  cd /work
  asp update $package
  asp checkout $package
  do_the_job "$package" || exit 1
done < /work/packages_arch.lst

# AUR packages
while read package ; do
  echo $package | grep -q "^#" && continue
  cd /work
  wget https://aur.archlinux.org/cgit/aur.git/snapshot/${package}.tar.gz
  tar xvzf ${package}.tar.gz
  do_the_job "$package" || exit 1
done < /work/packages_aur.lst

# run tests on output packages
#for pack in `ls /work/output/*.pkg.tar.xz ` ; do
#  namcap -i "$pack"
#done

# Build repo
repo-add ${_output}/groovyarcade.db.tar.gz ${_output}/*.pkg.tar.xz
