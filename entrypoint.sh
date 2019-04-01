useradd -ms /bin/bash -d /work build
echo 'build ALL=(root) NOPASSWD:ALL' > /etc/sudoers.d/user
chmod 0440 /etc/sudoers.d/user
su - build
