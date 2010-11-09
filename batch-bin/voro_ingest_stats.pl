#! /usr/bin/perl

# ------------------------------------
#
# Project:	OAC / Calisphere
#
# Name:		voro_ingest_stats.pl
#
# Function:	Run the two commands necessary to generate this week's voro
#		ingest statistics, logging their output, and send mail
#		if there are any errors.  Designed to run unattended.
#
# Command line parameters:
#		1 - optional - the command to find new and updated EAD and
#			METS objects.  if this parameter is omitted or is
#			of length zero, then the command is
#			"find_new_and_updated.pl" in the same directory as
#			this script, and it is executed with a single
#			command line parameter of a single hyphen.
#
#		2 - optional - the command to generate the HTML reports.
#			if this parameter is omitted or of length zero, the
#			command is "summarize_new_and_updated.pl" in the same
#			directory as this script, with no command line
#			parameters.
#
#		3 - optional - the e-mail address to which to send any
#			failures.  if this parameter is omitted or of length
#			zero, send them to the "dsc" account on this machine.
#
#		4 - optional - the directory into which to write the execution
#			logs (i.e., the STDERR and STDOUT output) of the two
#			commands.  if this parameter is omitted or of length
#			zero, the directory is "/dsc/data/ingest-stats/logs".
#
# Author:	Michael A. Russell
#
# Revision History:
#		2009/5/27 - MAR - Initial writing
#		2009/6/16 - MAR - Change the message if the commands we run
#			don't generate any output.
#       2010/10/27 - MER - Change to work in consolidated dsc server environment
#
# ------------------------------------

use strict;
use warnings;

# Declare our variable names.
use vars qw(
	$c
	$command_one
	$command_one_param
	$command_one_short
	@command_out
	$command_two
	$command_two_short
	$e_mail_addr
	$exit_code
	$log_dir
	$log_timestamp
	$output_is
	$nearby
	@now
	$pos
	);

# Declare subroutines that we'll define later.
sub log_and_mail;

# Don't print any errors, until we can get our own STDOUT/STDERR redirected
# into the log directory, if at all possible.

# Get the command name for error messages.
$pos = rindex($0, "/");
$c = ($pos > 0) ? substr($0, $pos + 1) : $0;
$nearby = ($pos > 0) ? substr($0, 0, $pos + 1) : "";
$nearby = "./" if ($nearby eq "");
undef $pos;

# Examine command line parameters.
if ((scalar(@ARGV) >= 1) && (length($ARGV[0]) > 0)) {
	$command_one = $ARGV[0];
	if ($command_one =~ m|/([^/]+)$|) {
		$command_one_short = $1;
		}
	else {
		$command_one_short = $command_one;
		}
	$command_one_param = "";
	}
else {
	$command_one_short = "find_new_and_updated.pl";
	$command_one = $nearby . $command_one_short;
	$command_one_param = "-";
	}

if ((scalar(@ARGV) >= 2) && (length($ARGV[1]) > 0)) {
	$command_two = $ARGV[1];
	if ($command_two =~ m|/([^/]+)$|) {
		$command_two_short = $1;
		}
	else {
		$command_two_short = $command_two;
		}
	}
else {
	$command_two_short = "summarize_new_and_updated.pl";
	$command_two = $nearby . $command_two_short;
	}

if ((scalar(@ARGV) >= 3) && (length($ARGV[2]) > 0)) {
	$e_mail_addr = $ARGV[2];
	}
else {
	$e_mail_addr = "dsc";
	}

if ((scalar(@ARGV) >= 3) && (length($ARGV[2]) > 0)) {
	$e_mail_addr = $ARGV[2];
	}
else {
	$e_mail_addr = "dsc";
	}

if ((scalar(@ARGV) >= 4) && (length($ARGV[3]) > 0)) {
	$log_dir = $ARGV[3];
	}
else {
	$log_dir = "/dsc/data/ingest-stats/logs";
	}

# Create the timestamp for the log file(s) for this run.
@now = localtime( );
$log_timestamp = sprintf("%04d%02d%02d.%02d%02d%02d.$$", $now[5] + 1900,
	$now[4] + 1, $now[3], $now[2], $now[1], $now[0]);

# If the log directory doesn't exist, we cannot proceed, and we'll go ahead
# and put something on STDERR.
unless (-e $log_dir) {
	die "$c:  log directory \"$log_dir\" does not exist, stopped";
	}
unless (-d _) {
	die "$c:  log directory \"$log_dir\" is not a directory, stopped";
	}
open(STDOUT, ">", "$log_dir/$c.$log_timestamp.log") ||
	die "$c:  unable to redirect STDOUT to ",
		"\"$log_dir/$c.$log_timestamp.log\", $!, stopped";
open(STDERR, ">&STDOUT") ||
	die "$c:  unable to redirect STDERR to ",
		"\"$log_dir/$c.$log_timestamp.log\", $!, stopped";

# Our STDOUT and STDERR have been redirected to a log file.

if (scalar(@ARGV) > 4) {
	print STDERR "$c:  this script uses only the first 4 command line ",
		"parameter - all beyond that have been ignored\n";
	}

# Check whether our commands exist and are executable.
foreach ($command_one, $command_two) {
	unless (-e $_) {
		log_and_mail "$c:  command \"$_\" does not exist\n";
		}
	unless (-f _) {
		log_and_mail "$c:  command \"$_\" is not a file\n";
		}
	unless (-x _) {
		log_and_mail "$c:  you do not have enough permission to " .
			"execute command \"$_\"\n";
		}
	}

# If we have a parameter for command one, append it.
if (length($command_one_param) > 0) {
	$command_one .= " $command_one_param";
	}

# Execute command one, and log its output, if it generated any.
@command_out = `$command_one 2>&1`;
$exit_code = $? >> 8;
if (scalar(@command_out) > 0) {
	open(LOG, ">", "$log_dir/$command_one_short.$log_timestamp.log") ||
		log_and_mail "$c:  unable to open " .
			"\"$log_dir/$command_one_short.$log_timestamp.log\" " .
			"for output,$!\n";
	print LOG @command_out;
	close(LOG);
	$output_is = "its output can be found in file " .
		"\"$log_dir/$command_one_short.$log_timestamp.log\"";
	}
else {
	$output_is = "it generated no STDOUT/STDERR output";
	}
if ($exit_code != 0) {
	log_and_mail "$c:  execution of command \"$command_one\" failed with " .
		"exit code $exit_code, $output_is\n";
	}
if (scalar(@command_out) > 0) {
	print "$c:  the output of command \"$command_one\" is in file ",
		"\"$log_dir/$command_one_short.$log_timestamp.log\"\n";
	}
else {
	print "$c:  command \"$command_one\" generated no STDOUT/STDERR ",
		"output\n";
	}

# Execute command two, and log its output, if it generated any.
@command_out = `$command_two 2>&1`;
$exit_code = $? >> 8;
if (scalar(@command_out) > 0) {
	open(LOG, ">", "$log_dir/$command_two_short.$log_timestamp.log") ||
		log_and_mail "$c:  unable to open " .
			"\"$log_dir/$command_two_short.$log_timestamp.log\" " .
			"for output,$!\n";
	print LOG @command_out;
	close(LOG);
	$output_is = "its output can be found in file " .
		"\"$log_dir/$command_two_short.$log_timestamp.log\"";
	}
else {
	$output_is = "it generated no STDOUT/STDERR output";
	}
if ($exit_code != 0) {
	log_and_mail "$c:  execution of command \"$command_two\" failed with " .
		"exit code $exit_code, $output_is\n";
	}
if (scalar(@command_out) > 0) {
	print "$c:  the output of command \"$command_two\" is in file ",
		"\"$log_dir/$command_two_short.$log_timestamp.log\"\n";
	}
else {
	print "$c:  command \"$command_two\" generated no STDOUT/STDERR ",
		"output\n";
	}

# Everything was OK.  Say so.
print "$c:  successful termination\n";

# -----
# Subroutine to log and mail a message.
sub log_and_mail {
	# If we're mailing, it's probably an unrecoverable error, so write
	# on STDERR (even though STDOUT should be going to the same place).
	print STDERR @_;

	# Attempt to send mail.
	open(MAIL, "|-", "/usr/lib/sendmail -t") ||
		die "$c:  unable to send mail, the attempt to open a pipe ",
			"to /usr/lib/sendmail failed, $!, stopped";
	print MAIL "To:  $e_mail_addr\n";
	print MAIL "Subject:  Failure Detected By Script $c\n";
	print MAIL "\n";
	print MAIL @_;
	close(MAIL);

	# If we're logging and mailing, it's the last thing we should do.
	exit(1);
	}
