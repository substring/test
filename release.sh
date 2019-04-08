#!/bin/bash

source settings

_iso=groovyarcade_${GA_VERSION}.iso
tag=${GA_VERSION}


export GITHUB_USER=substring
export GITHUB_REPO=test

release_name="GroovyArcade $tag"
ghr=`[[ -f ~/go/bin/github-release ]] && echo "~/go/bin/github-release" || echo "/usr/local/bin/github-release"`
ghr_opts="--tag '$tag'"

# Create a release
$ghr release \
    --tag "$tag" \
    --name "groovyarcade $tag" \
    --description "automatic build" \
    --pre-release

cat packages_aur.lst packages_local.lst | grep -v "^#" | while read pkg ; do
  for file in `ls work/output/$pkg*.pkg.tar.xz` ; do
    filename=`basename $file`
    echo "Uploading $filename ..."
    # Upload files
    $ghr upload \
      --tag "$tag" \
      --name "$filename" \
      --file "$file"
  done
done

# Upload the iso
$ghr upload \
    --tag "$tag" \
    --name "${_iso}.xz" \
    --file "work/output/${_iso}.xz"

# Make the release definitive
$ghr edit \
    --tag "$tag" \
    --name "groovyarcade $tag" \
    --description "automatic build"
