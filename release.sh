#!/bin/bash
set -e

source settings

cancel_and_exit() {
  echo "Required cancel of release. Deleting the release" >&2
  delete_release
  exit 1
}


#
# Create a release
#
create_release() {
	echo "Creating release $tag"
$ghr release \
    --tag "$tag" \
    --name "$release_name" \
    --description "automatic build" \
    --pre-release
}

#
# Upload repo + packages + iso
#
upload_assets() {
# Just build the repo only if packages are available
echo "Preparing the AUR repo"
command -v repo-add && ls "${_output}"/*.pkg.tar.xz >/dev/null && repo-add "${_output}"/groovyarcade.db.tar.gz "${_output}"/*.pkg.tar.xz

while read -r file ; do
  filename=$(basename "$file")
  echo "Uploading $filename ..."
  # Upload files
  $ghr upload \
    --tag "$tag" \
    --name "$filename" \
    --file "${_output}/$filename" || cancel_and_exit
done < "${_output}"/built_packages

# Upload the iso
[[ ! -f ${_output}/${_iso}.xz ]] && cancel_and_exit
echo "Uploading ${_iso}.xz..."
$ghr upload \
    --tag "$tag" \
    --name "${_iso}.xz" \
    --file "${_output}/${_iso}.xz" || cancel_and_exit
}


#
# Make the release definitive
#
publish_release() {
	echo "Publihing release $tag"
$ghr edit \
    --tag "$tag" \
    --name "GroovyArcade $tag" \
    --description "automatic build"
}

#
# Remove a release
#
delete_release() {
echo "Deleting release $tag..."
$ghr delete \
    --tag "$tag"
}

_iso=groovyarcade_${GA_VERSION}.iso
if [[ -d /work ]] ; then
  _output=/work/output
elif [[ -d ./work ]] ; then
  _output=./work/output
else
  echo "ERROR: no work dir found"
  exit 1
fi
tag=${GA_VERSION}

release_name="GroovyArcade $tag"
ghr=$([[ -f ~/go/bin/github-release ]] && echo "$HOME/go/bin/github-release" || echo "/usr/local/bin/github-release")

# Make sure all env vars exist
export GITHUB_TOKEN=${GITHUB_TOKEN:-$(cat ./GITHUB_TOKEN)}
[[ -z $GITHUB_USER ]] && (echo "GITHUB_USER is undefined, cancelling." ; exit 1 ;)
[[ -z $GITHUB_REPO ]] && (echo "GITHUB_REPO is undefined, cancelling." ; exit 1 ;)
# Allow a local build to release, the CI sets the GITHUB_TOKEN env var
if [[ -z $GITHUB_TOKEN ]] ; then
  echo "GITHUB_TOKEN is undefined, cancelling."
  exit 1
fi

# Parse command line
while getopts "cupd" option; do
  case "${option}" in
    c)
      create_release
      exit 0
      ;;
    u)
      upload_assets
      exit 0
      ;;
    p)
      publish_release
      exit 0
      ;;
    d)
      delete_release
      exit 0
      ;;
    *)
      echo "ERROR: options can be -c -u -p or -d only" >&2
      exit 1
      ;;
    esac
done

echo "ERROR: no option provided" >&2
exit 1
