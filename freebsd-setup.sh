#!/bin/sh -e

HOST_NAME="${HOSTNAME:-marvin.darkcity}"
INTERFACE="${EXT_IF:-vtnet0}"
PACKAGES="${PACKAGES:-ca_root_nss sudo bash python}"
PUBLIC_KEY="${SSH_PUBLIC_KEY_URL:-/https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub}"
USER="${SSH_USER:-vagrant}"

# ZFS filesystems
zfs create -o mountpoint=/home tank/home

# Network configuration
echo 'hostname="${HOSTNAME}"' >> /etc/rc.conf
echo 'ifconfig_'${INTERFACE}'="DHCP -tso"' >> /etc/rc.conf

# Enable services
echo 'sendmail_enable="NONE"' >> /etc/rc.conf
echo 'sshd_enable="YES"' >> /etc/rc.conf
echo 'pf_enable="YES"' >> /etc/rc.conf
echo 'pflog_enable="YES"' >> /etc/rc.conf
echo 'pass all' >> /etc/pf.conf

# Start services
service sshd keygen
service sshd start
service pf start
service pflog start

# Add FreeBSD package repository
mkdir -p /usr/local/etc/pkg/repos
cat << EOT > /usr/local/etc/pkg/repos/FreeBSD.conf
FreeBSD: {
  url: "pkg+http://pkg.eu.FreeBSD.org/\${ABI}/latest",
  enabled: yes
}
EOT
env ASSUME_ALWAYS_YES=true /usr/sbin/pkg bootstrap -f
pkg update

# Install required packages
for package in ${PACKAGES}; do
  pkg install -y ${package}
done

# Activate installed root certifcates
rm /etc/ssl/cert.pem
ln -s /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem

# Create the user
echo "*" | pw useradd -n ${USER} -s /usr/local/bin/bash -m -G wheel -H 0

# Enable sudo for user
mkdir -p /usr/local/etc/sudoers.d
echo "%${USER} ALL=(ALL) NOPASSWD: ALL" >> /usr/local/etc/sudoers.d/${USER}

# Authorize user to login without a key
mkdir /home/${USER}/.ssh
chmod 700 /home/${USER}/.ssh
touch /home/${USER}/.ssh/authorized_keys
chown -R ${USER}:${USER} /home/${USER}

# Get the public key and save it in the `authorized_keys`
fetch -o /home/${USER}/.ssh/authorized_keys ${PUBLIC_KEY}

# Speed up boot process
echo 'autoboot_delay="2"' >> /boot/loader.conf

# Clean up installed packages
pkg clean -a -y

# Empty out tmp directory
rm -rf /tmp/*

# Remove the history
cat /dev/null > /root/.history

# Done
echo "Done. Power off the box and create the snapshot."
