#
# Regular cron jobs for the apt-upchk package
#
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

0 */6	* * *	aptupchk	test -x /usr/sbin/apt-upchk-notify && apt-upchk-notify
