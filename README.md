Debian package update checker
=============================

Package to check updates and report by mail.
This script will be run under non-root user.

Pre-build package
-----------------

Add this line to your apt.

```
deb http://arege.jp/debian-arege stable apt-upchk
```

```sh
$ sudo apt-get update
$ sudo apt-get install apt-upchk
```

Currently the apt line is not singed.
Please allow to install un-signed package for apt-upchk, intentinally.

How to build by yourself
------------------------

```sh
$ gbp buildpackage --git-pbuilder --git-arch=amd64 --git-dist=jessie
```
