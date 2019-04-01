#!/bin/bash

export GITHUB_TOKEN=`cat ~/git/GroovyArcade/GAbuild/GITHUB_TOKEN`
export GITHUB_USER=substring
export GITHUB_REPO=test
tag=2019-03
release_name="GroovyArcade $tag"
ghr=~/go/bin/github-release
ghr_opts="--tag '$tag'"

# Create the repo db
#repo-add groovyarcade.db.tar.gz <PACKAGES>

# Create a release tag and push it
# Comment this for now
# The rev-parse is to be sure we are in a real git repo
#git rev-parse --is-inside-work-tree && git tag "$tag" && git push --tags

# Create a release
$ghr release \
    --tag "$tag" \
    --name "groovyarcade $tag" \
    --description "automatic build" \
    --pre-release

cat packages_aur.lst packages_local.lst | while read pkg ; do
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

# Make the release definitive
$ghr edit \
    --tag "$tag" \
    --name "groovyarcade $tag" \
    --description "automatic build"
