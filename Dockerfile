FROM docker.io/i386/alpine:3.21.0

ENV KERNEL=virt

# Install base system, kernel, and our tools
RUN apk add openrc alpine-base agetty alpine-conf \
    linux-$KERNEL linux-firmware-none \
    vim python3 nodejs git tree nano \
    bash sudo

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
