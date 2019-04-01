Main doc source : https://wiki.archlinux.org/index.php/Remastering_the_Install_ISO
Additionnal :
https://rogalian.blogspot.com/2014/05/groovymame-installation-on-arch-linux.html

Download image:
  - need:
    + image name
    + URL
    + checksum
  - download if not in cache
  - compute checksum

Extract files

Kernel:
  - patch
    + low pixelclock
    + ati and avga
    + realtime kernel ?
  - build
  - make initramfs

Boot:
  - kernel
  - initramfs
  - global configuration of grub

Add/build software:
  - GAsetup
  - groovymame -> https://drive.google.com/open?id=1_h5lcMQ3xMJlKcrh_u1CtCnQhrQgry7W
  - easybashgui
  - zenity/gtkdialog/xdialog
  - xorg drivers
  - sdl2

Rebuild the .iso:
  - rebuild EFI
  - rebuild initramfs
  - whoelse ?

Docker:
- tools:
  - squashfs-tools
  - arch-install-scripts (arch-chroot)
  - mkinitcpio (should already be there)
  - cdrtools (for geniso)
  - dosfstools (for EFI FAT16 .img)
  - asp
  - base-devel
- volumes:
  - cache de l'image
  - logs/
  - work
    + archiso
    + customiso
  - pacman keyring cache to speedup a little
