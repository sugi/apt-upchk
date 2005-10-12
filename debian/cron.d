#
# Regular cron jobs for the apt-upchk package
#
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

7 */6	2-31 * *	aptupchk	test -x /usr/share/apt-upchk/scripts/notify && /usr/share/apt-upchk/scripts/notify
7 1-23/6	1 * *	aptupchk	test -x /usr/share/apt-upchk/scripts/notify && /usr/share/apt-upchk/scripts/notify
7 0	1 * *	aptupchk	test -x /usr/share/apt-upchk/scripts/notify && /usr/share/apt-upchk/scripts/notify -f
