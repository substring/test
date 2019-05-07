patch -p2 -d /work/linux < /work/package/linux/patch/PKGBUILD.patch
sed -i \
-e '/_srcname=archlinux-linux/a _15kpatchcommitid=cb50d2cf199e333b83260f1be5608e3ab19c4f29' \
-re 's/pkgbase=linux[[:space:]]+/pkgbase=linux-15khz /' \
/work/linux/trunk/PKGBUILD
exit $?
