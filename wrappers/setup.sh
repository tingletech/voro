#!/bin/sh

# voro env
VOROBASE=$HOME/branches/production/voro
CONFDIR=${VOROBASE}/wrappers/conf
BINDIR=${VOROBASE}/wrappers/bin
LOGDIR=$HOME/log/wrappers/log
CDLDATA=$HOME/data/in/oac-ead
CDLDLXS=$HOME/workspace/dlxs/oac-ead
OACDATA=$HOME/workspace/dlxs/oac-ead

export VOROBASE CONFDIR BINDIR LOGDIR CDLDATA CDLDLXS OACDATA FINDAID FINDBASE

# system env
TIMESTAMP=`date +%y%m%d_%H%M%S`; export TIMESTAMP
PREFIX=$HOME/local
PATH=$PREFIX/bin:/usr/bin:/usr/ucb:/usr/bin/X11:/usr/local/bin:/usr/local/bin:/usr/ccs/bin
LD_LIBRARY_PATH=$PREFIX/lib:/usr/local/lib
PERL5LIB=$PREFIX/lib/perl5\:$PREFIX/lib/perl5/site_perl
SSH=/usr/local/bin/ssh
SCP=/usr/local/bin/scp
DATE=`date +%Y%m%d`
export PREFIX PATH LD_LIBRARY_PATH PERL5LIB SSH SCP DATE

# simple checks
if [ `whoami` = dsc ]; then
	echo "[INFO] voro setup executed at timestamp: $TIMESTAMP"
else
	echo "[ERROR] Must run as user: dsc"
	exit 1
fi

# mail setup
VOROMAIL='brian.tingle@ucop.edu'		# default
MAILFILE=$CONFDIR/mail.dat
export VOROMAIL MAILFILE
if [ -f $MAILFILE ]; then
	VOROMAIL=`cat $MAILFILE`
fi
# mail Function
voromail () {
	echo $1 | mailx -s "[ERROR] VORO wrapper" $VOROMAIL
}
