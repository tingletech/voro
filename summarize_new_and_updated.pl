#! /usr/bin/perl

# ------------------------------------
#
# Project:	OAC / Calisphere
#
# Name:		summarize_new_and_updated.pl
#
# Function:	Generate summary information about new and updated EAD
#		and METS objects.
#
# Command line parameters:
#		1 - optional - the file containing the detail information
#			about new and updated EAD and METS objects.  the
#			default (if this parameter is omitted or of length
#			zero) is "/voro/ingest/data/ingest_stats.txt".
#
#		2 - optional - date for which to do the summarization.
#			the default (if this parameter is omitted or of length
#			zero) is today's date if today is Friday, or the date
#			of the previous Friday, if today is not Friday.
#			the format of the value is "yyyy/mm/dd".
#
#		3 - optional - the directory into which to write the HTML
#			summary files.  the default (if this parameter is
#			omitted or of length zero) is a subdirectory of
#			"/voro/ingest/html" by the name "yyyymmdd" where that
#			is the date for the summarization (as specified by the
#			second command line parameter).
#	TODO
#	==> change to yyyy/yyyymmdd 
#
#		4 - optional - the data necessary to access the production
#			OAC MySQL database.  this parameter gives the 5 pieces
#			of data, separated by slashes.  its format is
#			"host/port/user/password/database".  the default (if
#			this parameter is omitted or of length zero) is
#			"oac4db-prod.cdlib.org/3340/oac4ro/oac41ro/oac4".
#
#			(this is used to get the translation of EAD parent
#			ARK number to cdlpath.)
#
#		5 - optional - the path to use to access a MySQL client
#			command.  the default (if this parameter is omitted
#			or of length zero) is
#			"/cdlcommon/products/mysql/bin/mysql".
#
#		6 - optional - the path to the finding aids.  the default
#			(if this parameter is omitted or of length zero) is
#			"/voro/data/oac-ead/prime2002".
#
# Author:	Michael A. Russell
#
# Revision History:
#		2009/5/13 - MAR - Initial writing
#		2009/5/27 - MAR - Found bug in YTD counts.
#		2009/5/27 - MAR - Switched from "repo.xml" files to the
#			MySQL database, to get the ARK number-to-cdlpath
#			translation for EADs.
#		2009/8/28 - MAR - Put an asterisk to the left of a finding
#			aid's link in the summary, if it contains a "<dao>"
#			or "<daogrp>" element.  Change the link for a
#			finding aid from "content.cdlib.org" to
#			"oac.cdlib.org/findaid".
#		2009/8/31 - MAR - Don't die if more than one EAD has the same
#			ARK number.  Instead, generate a report for that.
#		2009/9/9 - MAR - The "<dao>" and "<daogrp>" in messages
#			needs to appear as "&lt;dao&gt;" and "&lt;daogrp&gt;",
#			because this is going in HTML.
#		2009/9/9 - MAR - Took out some blank lines that I hadn't meant
#			to leave in.
#		2009/9/14 - MAR - Add a link to the staging EADs/METS with
#			text "stage".
#
#  --> 		2010/05/07 bct digital extent stats
#
# ------------------------------------

use strict;
use warnings;
use Time::Local;
use XML::LibXML;

# Declare our variable names.
use vars qw(
	$ark_number
	%ark_to_cdlpath
	$c
	$count
	%counts
	@date_weekly
	@date_ytd
	$detail_file
	@duplicate_arks
	%ead_ark_to_info
	$ead_dir
	$from_date
	$has_dao_or_daogrp
	$i
	$line_no
	$mets_or_ead
	$mysql_command
	$mysql_info
	$naan
	$nearby
	$new_or_updated
	$output_dir
	$parser
	$pos
	$stage_url
	@summarization_date
	@the_date
	$timestamp
	$total
	$to_date
	$type_specific
	$url
	);

# Declare subroutines that we'll define later.
sub load_mysql_data;
sub date_in_range;
sub load_dao_or_daogrp_info;
sub build_report_string;

# Get the command name for error messages.
$pos = rindex($0, "/");
$c = ($pos > 0) ? substr($0, $pos + 1) : $0;
$nearby = ($pos > 0) ? substr($0, 0, $pos + 1) : "";
$nearby = "./" if ($nearby eq "");
undef $pos;

# Examine command line parameters.
if ((scalar(@ARGV) >= 1) && (length($ARGV[0]) > 0)) {
	$detail_file = $ARGV[0];
	}
else {
	$detail_file = "/voro/ingest/data/ingest_stats.txt";
	}

if ((scalar(@ARGV) >= 2) && (length($ARGV[1]) > 0)) {
	unless ($ARGV[1] =~ /^(\d+)\/(\d+)\/(\d+)$/) {
		die "$c:  \"$ARGV[1]\" is not in \"YYYY/MM/DD\" format, ",
			"stopped";
		}

	# Convert the date into seconds, as of noon on that day.
	$i = timelocal(0, 0, 12, $3, $2 - 1, $1 - 1900);

	# Convert that back into a date, to normalize it, and to find out
	# if it was a Friday.
	@the_date = localtime($i);

	# Check that it was Friday.
	unless ($the_date[6] == 5) {
		die "$c:  ", sprintf("%04d/%02d/%02d", $the_date[5] + 1900,
			$the_date[4] + 1, $the_date[3]), " was not a ",
			"Friday, stopped";
		}

	# Use that date.
	@summarization_date = ($the_date[5] + 1900, $the_date[4] + 1,
		$the_date[3]);
	}
else {
	# Get the date of the most recent Friday, or the date today if today
	# is Friday.
	undef @summarization_date;
	for ($i = 0; $i <= 6; $i++) {
		# Get the date $i days ago.
		@the_date = localtime(time( ) - ($i * 24 * 60 * 60));

		# If it wasn't a Friday, go another day further back.
		next unless ($the_date[6] == 5);

		# We found Friday.  Use that date.
		@summarization_date = ($the_date[5] + 1900, $the_date[4] + 1,
			$the_date[3]);
		undef @the_date;
		last;
		}
	unless (@summarization_date) {
		die "$c:  unable to find the date of the most recent ",
			"Friday, stopped";
		}
	}

if ((scalar(@ARGV) >= 3) && (length($ARGV[2]) > 0)) {
	$output_dir = $ARGV[2];
	}
else {
	$output_dir = "/voro/ingest/html/" . sprintf("%04d%02d%02d",
		$summarization_date[0], $summarization_date[1],
		$summarization_date[2]);
	}

if ((scalar(@ARGV) >= 4) && (length($ARGV[3]) > 0)) {
	$mysql_info = $ARGV[3];
	}
else {
	$mysql_info = "oac4db-prod.cdlib.org/3340/oac4ro/oac41ro/oac4";
	}

if ((scalar(@ARGV) >= 5) && (length($ARGV[4]) > 0)) {
	$mysql_command = $ARGV[4];
	}
else {
	$mysql_command = "/cdlcommon/products/mysql/bin/mysql";
	}

if ((scalar(@ARGV) >= 6) && (length($ARGV[5]) > 0)) {
	$ead_dir = $ARGV[5];
	}
else {
	$ead_dir = "/voro/data/oac-ead/prime2002";
	}

if (scalar(@ARGV) > 6) {
	print STDERR "$c:  this script uses only the first 6 command line ",
		"parameter - all beyond that have been ignored\n";
	}

# Attempt to create the output directory.
if (-e $output_dir) {
	unless (-d _) {
		die "$c:  output directory \"$output_dir\" exists, but ",
			"it is not a directory, stopped";
		}
	}
else {
	unless (mkdir($output_dir, 0775)) {
		die "$c:  unable to create output directory \"$output_dir\", ",
			"$!, stopped";
		}
	}

# Make sure the command is executable.
unless (-e $mysql_command) {
	die "$c:  command \"$mysql_command\" does not exist, stopped";
	}
unless (-f _) {
	die "$c:  command \"$mysql_command\" does not exist, stopped";
	}
unless (-x _) {
	die "$c:  you do not have the permissions necessary to execute ",
		"command \"$mysql_command\", stopped";
	}

# Create a parser to use.
$parser = XML::LibXML->new( );

# Build the ARK-to-cdlpath conversion hash.
%ark_to_cdlpath = ( );
load_mysql_data($mysql_info);

# Construct the hash that converts ARK numbers to the answer to the
# question "does the EAD contain a <dao> or <daogrp>?"  (This becomes
# complicated by the fact that it's possible to have more than one
# EAD with an ARK number.  It's wrong, but it's possible.)
%ead_ark_to_info = ( );
load_dao_or_daogrp_info($ead_dir);

# Zero counts (by creating empty hashes).
%counts = ( );
$counts{"weekly-new-ead"} = { };
$counts{"weekly-new-mets"} = { };
$counts{"weekly-updated-ead"} = { };
$counts{"weekly-updated-mets"} = { };
$counts{"ytd-new-ead"} = { };
$counts{"ytd-new-mets"} = { };
$counts{"ytd-updated-ead"} = { };
$counts{"ytd-updated-mets"} = { };

# Calculate the beginning date of the weekly counts.
$i = timelocal(0, 0, 12, $summarization_date[2], $summarization_date[1] - 1,
	$summarization_date[0] - 1900);
@the_date = localtime($i - (6 * 24 * 60 * 60));
@date_weekly = ($the_date[5] + 1900, $the_date[4] + 1, $the_date[3]);
undef @the_date;
undef $i;

# Calculate the beginning date of the "year-to-date" counts.  It is the
# previous July 1.
if ($summarization_date[1] >= 7) {
	@date_ytd = ($summarization_date[0], 7, 1);
	}
else {
	@date_ytd = ($summarization_date[0] - 1, 7, 1);
	}

# Open the detail file.
open(DETAIL, "<", $detail_file) ||
	die "$c:  unable to open file \"$detail_file\" for input, $!, stopped";

# Process the lines in the detail file.
$line_no = 0;
while (<DETAIL>) {
	chomp;
	$line_no++;

	# Parse the line.
	unless (/^\S+\/(\d+)\/[a-z0-9]{2}\/([^\/]+)\s+(METS|EAD)\s+\S+\s(new|updated)\s(\d+)\s+"([^"]+)"$/i) {
		die "$c:  format of line $line_no in \"$detail_file\" is ",
			"invalid, stopped";
		}

	# Give symbolic names to the values on the line.
	$naan = $1;
	$ark_number = $2;
	$mets_or_ead = lc($3);
	$new_or_updated = lc($4);
	$timestamp = $5;
	$type_specific = $6;

	# Construct the ARK number from the NAAN and the ending.
	$ark_number = "ark:/$naan/$ark_number";

	# If this is an EAD, attempt to convert the type-specific data (which
	# is an ARK number) to a cdlpath, if possible.
	if ($mets_or_ead eq "ead") {
		if (exists($ark_to_cdlpath{$type_specific})) {
			$type_specific = $ark_to_cdlpath{$type_specific};
			}
		}

	# If it's with the weekly range, update those counts, by adding
	# the ARK number of the item to the array.
	if (date_in_range($timestamp, \@date_weekly, \@summarization_date)) {
		if (exists($counts{"weekly-$new_or_updated-$mets_or_ead"}
			{$type_specific})) {
			push @{$counts{"weekly-$new_or_updated-$mets_or_ead"}
				{$type_specific}}, $ark_number;
			}
		else {
			$counts{"weekly-$new_or_updated-$mets_or_ead"}
				{$type_specific} = [ $ark_number ];
			}
		}

	# Similarly for the year-to-date counts.
	if (date_in_range($timestamp, \@date_ytd, \@summarization_date)) {
		if (exists($counts{"ytd-$new_or_updated-$mets_or_ead"}
			{$type_specific})) {
			push @{$counts{"ytd-$new_or_updated-$mets_or_ead"}
				{$type_specific}}, $ark_number;
			}
		else {
			$counts{"ytd-$new_or_updated-$mets_or_ead"}
				{$type_specific} = [ $ark_number ];
			}
		}
	}

# Close the detail file.
close(DETAIL);

# Write out the weekly summary report file.
$from_date = sprintf("%04d/%02d/%02d", $date_weekly[0], $date_weekly[1],
	$date_weekly[2]);
$to_date = sprintf("%04d/%02d/%02d", $summarization_date[0],
	$summarization_date[1], $summarization_date[2]);

open(SUMM, ">", "$output_dir/summary.html") ||
	die "$c:  unable to open \"$output_dir/summary.html\" for output, ",
		"$!, stopped";
print SUMM "<html><head><title>Summary for $from_date to $to_date</title>\n";
print SUMM "</head><body><h1>Summary for $from_date to $to_date</h1>\n";

print SUMM "<br/><table border=\"1\"><tr><td><table>\n";
print SUMM "<tr><td colspan=\"2\"><h2>New EAD by Contributing Institution:",
	"</h2></td></tr>\n";
print SUMM "<tr><td>Institution</td><td>Count</td></tr>\n";
$total = 0;
foreach $type_specific (sort keys %{$counts{"weekly-new-ead"}}) {
	$count = scalar(@{$counts{"weekly-new-ead"}{$type_specific}});
	$total += $count;
	print SUMM "<tr><td>$type_specific</td><td>$count</td></tr>\n";
	}
print SUMM "<tr><td colspan=\"2\">Total: $total</td></tr>\n";
print SUMM "</table></td><tr></table>\n";

print SUMM "<br/><table border=\"1\"><tr><td><table>\n";
print SUMM "<tr><td colspan=\"2\"><h2>Updated EAD by Contributing Institution:",
	"</h2></td></tr>\n";
print SUMM "<tr><td>Institution</td><td>Count</td></tr>\n";
$total = 0;
foreach $type_specific (sort keys %{$counts{"weekly-updated-ead"}}) {
	$count = scalar(@{$counts{"weekly-updated-ead"}{$type_specific}});
	$total += $count;
	print SUMM "<tr><td>$type_specific</td><td>$count</td></tr>\n";
	}
print SUMM "<tr><td colspan=\"2\">Total: $total</td></tr>\n";
print SUMM "</table></td><tr></table>\n";

print SUMM "<br/><table border=\"1\"><tr><td><table>\n";
print SUMM "<tr><td colspan=\"2\"><h2>New METS by PROFILE:</h2></td></tr>\n";
print SUMM "<tr><td>PROFILE</td><td>Count</td></tr>\n";
$total = 0;
foreach $type_specific (sort keys %{$counts{"weekly-new-mets"}}) {
	$count = scalar(@{$counts{"weekly-new-mets"}{$type_specific}});
	$total += $count;
	print SUMM "<tr><td>$type_specific</td><td>$count</td></tr>\n";
	}
print SUMM "<tr><td colspan=\"2\">Total: $total</td></tr>\n";
print SUMM "</table></td><tr></table>\n";

print SUMM "<br/><table border=\"1\"><tr><td><table>\n";
print SUMM "<tr><td colspan=\"2\"><h2>Updated METS by PROFILE:</h2></td>",
	"</tr>\n";
print SUMM "<tr><td>PROFILE</td><td>Count</td></tr>\n";
$total = 0;
foreach $type_specific (sort keys %{$counts{"weekly-updated-mets"}}) {
	$count = scalar(@{$counts{"weekly-updated-mets"}{$type_specific}});
	$total += $count;
	print SUMM "<tr><td>$type_specific</td><td>$count</td></tr>\n";
	}
print SUMM "<tr><td colspan=\"2\">Total: $total</td></tr>\n";
print SUMM "</table></td><tr></table>\n";

print SUMM "</body></html>\n";
close(SUMM);

# Write out the weekly detail files.
foreach $new_or_updated ("new", "updated") {
	foreach $mets_or_ead ("mets", "ead") {
		open(SUMM, ">",
			"$output_dir/$mets_or_ead-$new_or_updated.html") ||
			die "$c:  unable to open \"$output_dir/",
				"$mets_or_ead-$new_or_updated.html\" for ",
				"output, $!, stopped";
		print SUMM "<html><head><title>Detail for $new_or_updated ",
			uc($mets_or_ead), " from $from_date to $to_date",
			"</title>\n";
		print SUMM "</head><body><h1>Detail for $new_or_updated ",
			uc($mets_or_ead), " from $from_date to $to_date",
			"</h1>\n";
		print SUMM "<table>\n";

		print SUMM "<tr><td colspan=\"4\"><hr/></td></tr>\n";
		foreach $type_specific (sort keys
			%{$counts{"weekly-$new_or_updated-$mets_or_ead"}}) {
			print SUMM "<tr><td>$type_specific</td><td ",
				"colspan=\"3\">&nbsp;</td></tr>\n";
			foreach (@{$counts{
				"weekly-$new_or_updated-$mets_or_ead"}
				{$type_specific}}) {
				# Use a different URL for EADs than for METS.
				if ($mets_or_ead eq "ead") {
					# Determine if the finding aid has
					# a "<dao>" or "<daogrp>" element
					$has_dao_or_daogrp =
						build_report_string($_);

					# URL for EAD.
					$url = "http://oac.cdlib.org/" .
						"findaid/$_";

					# Staging URL for EAD.
					$stage_url = "http://oac-stage.cdlib." .
						"org/findaid/$_";
					}
				else {
					# URL for METS.
					$url = "http://content.cdlib.org/$_";

					# Staging URL for METS.
					$stage_url = "http://voro.cdlib.org/$_";

					# No asterisk for a METS file.
					$has_dao_or_daogrp = "&nbsp;";
					}
				print SUMM "<tr><td>&nbsp;</td>\n";
				print SUMM "<td>$has_dao_or_daogrp</td>\n";
				print SUMM "<td><a href=\"$stage_url\">",
					"Stage</a></td>\n";
				print SUMM "<td><a href=\"$url\">$url</a></td>",
					"</tr>\n";
				}
			print SUMM "<tr><td colspan=\"4\"><hr/></td></tr>\n";
			}

		print SUMM "</table></body></html>\n";
		close(SUMM);
		}
	}

# Write out the year-to-date summary report.
$from_date = sprintf("%04d/%02d/%02d", $date_ytd[0], $date_ytd[1],
	$date_ytd[2]);
open(SUMM, ">", "$output_dir/year-to-date.html") ||
	die "$c:  unable to open \"$output_dir/year-to-date.html\" for ",
		"output, $!, stopped";
print SUMM "<html><head><title>Summary for $from_date to $to_date</title>\n";
print SUMM "</head><body><h1>Summary for $from_date to $to_date</h1>\n";

print SUMM "<br/><table border=\"1\"><tr><td><table>\n";
print SUMM "<tr><td colspan=\"2\"><h2>New EAD by Contributing Institution:",
	"</h2></td></tr>\n";
print SUMM "<tr><td>Institution</td><td>Count</td></tr>\n";
$total = 0;
foreach $type_specific (sort keys %{$counts{"ytd-new-ead"}}) {
	$count = scalar(@{$counts{"ytd-new-ead"}{$type_specific}});
	$total += $count;
	print SUMM "<tr><td>$type_specific</td><td>$count</td></tr>\n";
	}
print SUMM "<tr><td colspan=\"2\">Total: $total</td></tr>\n";
print SUMM "</table></td><tr></table>\n";

print SUMM "<br/><table border=\"1\"><tr><td><table>\n";
print SUMM "<tr><td colspan=\"2\"><h2>Updated EAD by Contributing Institution:",
	"</h2></td></tr>\n";
print SUMM "<tr><td>Institution</td><td>Count</td></tr>\n";
$total = 0;
foreach $type_specific (sort keys %{$counts{"ytd-updated-ead"}}) {
	$count = scalar(@{$counts{"ytd-updated-ead"}{$type_specific}});
	$total += $count;
	print SUMM "<tr><td>$type_specific</td><td>$count</td></tr>\n";
	}
print SUMM "<tr><td colspan=\"2\">Total: $total</td></tr>\n";
print SUMM "</table></td><tr></table>\n";

print SUMM "<br/><table border=\"1\"><tr><td><table>\n";
print SUMM "<tr><td colspan=\"2\"><h2>New METS by PROFILE:</h2></td></tr>\n";
print SUMM "<tr><td>PROFILE</td><td>Count</td></tr>\n";
$total = 0;
foreach $type_specific (sort keys %{$counts{"ytd-new-mets"}}) {
	$count = scalar(@{$counts{"ytd-new-mets"}{$type_specific}});
	$total += $count;
	print SUMM "<tr><td>$type_specific</td><td>$count</td></tr>\n";
	}
print SUMM "<tr><td colspan=\"2\">Total: $total</td></tr>\n";
print SUMM "</table></td><tr></table>\n";

print SUMM "<br/><table border=\"1\"><tr><td><table>\n";
print SUMM "<tr><td colspan=\"2\"><h2>Updated METS by PROFILE:</h2></td></tr>\n";
print SUMM "<tr><td>PROFILE</td><td>Count</td></tr>\n";
$total = 0;
foreach $type_specific (sort keys %{$counts{"ytd-updated-mets"}}) {
	$count = scalar(@{$counts{"ytd-updated-mets"}{$type_specific}});
	$total += $count;
	print SUMM "<tr><td>$type_specific</td><td>$count</td></tr>\n";
	}
print SUMM "<tr><td colspan=\"2\">Total: $total</td></tr>\n";
print SUMM "</table></td><tr></table>\n";

print SUMM "</body></html>\n";
close(SUMM);

# Find the ARK numbers that appear in more than one EAD.
@duplicate_arks = ( );
foreach (keys %ead_ark_to_info) {
	if (scalar(@{$ead_ark_to_info{$_}}) > 2) {
		push @duplicate_arks, $_;
		}
	}

# Write out the report of EADs that have the same ARK number.
open(DUPARK, ">", "$output_dir/eads-with-duplicate-ark-numbers.html") ||
	die "$c:  unable to open \"$output_dir/eads-with-duplicate-ark-",
		"numbers.html\" for output, $!, stopped";
print DUPARK "<html><head><title>EADs With The Same ARK Number</title>\n";
print DUPARK "</head><body><h1>EADs With The Same ARK Number</h1>\n";
print DUPARK "<br/>\n";
if (scalar(@duplicate_arks) == 0) {
	print DUPARK "No ARK numbers have been assigned to more than one ",
		"EAD.\n";
	}
else {
	print DUPARK "<table border=\"1\">\n";
	print DUPARK "<tr><td colspan=\"2\">Count of ARK numbers that have ",
		"been assigned to more than one EAD is ",
		scalar(@duplicate_arks), "</td></tr>\n";
	print DUPARK "<tr><td>ARK Number</td><td>EAD File Names</td></tr>\n";
	foreach (@duplicate_arks) {
		print DUPARK "<tr><td>$_</td><td>\n";
		for ($i = 0; $i < scalar(@{$ead_ark_to_info{$_}}); $i += 2) {
			if ($i != 0) {
				print DUPARK "<br/>";
				}
			print DUPARK ${$ead_ark_to_info{$_}}[$i], "\n";
			}
		}
	print DUPARK "</table>\n";
	}
print DUPARK "</body></html>\n";
close(DUPARK);

# Megabyte MB stats for Mary
my $sizestats_command = "/usr/bin/find $ead_dir -type d -exec du -sh {} >> $output_dir/ead-disk-stats.txt \\;";
my $sizestats_output = `$sizestats_command`;
my $sizestats_exit_code = $? >> 8;
unless ($sizestats_exit_code == 0) {
        die qq{$c:  command "$sizestats_command" terminated with exit code $sizestats_exit_code, stopped};
}




# -----
# Subroutine to build the ARK-to-cdlpath conversion hash, using the
# OAC MySQL database.
sub load_mysql_data {
	my $mysql_info = $_[0];

	my $ark;
	my @ark_list;
	my $cdlpath;
	my @cdlpath_list;
	my $command;
	my $exit_code;
	my $mysql_database;
	my $mysql_host;
	my $mysql_output;
	my $mysql_password;
	my $mysql_port;
	my $mysql_user;
	my $response;
	my $row;
	my @rows;

	# Pull the 5 values out of the string.
	unless ($mysql_info =~ m|^([^/]+)/([^/]+)/([^/]+)/([^/]+)/([^/]+)$|) {
		die "$c:  format of command line parameter 4 ",
			"(\"$mysql_info\") is invalid, stopped";
		}
	$mysql_host = $1;
	$mysql_port = $2;
	$mysql_user = $3;
	$mysql_password = $4;
	$mysql_database = $5;

	# Construct the command we would like to execute.
	$command = "$mysql_command " .
		"-h $mysql_host " .
		"-P $mysql_port " .
		"-u $mysql_user " .
		"-p$mysql_password " .
		"-D $mysql_database " .
		"-X " .
		"-e \"select ark,cdlpath from oac_institution;\"";

	# Execute it, and get the output.
	$mysql_output = `$command 2>&1`;
	$exit_code = $? >> 8;
	unless ($exit_code == 0) {
		die "$c:  command \"$command\" terminated with exit code ",
			"$exit_code, and the first 200 characters of its ",
			"output \"", substr($mysql_output, 0, 200),
			"\", stopped";
		}

	# Attempt to parse the output.
	eval {
		$response = $parser->parse_string($mysql_output);
		};
	if (length($@) != 0) {
		die "$c:  unable to parse the output of command \"$command\", ",
			"$@, and the first 200 characters of its output was \"",
			substr($mysql_output, 0, 200), "\", stopped";
		}

	# Make sure that we got back <resultset> XML.
	unless ($response->documentElement( )->nodeName( ) eq "resultset") {
		die "$c:  command \"$command\" returned <",
			$response->documentElement( )->nodeName( ),
			"> XML, not <resultset> XML, as expected, the first ",
			"200 characters of its output was \"",
			substr($mysql_output, 0, 200), "\", stopped";
		}

	# Pull out the <row>s.
	@rows = $response->findnodes("//*[local-name(.) = 'row']");

	# If we got none, something is wrong, and we can probably display all
	# of the command's output (because we got the right kind of XML,
	# but without any real content).
	if (scalar(@rows) == 0) {
		die "$c:  command \"$command\" returned <resultset> XML, with ",
			"no <row> elements, and its output was ",
			"\"$mysql_output\", stopped";
		}

	# Process each row.
	foreach $row (@rows) {
		# Get the <field name="ark"> child.
		@ark_list = $row->findnodes("*[local-name(.) = 'field' and " .
			"\@name = 'ark']");
		unless (scalar(@ark_list) == 1) {
			die "$c:  in the output of command \"$command\", ",
				"did not find exactly one ",
				"'<field name=\"ark\">' child of '",
				$row->toString( ), "', found ",
				scalar(@ark_list), ", stopped";
			}
		$ark = $ark_list[0]->textContent( );
		if ((! defined($ark)) || (length($ark) == 0)) {
			die "$c:  in the output of command \"$command\", ",
				"found no text content of the single ",
				"'<field name=\"ark\">' child of '",
				$row->toString( ), "', stopped";
			}

		# Get the <field name="cdlpath"> child.  (Except, it's OK
		# if we don't get anything for this value.  We'll ignore
		# the "association".)
		@cdlpath_list = $row->findnodes("*[local-name(.) = 'field' " .
			"and \@name = 'cdlpath']");
		unless (scalar(@cdlpath_list) == 1) {
			die "$c:  in the output of command \"$command\", ",
				"did not find exactly one ",
				"'<field name=\"cdlpath\">' child of '",
				$row->toString( ), "', found ",
				scalar(@cdlpath_list), ", stopped";
			}
		$cdlpath = $cdlpath_list[0]->textContent( );
		next unless (defined($cdlpath) && (length($cdlpath) != 0));

		# Save the association in our hash.
		$ark_to_cdlpath{$ark} = $cdlpath;
		}
	}

# -----
# Subroutine to decide whether a timestamp is within a given date range.
sub date_in_range {
	my $the_timestamp = $_[0];
	my $beginning = $_[1];
	my $ending = $_[2];

	my @the_date;

	# Get the date from the timestamp.
	@the_date = localtime($the_timestamp);

	# Convert it to the same form as our beginning and ending dates.
	@the_date = ($the_date[5] + 1900, $the_date[4] + 1, $the_date[3]);

	# If the date is before the beginning, it's not within range.
	return(0) if ($the_date[0] < $$beginning[0]);
	return(0) if (($the_date[0] == $$beginning[0]) &&
		($the_date[1] < $$beginning[1]));
	return(0) if (($the_date[0] == $$beginning[0]) &&
		($the_date[1] == $$beginning[1]) &&
		($the_date[2] < $$beginning[2]));

	# If the date is after the ending, it's not within range.
	return(0) if ($the_date[0] > $$ending[0]);
	return(0) if (($the_date[0] == $$ending[0]) &&
		($the_date[1] > $$ending[1]));
	return(0) if (($the_date[0] == $$ending[0]) &&
		($the_date[1] == $$ending[1]) && ($the_date[2] > $$ending[2]));

	# It passed all the tests.  It's within range.
	return(1);
	}

# -----
# Subroutine to load the hash that translates between ARK numbers and
# answers to the question "does the EAD contain a <dao> or a <daogrp>?"
sub load_dao_or_daogrp_info {
	my $ead_dir = $_[0];

	my @dir_contents;
	my $dir_entry;
	my $document;
	my $ead_ark_number;
	my $ead_file_name;
	my $has_dao_or_daogrp;
	my @nodes;
	my @subdirs;

	# Get the contents of the directory.
	opendir(DIR, $ead_dir) ||
		die "$c:  unable to open directory \"$ead_dir\", $!, stopped";
	@dir_contents = readdir(DIR);
	closedir(DIR);

	# Process the contents of the directory.
	@subdirs = ( );
	foreach $dir_entry (@dir_contents) {
		# Skip "." and ".." as a matter of course.
		next if ($dir_entry eq ".");
		next if ($dir_entry eq "..");

		# Construct the full file name.
		$ead_file_name = "$ead_dir/$dir_entry";

		# Skip it if it's a symlink.
		next if (-l $ead_file_name);

		# If it's a subdirectory, save it, to process it later.
		if (-d $ead_file_name) {
			push @subdirs, $ead_file_name;
			next;
			}

		# If it's not a file, complain.
		unless (-f _) {
			die "$c:  \"$ead_file_name\" is neither a ",
				"symbolic link, a directory, nor a file, ",
				"stopped";
			}

		# If it's not an XML file, skip it.
		next unless ($dir_entry =~ /.xml$/i);

		# Parse the finding aid.
		eval {
			$document = $parser->parse_file("$ead_file_name");
			};
		if (length($@) != 0) {
			die "$c:  unable to parse \"$ead_file_name\", ",
				"$@, stopped";
			}

		# Get the EAD's ARK number.
		@nodes = $document->findnodes(
			"/ead/eadheader/eadid/\@identifier");
		if (scalar(@nodes) == 0) {
			die "$c:  unable to find the ARK number ",
				"(\"/ead/eadheader/eadid/\@identifier\") in ",
				"\"$ead_file_name\", stopped";
			}
		if (scalar(@nodes) > 1) {
			die "$c:  more than one ARK number ",
				"(\"/ead/eadheader/eadid/\@identifier\") in ",
				"\"$ead_file_name\", found ",
				scalar(@nodes), " ARK numbers, stopped";
			}
		$ead_ark_number = $nodes[0]->getValue( );
		unless (defined($ead_ark_number)) {
			die "$c:  found the ARK number ",
				"(\"/ead/eadheader/eadid/\@identifier\") in ",
				"\"$ead_file_name\", but ",
				"\"getValue( )\" return \"undef\" ,stopped";
			}
		unless ($ead_ark_number =~ m|^ark:/\d+/[a-z0-9]+$|) {
			die "$c:  the format of the ARK number ",
				"(\"/ead/eadheader/eadid/\@identifier\") in ",
				"\"$ead_file_name\" ",
				"(\"$ead_ark_number\") is invalid, stopped";
			}

		# Get the "<dao>" and "<daogrp>" elements.
		@nodes = $document->findnodes("//*[local-name(.) = 'dao' or " .
			"local-name(.) = 'daogrp']");

		# Record whether the EAD has any "<dao>" and/or "<daogrp>"
		# element.s
		if (scalar(@nodes) == 0) {
			$has_dao_or_daogrp = 0;
			}
		else {
			$has_dao_or_daogrp = 1;
			}

		# File away data for this ARK number in our hash.
		if (exists($ead_ark_to_info{$ead_ark_number})) {
			push @{$ead_ark_to_info{$ead_ark_number}},
				$ead_file_name, $has_dao_or_daogrp;
			}
		else {
			$ead_ark_to_info{$ead_ark_number} =
				[ $ead_file_name, $has_dao_or_daogrp ];
			}
		}

	# Process any subdirectories we found.
	foreach (@subdirs) {
		load_dao_or_daogrp_info($_);
		}
	}

# -----
# Subroutine to build a string to report on whether an EAD has "<dao>" and/or
# "<daogrp>" elements.
sub build_report_string {
	my $ark_number = $_[0];

	my $i;
	my $return_string;

	# If this ARK number is not in our hash, return the error indication.
	unless (exists($ead_ark_to_info{$ark_number})) {
		return("Unable to find the EAD with ARK number " .
			"\"$ark_number\"");
		}

	# If this ARK number is associated with only one EAD, then return
	# "*" or "&nbsp", if that EAD contains at least one "<dao>" and/or
	# "<daogrp>" element, respectively, and "&nbsp;" otherwise.
	if (scalar(@{$ead_ark_to_info{$ark_number}}) <= 2) {
		if (${$ead_ark_to_info{$ark_number}}[1] == 0) {
			return("&nbsp;");
			}
		else {
			return("*");
			}
		}

	# Construct a longer string, since this ARK number is associated
	# with more than one EAD file.
	$return_string = "";
	for ($i = 0; $i < scalar(@{$ead_ark_to_info{$ark_number}}); $i += 2) {
		if ($i != 0) {
			$return_string .= "<br/>";
			}
		if (${$ead_ark_to_info{$ark_number}}[$i + 1] == 0) {
			$return_string .= "no &lt;dao&gt;/&lt;daogrp&gt; in " .
				"\"${$ead_ark_to_info{$ark_number}}[$i]\"";
			}
		else {
			$return_string .= "at least one &lt;dao&gt;/" .
				"&lt;daogrp&gt; in " .
				"\"${$ead_ark_to_info{$ark_number}}[$i]\"";
			}
		}
	return($return_string);
	}
