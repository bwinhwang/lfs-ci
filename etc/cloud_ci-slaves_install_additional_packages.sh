#!/bin/bash

echo "$(date) user data script start" >> /tmp/userdata.log

/sbin/chkconfig cfexecd off
/sbin/service cfexecd stop

mkdir /root/.ssh
echo 'ssh-dss AAAAB3NzaC1kc3MAAACBAKEYtxoI+RarJtfEUT2pwfpqUHh+0jWtQG6igr4aO7WgxpZKZTW76w8cqa/fEeWFDjoi9v0X2e8kPXzkW/6Eqg/RiwCu/gMt2jXn3LyZ0SiuNhg1//9IxIJcpMY/7yqrHZQ9t+gChzAEezHDjk6DJh6TRrA6jKeiohSiDq/geg/lAAAAFQDEcDXPBFd9AmTWluvswW+/G0O2wwAAAIARmncDRixGyP5EKARctpfPJ7NctsVr1F8G4pJ/0FudY+ZbLyRfcfqCpIaPFzDLaAFAYKTzHue2y6Rmw3Z2HhZvQdjQeliIszJKF3wE1z2F3JSfgkDxwiUXmHdvkD0pSCQnmbV37/aHG1LhMsUrp/eqoLfreex92Tch1hIZ+5M8fQAAAIBjdnbPrDqV1lDMiGA9LJlUGqf7NF5MRgnFzAo8kShjdlAdvicemPmOsxdb1f4ypf0a8yHiXGFPDlzErszkdvRXijG2EUfZ9ZRu/a1ZACn5GqXpbM+9jq5buV6Rjls0aQFtJ27/GbrJQytCV7yvj1SxhZ26GN6XvF32sim2MHt6ng== bm@marvin.minks.de' >> /root/.ssh/authorized_keys

echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDXKLFjR5oM+ucCecLi5Ere84kFgkjbXAK8HjBjol1FLait94OYKHg0x9hOdtowSYmS0KneO7yftfmYH8z4KaoLwIw2ATx5oD0n38BcaHM1BQfZzcv4Cz10GcNm8nUaoKhnffgG+tSqQUglPlui0U384gRoIjQM/io55TYqwbtFgt5EtgCzjnY5tAQKfMuVzOy0bCSlF9RKhoU8zCM/j8Ghl1vKx64IePKVS/zkv1AxjWqNWYSzaVtJ59ccG/ZmAth3AZ+9zQtubTAt5D9M159ZdnlUxjZIcVhZk8UVmnJN//1WbJWKEqZgY+w5O3aiNR9iM11v9NgdiA33r0fLYCAH eambrosc@erwinqa' >> /root/.ssh/authorized_keys

chmod 1777 /opt
rm -f /var/fpwork
ln -s /opt /var/fpwork

mkdir /build ;    mount ullinn12.emea.nsn-net.net:/vol/ullinn12_bin/build /build
mkdir /ps ;       mount ullinn11.emea.nsn-net.net:/vol/ullinn11_ps /ps
mkdir /tftpboot ; mount hopp.emea.nsn-net.net:/tftpboot /tftpboot
mkdir /nobackup ; mount ullinn11.emea.nsn-net.net:/vol/ullinn11_bin3/nobackup /nobackup
mkdir /nobackup_with_snapshots
mkdir /admulm

sed -i "s;ullinn10.emea.nsn-net.net:/vol/ullinn10_bin/build;ullinn12.emea.nsn-net.net:/vol/ullinn12_bin/build;" /etc/fstab
grep tftpboot /etc/file || \
	echo "hopp.emea.nsn-net.net:/tftpboot /tftpboot nfs soft,intr,retry=1,rw,rsize=32768,wsize=32768  0 0" >> /etc/fstab 
grep pslfs /etc/file || \
	echo "eslinn11.emea.nsn-net.net:/vol/eslinn11_pslfs                       /build/home/SC_LFS nfs  soft,intr,retry=1,rw,rsize=32768,wsize=32768  0 0" >> /etc/fstab
	echo "ullinn11.emea.nsn-net.net:/vol/ullinn11_bin3/nobackup               /nobackup nfs  soft,intr,retry=1,rw,rsize=32768,wsize=32768  0 0" >> /etc/fstab
	echo "ullinn11.emea.nsn-net.net:/vol/ullinn11_snap                        /nobackup_with_snapshots nfs  soft,intr,retry=1,rw,rsize=32768,wsize=32768  0 0" >> /etc/fstab
	echo "ullinn10.emea.nsn-net.net:/vol/ullinn10_grp/ee_groups_lin/admulm    /admulm nfs  soft,intr,retry=1,rw,rsize=32768,wsize=32768  0 0" >> /etc/fstab

yum -y install perl-parent doxygen texlive-latex xz-devel.i686 perl-File-Slurp-9999.13-7.el6.noarch perl-DBD-MySQL.x86_64 perl-XML-Simple.noarch ctags.x86_64 perl-XML-XPath.noarch symlinks s3cmd.noarch libstdc++-4.4.6-4.el6.i686
# for git
yum -y install curl-devel openssl-devel.x86_64 expat-devel.x86_64
yum -y install LINSEE_Core-0.9.5-2.noarch LINSEE_euca2ools_v302-3.0.2-2.x86_64 LINSEE_euca2ools_v311-3.1.1-1.x86_64 LINSEE_python_v273-2.7.3-4.x86_64 LINSEE_subversion_v189-1.8.9-1.x86_64
yum -y install gcc-c++-4.4.6-4.el6.x86_64 patchutils-0.3.1-3.1.el6.x86_64

mount -a



export http_proxy=http://10.144.1.11:8080
export https_proxy=https://10.144.1.11:8080
export no_proxy='localhost,127.0.0.1,.nsn-net.net,.inside.nokiasiemensnetworks.com'

cd /tmp
wget --no-check-certificate https://github.com/git/git/archive/v1.7.12.2.tar.gz -O v1.7.12.2.tar.gz
tar xfvz v1.7.12.2.tar.gz
cd git-1.7.12.2
make HOME=/usr/local >> /tmp/userdata.log 2>&1
make install HOME=/usr/local >> /tmp/userdata.log 2>&1

sed -i -e s/10.171.0.1/10.171.0.2/g /etc/resolv.conf
echo "$(date) resolv.conf" >> /tmp/userdata.log
cat /etc/resolv.conf >> /tmp/userdata.log

echo "$(date) user data script done" >> /tmp/userdata.log
chmod 777 /tmp/userdata.log


