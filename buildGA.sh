#!/bin/bash

# Setup logs
mkdir -p ./logs
[[ -z $LOGFILE ]] && LOGFILE=./logs/"`basename $0 .sh`.log"
#exec &> >(tee -a "$LOGFILE")
exec &> >(tee "$LOGFILE")

# Create the required dirs
[[ -z $WORK ]] && WORK=./work
CACHE="$WORK/cache"
ARCH_ISO_PATH="$WORK/archiso"
GA_ISO_PATH="$WORK/ga_iso" # Created when copying the files from the DVD
SFS_PATH="$WORK/archsquash" # Created by the unsquashfs command below
EFI_PATH="$WORK/efi"
OUTPUT="$WORK/output"
mkdir -p "$WORK" "$CACHE" "$ARCH_ISO_PATH" "$OUTPUT" "$EFI_PATH"


# Get the general settings
source settings
source include.sh

GA_ISO_FILE="$OUTPUT/groovyarcade_${GA_VERSION}.iso"
rm $GA_ISO_FILE

check_downloads() {
  (cd "$CACHE" && sha1sum -c $1)
  return $?
}

# Must be run as root
[ "$EUID" -ne 0 ] && die 1 "This script must be run as root"


#
# Download
#
log "Downloading ARCH LINUX $ARCH_VERSION iso"
# Avoid having spaces in variable values, would crash the for loop
isoname=archlinux-${ARCH_VERSION}-x86_64.iso
bootstrapname=archlinux-bootstrap-${ARCH_VERSION}-x86_64.tar.gz
sha1name=sha1sums.txt
downloads="$sha1name $bootstrapname $isoname"
if [[ ! -e "$CACHE/$isoname" || ! -e "$CACHE/$sha1name" ]] || ! check_downloads $sha1name ; then
  for dl in $downloads ; do
    wget -O "$CACHE/${dl}" "$ARCH_URL/iso/$ARCH_VERSION/${dl}"
  done
fi

check_downloads $sha1name || die 1 "ISO didn't match checksum. Aborting"


#
# Mount the iso
#
log "Mounting the $isoname ARCH DVD and copying its content to $GA_ISO_PATH"
mount -r -t iso9660 -o loop "$CACHE/$isoname" "$ARCH_ISO_PATH"
cp -a "$ARCH_ISO_PATH" "$GA_ISO_PATH"
umount "$ARCH_ISO_PATH"


#
# Get the squashfs
#
log "Unsquashing arch linux"
unsquashfs -d "$SFS_PATH" "$GA_ISO_PATH"/arch/x86_64/airootfs.sfs || die 3 "Couldn't uncompress the squashfs. Aborting"


#
# Prepare the chroot environment
#
log "Preparing chroot environment"
# Share mount point
mkdir -p "$SFS_PATH"/work
mount --bind ./work/output "$SFS_PATH"/work
( cd "$SFS_PATH" &&
mount -t proc /proc proc/ &&
mount --bind --make-slave /sys sys/ &&
mount --bind --make-slave /dev dev/  
)
# backup chroot resolv.conf
mv "$SFS_PATH"/etc/resolv.conf "$SFS_PATH"/etc/resolv.conf.original
cp /etc/resolv.conf "$SFS_PATH"/etc/resolv.conf

#
# Basic setup
#
log "Setting up pacman"
# Now get pacman ready
cat << EOF | chroot "$SFS_PATH"
pacman-key --init
pacman-key --populate archlinux
pacman -Sy
killall gpg-agent
EOF

#
# Patch and build kernel
#


#
# Patch and build MAME, or just download a pre-compiled
#

#
# Install arch packages
#
log "Install Arch linux genuine packages"
packages=`cat packages_native.lst | tr '\n' ' '`
#cat << EOF | chroot "$SFS_PATH"
#for pck in $packages ; do
#pacman -S --noconfirm \$pck
#done
#EOF
cat << EOCHR | chroot "$SFS_PATH"
pacman -S --noconfirm --needed $packages
EOCHR

#
# Install self compiled packages
#
log "Installing custom packages"
cat << EOF | chroot "$SFS_PATH"
pacman -U --noconfirm /work/groovymame-0.208-1-x86_64.pkg.tar.xz
pacman -U --noconfirm /work/attract-2.5.1-1-x86_64.pkg.tar.xz
pacman -U --noconfirm /work/advancemame-3.9-1-x86_64.pkg.tar.xz
EOF

#
# umount bind mountpoints before rebuilding the iso
#
log "Unmount bind mounts"
# those umounts can sometimes be tricky, umount can report that the target is still busy
#grep archsquash /proc/mounts | cut -f2 -d" " | sort -r| sudo xargs umount -fRnv
umount "$SFS_PATH"/proc
umount "$SFS_PATH"/dev
umount "$SFS_PATH"/sys
umount "$SFS_PATH"/work

#
# Rebuild squashfs
#
log "Resquashing arch linux to the GA iso folder"
rm -f "$GA_ISO_PATH"/arch/x86_64/airootfs.sfs
mksquashfs "$SFS_PATH" "$GA_ISO_PATH"/arch/x86_64/airootfs.sfs || die 4 "Failed to rebuild the squashfs. Aborting"
(cd "$GA_ISO_PATH"/arch/x86_64/ && sha512sum airootfs.sfs > airootfs.sha512)

#
# Update volume name everywhere
#
log "Updating volume name in boot config files"
# May as well write it as a find -type f | grep to avoid a static list, depending on arch updates
conf_files="loader/entries/archiso-x86_64.conf arch/boot/syslinux/archiso_sys.cfg arch/boot/syslinux/archiso_pxe.cfg"
arch_volume_name=`isoinfo -d -i "$CACHE/$isoname" | grep "Volume id:" | sed "s/Volume id\: //"`
for file in $conf_files ; do
  sed -i "s/$arch_volume_name/GROOVYARCADE_${GA_VERSION}/g" "$GA_ISO_PATH/$file"
done


#
# Rebuild the EFI img
#
log "Rebuilding efiboot.img with new config files"
mount -t vfat -o loop "$GA_ISO_PATH"/EFI/archiso/efiboot.img "$EFI_PATH"
sed -i "s/$arch_volume_name/GROOVYARCADE_${GA_VERSION}/g" "$EFI_PATH/loader/entries/archiso-x86_64.conf"
umount "$EFI_PATH"


#
# Rebuild ISO
#
log "Building $GA_ISO_FILE"
# the exit 1 is to skip this step rather than multiline comments
# xorriso has better performance + more features
(exit 1 ; cd "$GA_ISO_PATH" && \
genisoimage -l -r -J -V "GROOVYARCADE_${GA_VERSION}" \
  -b isolinux/isolinux.bin \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -c isolinux/boot.cat \
  -o "../../$GA_ISO_FILE" \
  ./
)

xorriso -as mkisofs \
  -iso-level 3 \
  -volid "GROOVYARCADE_${GA_VERSION}" \
  -eltorito-boot isolinux/isolinux.bin \
  -eltorito-catalog isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e EFI/archiso/efiboot.img \
  -no-emul-boot -isohybrid-gpt-basdat \
  -isohybrid-mbr "$GA_ISO_PATH/isolinux/isohdpfx.bin" \
  -output "$GA_ISO_FILE" \
  "$GA_ISO_PATH"
  #-full-iso9660-filenames \

#
# Compress the iso
#
log "xz-ing the iso..."
xz -v -T 0 "$GA_ISO_FILE"

#
# Cleaning
#
log "Cleaning"
mv "$SFS_PATH"/etc/resolv.conf.original "$SFS_PATH"/etc/resolv.conf
rm -rf "$SFS_PATH" "$GA_ISO_PATH" "$EFI_PATH"

#
# Tadaaaaa
#
log "Finished!"
exit 0
