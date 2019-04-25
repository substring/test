#!/bin/bash
_output=/work/output
export CCACHE_DIR=/work/cache/ccache
built_packages="$_output/built_packages"

do_the_job() {
  echo "+-------------------------"
  echo "| Building $package"
  echo "+-------------------------"
  
  package="$1"
  
  if [[ -x /work/package/$package/patch.sh ]] ; then
    /work/package/"$package"/patch.sh || return 1
  fi
  
  # Handle community/AUR package
  cd "/work/$package/trunk" || cd "/work/$package" || { echo "Couldn't cd to the package dir" ; exit 1 ; }
  
  # The CI can set MAKEPKG_OPTS to "--nobuild --nodeps" for a simple basic check for every branch not tag nor master)
  # So if empty, set some default value
  export MAKEPKG_OPTS=${MAKEPKG_OPTS:-"--syncdeps"}
  # shellcheck disable=SC2086
  PKGDEST="$_output" makepkg --noconfirm --skippgpcheck $MAKEPKG_OPTS
  
  # rc=13 if the package was already built -> skip that error
  # This only happens in a local build
  rc=$?
  if [[ $rc != 0 && $rc != 13 ]] ; then
    echo "rc= $rc"
    return 2
  elif [[ $rc == 13 ]] ; then
    echo "Output package already exists, can recover and keep going..."
  fi
  
  # TODO: if we've exited just above, the following folder would always exist, could cause some confusion
  mkdir -p "${_output}/${package}"
  makepkg --printsrcinfo > "${_output}/${package}/".SRCINFO
  cp PKGBUILD "${_output}/${package}"
  makepkg --packagelist >> "$built_packages"
  
  # use the SRCINFO to find the current version and purge previous versions of the package
  echo
}

# Need to update, that's arch philosophy. The db from the image build can be outdated
sudo pacman -Sy

rm "$built_packages" 2>/dev/null

# Native arch packages
while read -r package ; do
  echo "$package" | grep -q "^#" && continue
  cd /work || { echo "Couldn't cd to the work dir" ; exit 1 ; } 
  asp update "$package"
  asp checkout "$package"
  do_the_job "$package" || exit 1
done < /work/packages_arch.lst

# AUR packages
while read -r package ; do
  echo "$package" | grep -q "^#" && continue
  cd /work || { echo "Couldn't cd to work dir" ; exit 1 ; } 
  wget https://aur.archlinux.org/cgit/aur.git/snapshot/"${package}".tar.gz
  tar xvzf "${package}".tar.gz
  do_the_job "$package" || exit 1
done < /work/packages_aur.lst

# run tests on output packages
#for pack in `ls /work/output/*.pkg.tar.xz ` ; do
#  namcap -i "$pack"
#done
