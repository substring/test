#!/bin/bash
RELEASE=${RELEASE:-dev}

mkdir -p work/output
mkdir -p work/cache/ccache
chmod -R 777 work
echo "+++++++++++++++++++++++++++++"
echo "+++ Building docker image +++"
echo "+++++++++++++++++++++++++++++"
docker build -f GroovyArcade.dockerfile -t "groovyarcade-${RELEASE}" . &&
echo "+++++++++++++++++++++++++++++"
echo "+++ Running container     +++"
echo "+++++++++++++++++++++++++++++"
docker run --tty --name "groovyarcade-${RELEASE}" --rm -v "$(pwd)/work/output":/work/output -v "$(pwd)/work/cache":/work/cache "groovyarcade-${RELEASE}"
