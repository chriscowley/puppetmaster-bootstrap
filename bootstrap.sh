#!/bin/sh

if [ -f /etc/centos-release ]
then
  distro="el"
  ver=`awk '{ print $3 }' /etc/centos-release | cut -c1`
else
  echo "do not support this version yet"
  exit 1
fi

if [ -f ./bootstrap.conf ]
then
    echo "conf file exists"
    source ./bootstrap.conf
    if [ -z ${PMB_TEST+x} ]; then
        PMB_TEST=0
    fi
    if [ -z ${PMB_REPO_PREFIX+x} ]; then
        PMB_REPO_PREFIX="http://yum.puppetlabs.com"
    fi
    if [ -z ${PMB_CONFIGURE_GIT+x}]; then
        PMB_CONFIGURE_GIT=1
    fi
    if [ -z ${PMB_CONFIGURE_R10k+x}]; then
        PMB_CONFIGURE_R10k=1
    fi
else
    echo "no conf file"
    PMB_TEST=0
    PMB_REPO_PREFIX="http://yum.puppetlabs.com"
    PMB_CONFIGURE_GIT=1
    PMB_CONFIGURE_R10k=1
    PMB_INSTALL_POSTRECEIVE=1
fi
arch=`uname -i`
puppetrepo_prefix=$PMB_REPO_PREFIX
product_url="${puppetrepo_prefix}/${distro}/${ver}/products/${arch}/"
deps_url="${puppetrepo_prefix}/${distro}/${ver}/dependencies/${arch}/"
gpgkey="${puppetrepo_prefix}/RPM-GPG-KEY-puppetlabs"
repofile="""
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
"""

puppetconf="""
[main]
    logdir = /var/log/puppet
    rundir = /var/run/puppet
    ssldir = $vardir/ssl

[agent]
    classfile = $vardir/classes.txt
    server    = ${HOSTNAME}
    localconfig = $vardir/localconfig

[master]
    pluginsync = true
    environmentpath = $confdir/environments
"""

hierayaml='''
---
:backends:
  - yaml
:logger: console
:hierarchy:
  - "nodes/%\{clientcert}"
  - "%{environment}"
  - common

:yaml:
  :datadir: /etc/puppet/environments/%\{::environment\}/hieradata
'''

r10kyaml='''
:cachedir: "/var/cache/r10k"
:sources:
  :base:
    remote: "/srv/puppet.git"
    basedir: "/etc/puppet/environments"

:purgedirs:
- "/etc/puppet/environments"
'''

postreceive='''
#!/bin/bash

umask 0002

while read oldrev newrev ref
do
    branch=$(echo $ref | cut -d/ -f3)
    echo
    echo "--> Deploying ${branch}..."
    echo
    r10k deploy environment $branch -p
    # sometimes r10k gets permissions wrong too
    find /etc/puppet/environments/$branch/modules -type d -exec chmod 2775 {} \; 2> /dev/null
    find /etc/puppet/environments/$branch/modules -type f -exec chmod 664 {} \; 2> /dev/null
done
'''

function configure_yum {
if [ ${PMB_TEST} -eq 1 ]
then
    echo "Would create the following repo file:"
    cat << EOF
    ${repofile}
EOF
else
    cat > /etc/yum.repos.d/puppet.repo << EOF
    ${repofile}
EOF
fi
}

function pm_install {
    if [ ${PMB_TEST} -eq 1 ]
    then
        echo "yum -y install puppet puppetserver"
    else
        yum -y install puppet puppetserver
    fi
}

function configure_pm {
    if [ ${PMB_TEST} -eq 1 ]
    then
        echo "Create /etc/puppet/puppet.conf with:"
        echo "${puppetconf}"
        echo "Create /etc/hiera/puppet.conf with:"
        echo "${hierayaml}"
        if [ ! -L /etc/hiera.yaml ]; then
            echo "would have created symlink /etc/hiera.yaml -> /etc/puppet/hiera.yaml"
        else
            echo "Symlink for hiera.yaml already exists"
        fi
        echo "create /etc/puppet/environments"
        echo "Start and enable puppetserver"
    else
        echo "${puppetconf}" > /etc/puppet/puppet.conf
        echo "${hierayaml}" > /etc/puppet/hiera.yaml
        if [ ! -L /etc/hiera.yaml ]; then
            ln -sv /etc/puppet/hiera.yaml /etc/hiera.yaml
        fi
        mkdir -pv /etc/puppet/environments
        chgrp -v puppet /etc/puppet/environments
        chmod -v 2775 /etc/puppet/environments
        puppet resource service puppetserver ensure=running enable=true
    fi
}

function install_git {
    if [ ${PMB_TEST} -eq 1 ];then
        echo "install git"
        echo "Create /srv/puppet.git"
        echo "Reset HEAD name"
        if [ ${PMB_INSTALL_POSTRECEIVE} -eq 1 ]; then
            echo "Create post-receive hook containing:"
            echo "${postreceive}"
        fi
    else
        yum -y install git && \
        mkdir -pv /srv/puppet.git && \
        git init --bare --shared=group /srv/puppet.git
        chgrp -Rv puppet /srv/puppet.git && \
        cd /srv/puppet.git && git symbolic-ref HEAD refs/heads/production
        cd -
        if [ ${PMB_INSTALL_POSTRECEIVE} -eq 1 ]; then
          echo "${postreceive}" > /srv/puppet.git/hooks/post-receive
          chmod +x /srv/puppet.git/hooks/post-receive
        fi
    fi
}

function install_r10k {
    if [ ${PMB_TEST} -eq 1 ];then
        echo "Install R10k from Ruby forge"
        if [ ! -f /usr/bin/gem ]; then
            echo "Rubygems not installed"
            echo "yum -y install  rubygems"
        fi
        echo "gem install r10k"
        echo "Create R10k config:"
        echo "${r10kyaml}"
    else
        if [ ! -f /usr/bin/gem ]; then
            echo "Rubygems not installed"
            yum -y install  rubygems
        fi
        gem install r10k
        echo "${r10kyaml}" > /etc/r10k.yaml
    fi
}



configure_yum

if [ -f /etc/yum.repos.d/puppetlabs.repo ]
then
  pm_install
fi

if [ -f /usr/bin/puppetserver ]
then
    # puppetserver installed
    configure_pm
fi

if [ ${PMB_CONFIGURE_GIT} -eq 1 ]; then
    install_git
fi

if [ ${PMB_CONFIGURE_R10k} -eq 1 ]; then
    install_r10k
fi

