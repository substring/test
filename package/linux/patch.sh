patch -p2 -d /work/linux < /work/package/linux/patch/PKGBUILD.patch
sed -i \
-e '/_srcname=archlinux-linux/a _15kpatchcommitid=393c0bca0ad8b908001027053f623d6bc96a9756' \
-re 's/pkgbase=linux[[:space:]]+/pkgbase=linux-15khz /' \
/work/linux/trunk/PKGBUILD
exit $?
