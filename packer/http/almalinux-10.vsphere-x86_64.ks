# AlmaLinux 10 Kickstart for vSphere (reference-based)
text
keyboard us
lang en_US.UTF-8
timezone UTC --utc

# Network
network --bootproto=dhcp --device=link --onboot=yes --activate

# Root account: lock password; SSH via injected pubkey (handled in %post)
rootpw --lock

# SELinux enforcing
selinux --enforcing

# Firewall
firewall --disabled

# Bootloader (EFI-safe)
bootloader --timeout=1 --append="nofb quiet"

# Disk
zerombr
ignoredisk --only-use=sda
clearpart --all --initlabel --drives=sda
autopart --type=lvm

# Install source (boot ISO requires network repos)
url --url="https://repo.almalinux.org/almalinux/10/BaseOS/x86_64/os/"
repo --name="AppStream" --baseurl="https://repo.almalinux.org/almalinux/10/AppStream/x86_64/os/"

# Services
services --enabled=NetworkManager,sshd

# Packages
%packages --ignoremissing --excludedocs
@^minimal-environment
@core
open-vm-tools
openssh-server
curl
-net-tools
-NetworkManager-wifi
-NetworkManager-wwan
%end

# Post-install
%post --log=/root/ks-post.log
# Inject SSH public key from kernel cmdline (pubkey_b64=...)
PUBKEY_B64=$(sed -n 's/.*pubkey_b64=\([^ ]*\).*/\1/p' /proc/cmdline)
if [ -n "$PUBKEY_B64" ]; then
	install -d -m 700 /root/.ssh
	umask 077
	echo "$PUBKEY_B64" | base64 -d >> /root/.ssh/authorized_keys || true
fi
systemctl enable vmtoolsd || true
sed -i 's/^#\?UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
restorecon -v /etc/ssh/sshd_config || true
systemctl enable --now sshd

# Cleanup
dnf -y clean all
rm -rf /var/cache/dnf/* /var/log/anaconda/*
%end

reboot
