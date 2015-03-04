#!/bin/sh

if [ -f /etc/centos-release ]
then
  distro="el"
  ver=`awk '{ print $3 }' /etc/centos-release | cut -c1`
else
  echo "do not support this version yet"
  exit 1
fi
IFS="="
while read -r name value
do
  echo $name is $value
  case $name in
    "repo_prefix" )
      puppetrepo_prefix=${value}
    ;;
  esac
done < bootstrap.conf

arch=`uname -i`
puppetrepo_prefix="http://yum.puppetlabs.com"
product_url="${puppetrepo_prefix}/${distro}/${ver}/products/${arch}/"
deps_url="${puppetrepo_prefix}/${distro}/${ver}/dependencies/${arch}/"
gpgkey="${puppetrepo_prefix}/RPM-GPG-KEY-puppetlabs"

cat > /etc/yum.repos.d/puppet.repo.test << EOF
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

yum -y install puppet puppetserver heira

cat > /etc/puppet/puppet.conf << EOF
[main]
    logdir = /var/log/puppet
    rundir = /var/run/puppet
    ssldir = \$vardir/ssl

[agent]
    classfile = \$vardir/classes.txt
    server    = ${HOSTNAME}
    localconfig = \$vardir/localconfig

[master]
    pluginsync = true
    environmentpath = \$confdir/environments
EOF


cat > /etc/puppet/hiera.yaml << EOF
---
:backends:
  - yaml
:logger: console
:hierarchy:
  - "nodes/%{clientcert}"
  - "%{environment}"
  - common

:yaml:
   :datadir: /etc/puppet/environments/%{::environment}/hieradata
EOF
ln -sv /etc/puppet/hiera.yaml /etc/hiera.yaml

mkdir -pv /etc/puppet/environments
chgrp -v puppet /etc/puppet/environments
chmod -v 2775 /etc/puppet/environments

cat > /etc/r10k.yaml << EOF
# location for cached repos
:cachedir: '/var/cache/r10k'
#
# git repositories containing environments
:sources:
  :base:
    remote: '/srv/puppet.git'
    basedir: '/etc/puppet/environments'

# purge non-existing environments found here
:purgedirs:
- '/etc/puppet/environments'
EOF

gem install r10k
mkdir /var/cache/r10k
chgrp puppet /var/cache/r10k
chmod 2775 /var/cache/r10k

puppet resource service puppetserver ensure=running enable=true
