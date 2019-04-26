FROM archlinux/base:latest

RUN pacman -Sy --noconfirm --needed \
  archiso \
  mkinitcpio \
  cdrtools \
  asp \
  base-devel \
  ccache \
  haveged \
  namcap \
  wget

RUN pacman -Syu --noconfirm

RUN pacman-key --init && \
    pacman-key --populate archlinux

RUN curl -L https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -jx --strip-components 3 -C /usr/local/bin bin/linux/amd64/github-release

RUN useradd -ms /bin/bash -d /work build

# Don't build on a single thread
RUN sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j'$(nproc)'"/' /etc/makepkg.conf

# Activate ccache
RUN sed -ri 's/^BUILDENV=(.*)\!ccache(.*)/BUILDENV=\1ccache\2/' /etc/makepkg.conf

WORKDIR /work

RUN echo 'build ALL=(root) NOPASSWD:ALL' > /etc/sudoers.d/user && \
    chmod 0440 /etc/sudoers.d/user

USER build

RUN mkdir -p /work /work/cache/ccache

COPY package /work/package
COPY buildContainer.sh /work
COPY packages_arch.lst /work
COPY packages_aur.lst /work

CMD /work/buildContainer.sh
