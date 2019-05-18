#!/bin/bash

umount_and_die() {
  for dir in proc dev sys work overlay ; do
    umount "$SFS_PATH"/$dir
  done
  die "$1" "$2"
}

#
# Must be run as root
#
[ "$EUID" -ne 0 ] && die 1 "This script must be run as root"


#
# Setup logs
#
mkdir -p ./logs
[[ -z $LOGFILE ]] && LOGFILE=./logs/"$(basename "$0" .sh)".log
#exec &> >(tee -a "$LOGFILE")
exec &> >(tee "$LOGFILE")


#
# Create the required dirs
#
[[ -z $WORK ]] && WORK=./work
CACHE="$WORK/cache"
ARCH_ISO_PATH="$WORK/archiso"
GA_ISO_PATH="$WORK/ga_iso" # Created when copying the files from the DVD
SFS_PATH="$WORK/archsquash" # Created by the unsquashfs command below
EFI_PATH="$WORK/efi"        # Holds EFI data for the DVD
OUTPUT="$WORK/output"       # GA packages
GA_OVERLAY="$WORK/overlay/groovyarcade"
ISO_OVERLAY="$WORK/overlay/iso"

mkdir -p "$WORK" "$CACHE" "$ARCH_ISO_PATH" "$OUTPUT" "$EFI_PATH"


#
# Get the general settings
#
source settings
source include.sh


GA_ISO_FILE="$OUTPUT/groovyarcade_${GA_VERSION}.iso"
[[ -z $REPACK_GA ]] && rm "$GA_ISO_FILE"


check_downloads() {
  (cd "$CACHE" && sha1sum -c "$1")
  return $?
}

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
    curl -sLo "$CACHE/${dl}" "$ARCH_URL/iso/$ARCH_VERSION/${dl}"
  done
fi

check_downloads $sha1name || die 1 "ISO didn't match checksum. Aborting"

# If REPACK_GA is set, don't fool around with arch iso, but just the groovy arcade iso
[[ -n $REPACK_GA ]] && isoname=."./output/groovyarcade_${GA_VERSION}.iso"
[[ -n $REPACK_GA ]] && [[ ! -f $CACHE/$isoname ]] && exit 1

#
# Mount the iso
#
log "Extracting $isoname ARCH DVD to $GA_ISO_PATH"
xorriso -osirrox on -indev "$CACHE/$isoname" -extract / "$GA_ISO_PATH"


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
mkdir -p "$SFS_PATH"/work "$SFS_PATH"/overlay
mount --bind "$_OUTPUT" "$SFS_PATH"/work
( cd "$SFS_PATH" &&
mount -t proc /proc proc/ &&
mount --bind --make-slave /sys sys/ &&
mount --bind --make-slave /dev dev/  
) || umount_and_die 4 "Failed bind mounting. Are there any mounts remaining from a previous execution of $0 ?"
# backup chroot resolv.conf
mv "$SFS_PATH"/etc/resolv.conf "$SFS_PATH"/etc/resolv.conf.original
cp /etc/resolv.conf "$SFS_PATH"/etc/resolv.conf

#
# Basic setup
#
log "Setting up pacman"
# Now get pacman ready
[[ -z $SKIP_PACKAGES ]] && cat << EOF | chroot "$SFS_PATH"
pacman-key --init
pacman-key --populate archlinux
killall gpg-agent
pacman -Sy --noconfirm reflector
reflector --verbose --latest 50 --sort rate --save /etc/pacman.d/mirrorlist 
pacman -Syu --noconfirm --ignore linux
EOF
# shellcheck disable=SC2181
[[ -z $SKIP_PACKAGES && $? != 0 ]] && umount_and_die 1 "ERROR: couldn't update the OS"


#
# Install self compiled packages
#
#First build the package list
packages_list=$(built_packages_list)
pacman_packages_list=
while read -r package ; do
  pacman_packages_list="$pacman_packages_list /work/$(basename "$package")"
done < "$packages_list"
log "Installing custom packages $pacman_packages_list"
[[ -z $SKIP_PACKAGES ]] && cat << EOCHR | chroot "$SFS_PATH"
pacman -U --needed --noconfirm $pacman_packages_list
#cp $pacman_packages_list /var/cache/pacman/pkg/
EOCHR
# shellcheck disable=SC2181
[[ -z $SKIP_PACKAGES && $? != 0 ]] && umount_and_die 9 "ERROR: couldn't install specific packages"


#
# Install arch packages
#
log "Installing Arch linux genuine packages"
packages=$(grep -v '^#' packages_native.lst | tr '\n' ' ')
#cat << EOF | chroot "$SFS_PATH"
#for pck in $packages ; do
#pacman -S --noconfirm \$pck
#done
#EOF
[[ -z $SKIP_PACKAGES ]] && cat << EOCHR | chroot "$SFS_PATH"
pacman -S --noconfirm --needed $packages
EOCHR


#
# Add arcade user
#
cat << EOCHR | chroot "$SFS_PATH"
groupadd --gid 1000 arcade
useradd --uid 1000 --gid 1000 --create-home --home-dir /home/arcade --shell /bin/bash --groups adm,audio,disk,games,log,network,nobody,optical,power,storage,tty,users,video,wheel arcade
echo -e "arcade\narcade" | passwd arcade
sed -i "/^# .*wheel.*NOPASSWD.*/s/^# //" /etc/sudoers
EOCHR


#
# Apply the overlay
#
log "Applying the groovy arcade overlay + set expected permissions"
# Change owner + rights on the mounted overlay fs
cp -R overlay "$WORK"
mount --bind "$GA_OVERLAY" "$SFS_PATH"/overlay
# chown root:root
cat << EOCHR | chroot "$SFS_PATH"
cp -R --no-preserve=ownership /overlay/* /
chown -R 1000:1000 /home/arcade
EOCHR


#
# Update volume name everywhere
#
log "Updating volume name in boot config files + setup kernel"
#cp "$SFS_PATH"/boot/vmlinuz-linux-15khz "$GA_ISO_PATH"/arch/boot/x86_64/
# May as well write it as a find -type f | grep to avoid a static list, depending on arch updates
conf_files="loader/entries/archiso-x86_64.conf arch/boot/syslinux/archiso_sys.cfg arch/boot/syslinux/archiso_pxe.cfg"
arch_volume_name=$(isoinfo -d -i "$CACHE/$isoname" | grep "Volume id:" | sed "s/Volume id\: //")
for file in $conf_files ; do
  sed -i \
-e "s/$arch_volume_name/GROOVYARCADE_${GA_VERSION}/g" \
"$GA_ISO_PATH/$file"
#-e "s/vmlinuz/vmlinuz-linux-15khz/g" \

done

# mkinitcpio ignores -c if the perset sets the .conf file
# So we have fun swapping files
cat << EOCHR | chroot "$SFS_PATH"
cp /etc/mkinitcpio.conf /etc/mkinitcpio-groovyarcade.conf
cp /etc/mkinitcpio-dvd.conf /etc/mkinitcpio.conf
mkinitcpio -p linux-15khz
cp /etc/mkinitcpio-groovyarcade.conf /etc/mkinitcpio.conf
EOCHR

cp "$SFS_PATH"/boot/vmlinuz-linux-15khz "$GA_ISO_PATH"/arch/boot/x86_64/vmlinuz
cp "$SFS_PATH"/boot/initramfs-linux-15khz.img "$GA_ISO_PATH"/arch/boot/x86_64/archiso.img
rm "$SFS_PATH"/boot/initramfs-linux-15khz-fallback.img
# gasetup expects a vmlinuz
cp "$SFS_PATH"/boot/vmlinuz-linux-15khz "$SFS_PATH"/boot/vmlinuz-linux
cp "$SFS_PATH"/boot/initramfs-linux-15khz.img "$GA_ISO_PATH"/arch/boot/x86_64/archiso.img


#
# Final touch
#
cat << EOCHR | chroot "$SFS_PATH"
systemctl enable smb
systemctl enable nmb
systemctl enable sshd
rm -rf /var/cache/pacman/pkg/*
cat << EOF >> /etc/pacman.conf

[groovyarcade]
SigLevel = PackageOptional
Server = $PACMAN_REPO
EOF
EOCHR


#
# List embedded packages
#
cat << EOCHR > "$GA_ISO_PATH"/pkglist.txt | chroot "$SFS_PATH"
pacman -Qe
EOCHR


#
# umount bind mountpoints before rebuilding the iso
#
log "Unmounting bind mounts"
# those umounts can sometimes be tricky, umount can report that the target is still busy
#grep archsquash /proc/mounts | cut -f2 -d" " | sort -r| sudo xargs umount -fRnv
umount "$SFS_PATH"/proc
umount "$SFS_PATH"/dev
umount "$SFS_PATH"/sys
umount "$SFS_PATH"/work
umount "$SFS_PATH"/overlay


#
# Rebuild squashfs
#
log "Resquashing arch linux to the GA iso folder"
rm -f "$GA_ISO_PATH"/arch/x86_64/airootfs.sfs
mksquashfs "$SFS_PATH" "$GA_ISO_PATH"/arch/x86_64/airootfs.sfs || die 4 "Failed to rebuild the squashfs. Aborting"


#
# Compute the squashfs checksum
#
log "Computing sha512"
(cd "$GA_ISO_PATH"/arch/x86_64/ && sha512sum airootfs.sfs > airootfs.sha512)


#
# Rebuild the EFI img
#
log "Rebuilding efiboot.img with new config files - uncomplete (missing kernel and initramfs)"
mount -t vfat -o loop "$GA_ISO_PATH"/EFI/archiso/efiboot.img "$EFI_PATH"
sed -i "s/$arch_volume_name/GROOVYARCADE_${GA_VERSION}/g" "$EFI_PATH/loader/entries/archiso-x86_64.conf"
umount "$EFI_PATH"


#
# Copy the DVD overlay
#
log "Copying the iso overlay"
ls "$ISO_OVERLAY"
cp -R "$ISO_OVERLAY/"* "$GA_ISO_PATH"


#
# Final touch to the DVD
#
log "Last DVD customizations"
# Point ot the right cfg file (the GA one, not default arch one)
#sed -i "s+archiso\.cfg+isolinux\.cfg+" "$GA_ISO_PATH/isolinux/isolinux.cfg" # Not needed anymore, file gotten from overlay
sed -i "s+archisolabel=GROOVY+archisolabel=GROOVYARCADE_${GA_VERSION}+g" "$GA_ISO_PATH/arch/boot/syslinux/syslinux.cfg"


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

# Volume ID is limited to 32 chars
volume_id="GROOVYARCADE_${GA_VERSION:0:19}"
xorriso -as mkisofs \
  -iso-level 3 \
  -volid "$volume_id" \
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
[[ -z $SKIP_XZ ]] && xz -v9T0 "$GA_ISO_FILE"


#
# Cleaning
#
log "Cleaning"
mv "$SFS_PATH"/etc/resolv.conf.original "$SFS_PATH"/etc/resolv.conf
rm -rf "$ARCH_ISO_PATH" "$SFS_PATH" "$GA_ISO_PATH" "$EFI_PATH" "$WORK/overlay"


#
# Ugly step : release the iso from here
#
log "Release the ISO to github"
./release.sh -i


#
# Tadaaaaa
#
log "Finished!"
exit 0
