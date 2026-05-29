FROM docker.io/i386/alpine:3.21.0

ENV KERNEL=virt

# Install base system, kernel, and our tools
RUN apk add openrc alpine-base agetty alpine-conf \
    linux-$KERNEL linux-firmware-none \
    bash sudo cpio nano tree

# Register bash as a valid login shell
RUN grep -q /bin/bash /etc/shells || echo /bin/bash >> /etc/shells

# Create guest user, set shell to bash
RUN deluser guest 2>/dev/null || true
RUN adduser -D -s /bin/bash guest
RUN echo 'ttyS0::respawn:/sbin/agetty --autologin guest -s ttyS0 115200 vt100' >> /etc/inittab

RUN echo "guest:" | chpasswd
RUN echo 'guest ALL=(root) NOPASSWD: /sbin/poweroff' > /etc/sudoers.d/guest
RUN setup-hostname cli

# Init services
RUN for i in devfs dmesg mdev hwdrivers; do rc-update add $i sysinit; done
RUN for i in hwclock modules sysctl hostname syslog bootmisc; do rc-update add $i boot; done
RUN rc-update add killprocs shutdown

# Copy shared assets
COPY ascii-loading.txt /etc/motd
COPY shell-config/bashrc /home/guest/.bashrc
COPY shell-config/profile /home/guest/.profile
COPY shell-config/exit-script /usr/local/bin/exit

RUN chmod +x /usr/local/bin/exit

# Copy site content
COPY content/ /home/guest/

# Ensure guest owns everything in their home
RUN chown -R guest:guest /home/guest

# --- Build squashfs rootfs and small initramfs ---

RUN apk add --no-cache squashfs-tools

# Create squashfs from rootfs (exclude virtual filesystems)
RUN mksquashfs / /tmp/rootfs.squashfs -comp gzip -no-progress \
    -e /sys /proc /dev /run /tmp /tmp/rootfs.squashfs

# Create small initramfs with kernel modules and custom init
COPY initramfs-init /tmp/initramfs-init
RUN KVER=$(ls /lib/modules/) && \
    mkdir -p /tmp/initrd/bin /tmp/initrd/lib /tmp/initrd/dev /tmp/initrd/proc /tmp/initrd/sys && \
    cp /lib/ld-musl-i386.so.1 /tmp/initrd/lib/ && \
    mkdir -p /tmp/initrd/lib/modules/$KVER && \
    mkdir -p /tmp/initrd/mnt/rootfs && \
    mkdir -p /tmp/initrd/mnt/overlay/upper /tmp/initrd/mnt/overlay/work /tmp/initrd/mnt/merged && \
    cp /bin/busybox /tmp/initrd/bin/busybox && \
    cd /tmp/initrd/bin && \
    for cmd in sh mount umount insmod switch_root mkdir sleep mknod ls; do ln -s busybox $cmd; done && \
    cp /lib/modules/$KVER/kernel/drivers/scsi/sd_mod.ko.gz /tmp/initrd/lib/modules/$KVER/ && \
    cp /lib/modules/$KVER/kernel/fs/squashfs/squashfs.ko.gz /tmp/initrd/lib/modules/$KVER/ && \
    cp /lib/modules/$KVER/kernel/fs/overlayfs/overlay.ko.gz /tmp/initrd/lib/modules/$KVER/ && \
    gunzip /tmp/initrd/lib/modules/$KVER/*.gz && \
    cp /tmp/initramfs-init /tmp/initrd/init && chmod +x /tmp/initrd/init && \
    cd /tmp/initrd && find . -print0 | cpio -o -0 -H newc --quiet | gzip -9 > /tmp/initramfs.cpio.gz

# Stage outputs
RUN mkdir -p /output && \
    cp /boot/vmlinuz-virt /output/vmlinuz && \
    cp /tmp/initramfs.cpio.gz /output/initrd.img && \
    cp /tmp/rootfs.squashfs /output/disk.img
