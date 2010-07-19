#!/bin/sh

# voro env
VOROBASE=/voro/prd1/voro
CONFDIR=${VOROBASE}/wrappers/conf
BINDIR=${VOROBASE}/wrappers/bin
LOGDIR=${VOROBASE}/wrappers/log
CDLDATA=/voro/data/oac-ead
CDLDLXS=/voro/workspace/dlxs/oac-ead
OACDATA=/voro/workspace/dlxs/oac-ead
FINDAID=/findaid
FINDBASE=/findaid/prd1/wrappers
export VOROBASE CONFDIR BINDIR LOGDIR CDLDATA CDLDLXS OACDATA FINDAID FINDBASE

# system env
TIMESTAMP=`date +%y%m%d_%H%M%S`; export TIMESTAMP
PREFIX=/voro/local
PATH=$PREFIX/bin:/usr/bin:/usr/ucb:/usr/bin/X11:/usr/local/bin:/usr/local/bin:/usr/ccs/bin
LD_LIBRARY_PATH=$PREFIX/lib:/usr/local/lib
PERL5LIB=$PREFIX/lib/perl5\:$PREFIX/lib/perl5/site_perl
SSH=/usr/local/bin/ssh
SCP=/usr/local/bin/scp
DATE=`date +%Y%m%d`
export PREFIX PATH LD_LIBRARY_PATH PERL5LIB SSH SCP DATE

# simple checks
if [ `whoami` = voro ]; then
	echo "[INFO] voro setup executed at timestamp: $TIMESTAMP"
else
	echo "[ERROR] Must run as user: voro"
	exit 1
fi

# mail setup
VOROMAIL='Mark.Reyes@ucop.edu'		# default
MAILFILE=$CONFDIR/mail.dat
export VOROMAIL MAILFILE
if [ -f $MAILFILE ]; then
	VOROMAIL=`cat $MAILFILE`
fi
# mail Function
voromail () {
	echo $1 | mailx -s "[ERROR] VORO wrapper" $VOROMAIL
}
