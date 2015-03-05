# puppetmaster-bootstrap

Bootstraps a Puppet master on a basic Centos install

# Usage
The simplest is to run:

```
curl https://raw.githubusercontent.com/chriscowley/puppetmaster-bootstrap/master/bootstrap.sh | sudo sh
```

A master will be installed that along with the utilities that I use (following the generally installed best-practise).

- Puppetserver
- Dynamic environments
- r10k
- git

You can also, from a checkout run `sudo ./bootstrap.sh`.

This allows the use of a certain amount of configuration:

- `PMB_CONFIGURE_GIT` : Whether to install/configure Git (defaults=1)
- `PMB_CONFIGURE_R10k` : Whether to install/configure R10k (defaults=1)
- `PMB_TEST` : Forces will only tell you what it would do, but nothing actually happens
- `PMB_INSTALL_POSTRECEIVE` : Install the post-receive git hook (default=1)
```
