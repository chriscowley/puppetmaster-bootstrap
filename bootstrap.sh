#!/bin/sh

if [ -f /etc/centos-release ]
then
  distro="el"
  ver=`awk '{ print $3 }' /etc/centos-release | cut -c1`
else
  echo "do not support this version yet"
  exit 1
fi
arch=`uname -i`
puppetrepo_prefix="http://yum.puppetlabs.com"
product_url="${puppetrepo_prefix}/${distro}/${ver}/products/${arch}/"
deps_url="${puppetrepo_prefix}/${distro}/${ver}/dependencies/${arch}/"
gpgkey="${puppetrepo_prefix}/RPM-GPG-KEY-puppetlabs"

cat > /etc/yum.repos.d/puppet.repo << EOF
[puppet-products]
name = Puppet Labs Products ${distro} ${ver} - ${arch}
baseurl = ${product_url}
gpgkey = ${gpgkey}
enabled = 1
gpgcheck = 1

[puppet-deps]
name = Puppet Labs Dependencies ${distro} ${ver} - ${arch}
baseurl = ${deps_url}
gpgkey = ${gpgkey}
enabled = 1
gpgcheck = 1
EOF

yum -y install puppet puppetserver
