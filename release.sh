#!/bin/bash

_iso=groovyarcade_${GA_VERSION}.iso
tag=${GA_VERSION}


export GITHUB_USER=substring
export GITHUB_REPO=test

release_name="GroovyArcade $tag"
ghr=`[[ -f ~/go/bin/github-release ]] && echo "~/go/bin/github-release" || echo "/usr/local/bin/github-release"`
ghr_opts="--tag '$tag'"

# Create the repo db
#repo-add groovyarcade.db.tar.gz <PACKAGES>

# Create a release tag and push it
# Comment this for now
# The rev-parse is to be sure we are in a real git repo
#git rev-parse --is-inside-work-tree && git tag "$tag" && git push --tags

ls work/output/

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
    --name "$_iso" \
    --file "$OUTPUT/$_iso"

# Make the release definitive
$ghr edit \
    --tag "$tag" \
    --name "groovyarcade $tag" \
    --description "automatic build"
