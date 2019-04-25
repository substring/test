#!/bin/bash
set -e

source settings

_iso=groovyarcade_${GA_VERSION}.iso
_output=work
tag=${GA_VERSION}

release_name="GroovyArcade $tag"
ghr=$([[ -f ~/go/bin/github-release ]] && echo "$HOME/go/bin/github-release" || echo "/usr/local/bin/github-release")

cancel_and_exit() {
  echo "Required cancel of release. Deleting the release" >&2
  $ghr delete --tag "$tag"
  exit 1
}

#
# Build repo
#
echo "Preparing the AUR repo"
repo-add ${_output}/groovyarcade.db.tar.gz ${_output}/*.pkg.tar.xz

echo "Getting ready for release $tag"

# Make sure all env vars exist
export GITHUB_TOKEN=${GITHUB_TOKEN:-$(cat ./GITHUB_TOKEN)}
[[ -z $GITHUB_USER ]] && (echo "GITHUB_USER is undefined, cancelling." ; exit 1 ;)
[[ -z $GITHUB_REPO ]] && (echo "GITHUB_REPO is undefined, cancelling." ; exit 1 ;)
# Allow a local build to release, the CI sets the GITHUB_TOKEN env var
if [[ -z $GITHUB_TOKEN ]] ; then
  echo "GITHUB_TOKEN is undefined, cancelling."
  exit 1
fi

#
# Create a release
#
$ghr release \
    --tag "$tag" \
    --name "$release_name" \
    --description "automatic build" \
    --pre-release

#
# Upload packages
#
while read -r file ; do
  filename=$(basename "$file")
  echo "Uploading $filename ..."
  # Upload files
  $ghr upload \
    --tag "$tag" \
    --name "$filename" \
    --file "$file"
done < work/output/built_packages

#
# Upload the iso
#
[[ ! -f work/output/${_iso}.xz ]] && cancel_and_exit
$ghr upload \
    --tag "$tag" \
    --name "${_iso}.xz" \
    --file "work/output/${_iso}.xz"

#
# Make the release definitive
#
$ghr edit \
    --tag "$tag" \
    --name "groovyarcade $tag" \
    --description "automatic build"
