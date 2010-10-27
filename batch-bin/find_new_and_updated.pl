#! /usr/bin/perl

# ------------------------------------
#
# Project:	OAC / Calisphere
#
# Name:		find_new_and_updated.pl
#
# Function:	Using an existing list of EAD and METS objects, find any
#		such objects that are new or updated, and record information
#		about them.
#
# Command line parameters:
#		1 - optional - the name of the file which contains the last
#			run's data about all EAD and METS object.  if this
#			parameter is omitted or is of length zero, then
#			there is no "last run's data" to examine, and this
#			run should only gather data on existing objects.
#
#			if this parameter is the string consisting of a
#			single hyphen ("-"), then this script will scan
#			directory "/voro/ingest/data", for files with names
#			of the form "object_list.YYYYMMDD.txt", and will use
#			the one with the more recent "YYYYMMDD" date.
#
#		2 - optional - the name of the file into which will be
#			written this run's current information about all
#			EAD and METS objects.  the default (if this parameter
#			is omitted or is of length zero) is
#			"/voro/ingest/data/object_list.YYYYMMDD.txt", where
#			"YYYYMMDD" is today's date.  (this file should be
#			input to the subsequent run of this script.)
#
#		3 - optional - the directory in which the EAD and METS objects
#			reside.  the default (if this parameter is omitted
#			or is of length zero) is "/voro/XTF/data"
#
#		4 - optional - the name of the output file to which is
#			appended the information about the new and updated
#			EAD and METS objects, that was found during this run.
#			the default (if this parameter is omitted or of length
#			zero) is "/voro/ingest/data/ingest_stats.txt".  (it
#			is always opened for "append".)
#
# File formats:
#	Existing EAD and METS objects:
#		With respect to files that contain information about existing
#		EAD and METS objects, we have one such input file and one
#		such output file.  The formats of the lines in those files
#		is the same.  (The intent is that today's output file will be
#		next week's input file.)  The format of those lines is:
#
#		DIR TYPE FILE SIZE MTIME CTIME MD5SUM "TYPE-SPECIFIC"
#
#		where "DIR" is the directory of the object
#
#		where "TYPE" is the object type, and may be either "EAD" or
#			"METS"
#
#		where "FILE" is the name of the file within directory "DIR"
#			that the voro ingest statistics should "watch"
#
#		where "SIZE" is the size of the file, in bytes
#
#		where "MTIME" is the modification time of the file, expressed
#			as seconds since the epoch (see the definition of
#			"mtime" as a value returned by the "stat( )" function)
#
#		where "CTIME" is the status change time of the file, expressed
#			as seconds since the epoch (see the definition of
#			"ctime" as a value returned by the "stat( )" function)
#
#		where "MD5SUM" is the MD5 checksum of the file
#
#		where "TYPE-SPECIFIC" is additional information that is
#			specific to the type of file.  for EAD, we record
#			the parent's ARK, and for METS, we record the PROFILE.
#			the value is surrounded with double quotes.
#
#	New and updated EAD and METS objects:
#		This file is always opened for "append", so that each run's
#		information is accumulated.  The formats of the line in that
#		file are:
#
#		DIR TYPE FILE [new|updated] MTIME "TYPE-SPECIFIC"
#
#		where "DIR" is the directory of the object
#
#		where "TYPE" is the object type, and may be either "EAD" or
#			"METS"
#
#		where "FILE" is the name of the file within directory "DIR"
#			that the voro ingest statistics should "watch"
#
#		where the next parameter is "new" or "updated" depending
#			on whether the object is new or updated
#
#		where "MTIME" is the modification time of the file, expressed
#			as seconds since the epoch (see the definition of
#			"mtime" as a value returned by the "stat( )" function)
#
#		where "TYPE-SPECIFIC" is additional information that is
#			specific to the type of file.  for EAD, we record
#			the parent's ARK, and for METS, we record the PROFILE.
#			the value is surrounded with double quotes.
#
# Object type:	The object type is determined by looking in the directory
#		for the object.  (The directory will typically be
#		"/voro/XTF/data/*/XX/ARKNUMBER".)  If a file by the name
#		"ARKNUMBER.xml" is present, and it contains "<ead>" XML,
#		the object type is EAD, and "ARKNUMBER.xml" is the file to
#		"watch".  Otherwise, the type is "METS", and the file to
#		"watch" in the directory is "ARKNUMBER.mets.xml".
#
# Author:	Michael A. Russell
#
# Revision History:
#		2009/5/8 - MAR - Initial writing
#		2009/5/27 - MAR - Added check that the input and output object
#			list files are not the same.
#		2009/6/9 - MAR - Don't do the above check if we don't have
#			an input file.
#
# ------------------------------------

use strict;
use warnings;
use XML::LibXML;
use Digest::MD5;

# Declare our variable names.
use vars qw(
	$c
	$count_exactly_same
	$count_same_md5sum
	$dir
	@dir_info
	$input_info_file
	%last_runs_info
	$line_no
	$new_and_updated_file
	@now
	$object_dir
	$output_info_file
	$parser
	$pos
	);

# Declare subroutines that we'll define later.
sub process_dir;
sub process_file;
sub check_for_new_and_updated;

# Get the command name for error messages.
$pos = rindex($0, "/");
$c = ($pos > 0) ? substr($0, $pos + 1) : $0;
#$nearby = ($pos > 0) ? substr($0, 0, $pos + 1) : "";
#$nearby = "./" if ($nearby eq "");
undef $pos;

# Examine command line parameters.
if ((scalar(@ARGV) >= 1) && (length($ARGV[0]) > 0)) {
	$input_info_file = $ARGV[0];

	# If we have been requested to select the input file, do so now.
	if ($input_info_file eq "-") {
		opendir(DIR, "/voro/ingest/data") ||
			die "$c:  unable to open directory ",
				"\"/voro/ingest/data\", $!, stopped";
		my @input_dir_contents = ( );
		while (defined($_ = readdir(DIR))) {
			next unless (/^object_list\.\d{8}\.txt$/);
			push @input_dir_contents, $_;
			}
		closedir(DIR);
		if (scalar(@input_dir_contents) == 0) {
			die "$c:  first parameter was a hyphen, but there ",
				"were no potential input files in ",
				"\"/voro/ingest/data\", stopped";
			}
		@input_dir_contents = sort(@input_dir_contents);

		# Select the one with the largest YYYYMMDD.
		$input_info_file = "/voro/ingest/data/" .
			$input_dir_contents[$#input_dir_contents];
		print "$c:  selected \"$input_info_file\" as the input file\n";
		}
	}
else {
	undef $input_info_file;
	}

if ((scalar(@ARGV) >= 2) && (length($ARGV[1]) > 0)) {
	$output_info_file = $ARGV[1];
	}
else {
	# Build the name of the output file.
	@now = localtime( );
	$output_info_file = "/voro/ingest/data/object_list." .
		sprintf("%04d%02d%02d", $now[5] + 1900, $now[4] + 1, $now[3]) .
		".txt";
	undef @now;
	}

if ((scalar(@ARGV) >= 3) && (length($ARGV[2]) > 0)) {
	$object_dir = $ARGV[2];
	}
else {
	$object_dir = "/voro/XTF/data";
	}

if ((scalar(@ARGV) >= 4) && (length($ARGV[3]) > 0)) {
	$new_and_updated_file = $ARGV[3];
	}
else {
	$new_and_updated_file = "/voro/ingest/data/ingest_stats.txt";
	}

if (scalar(@ARGV) > 4) {
	print STDERR "$c:  this script uses only the first 4 command line ",
		"parameter - all beyond that have been ignored\n";
	}

# We don't want the output object list file to be the same as the input
# object list file.
if (defined($input_info_file) && ($input_info_file eq $output_info_file)) {
	die "$c:  both input and output object list files (command line ",
		"parameters 1 and 2) are the same (\"$input_info_file\"), ",
		"stopped";
	}

# Create a parser to use.
$parser = XML::LibXML->new( );

# Read in the info from the last run, if there is on.
%last_runs_info = ( );
if (defined($input_info_file)) {
	open(INPF, "<", $input_info_file) ||
		die "$c:  unable to open \"$input_info_file\" for input, $!, ",
			"stopped";
	$line_no = 0;
	while(<INPF>) {
		chomp;
		$line_no++;

		# Check on the format of the data on the line.
		#	  DIR     TYPE    FILE    SIZE    MTIME   CTIME   MD5SUM            TYPE-SPECIFIC
		unless (/^(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([a-f0-9]{32})\s+"([^"]+)"$/) {
			die "$c:  format of line $line_no in file ",
				"\"$input_info_file\" is invalid, stopped";
			}
		$dir = $1;
		@dir_info = ($2, $3, $4, $5, $6, $7, $8);
		$dir_info[0] = lc($dir_info[0]);
		unless ($dir_info[0] =~ /^(ead|mets)$/) {
			die "$c:  the value in the second column ",
				"(\"$dir_info[1]\") of line $line_no in file ",
				"\"$input_info_file\" is neither \"ead\" nor ",
				"\"mets\", stopped";
			}

		# Make sure this line isn't a duplicate.
		if (exists($last_runs_info{$dir})) {
			die "$c:  the directory in the first column ",
				"(\"$dir\") of line $line_no in file ",
				"\"$input_info_file\" already appeared on a ",
				"previous line in the file, stopped";
			}

		# File away the data.
		$last_runs_info{$dir} = [ @dir_info ];
		}
	close(INPF);
	}

# Open our output info file.
open(OUTF, ">", $output_info_file) ||
	die "$c:  unable to open \"$output_info_file\" for output, $!, stopped";

# Open our output "new and updated" file, but only if we had a "last run".
if (defined($input_info_file)) {
	open(NEWUPD, ">>", $new_and_updated_file) ||
		die "$c:  unable to open \"$new_and_updated_file\" for ",
			"append, $!, stopped";
	}

# Process our directory.
$count_exactly_same = 0;
$count_same_md5sum = 0;
process_dir($object_dir, 1, "");

# If we were writing the "new and updated" file, close it.  Also, print counts.
if (defined($input_info_file)) {
	close(NEWUPD);
	print "$c:  $count_exactly_same objects were exactly the same\n";
	print "$c:  $count_same_md5sum objects had different mtime and/or ",
		"ctime values but had the same md5sum\n";
	}

# Close our output info file.
close(OUTF);

# -----
# Subroutine to process a directory.
sub process_dir {
	my $the_dir = $_[0];
	my $dir_level = $_[1];
	my $sub_dir_name = $_[2];

	# If the directory level is 1, we're processing our main directory.
	# 2 means we're processing an immediate subdirectory of our main
	# directory.  3 means we're processing a subdirectory of that which
	# has a name consisting of two characters.  4 means we're processing
	# a subdirectory the name of which is an ARK number.

	my @dir_contents;
	my $dir_entry;
	my %files;
	my @subdirs;
	my $xml_document;

	# Get the contents of this directory.
	opendir(DIR, $the_dir) ||
		die "$c:  unable to open directory \"$the_dir\", $!, stopped";
	@dir_contents = readdir(DIR);
	closedir(DIR);

	# Sort the directory's contents, so that if a sequence of error
	# messages is printed, we'll have a better idea of who close to
	# being done we are.
	@dir_contents = sort(@dir_contents);

	# Process the contents of the directory.
	@subdirs = ( );
	%files = ( );
	foreach $dir_entry (@dir_contents) {
		# Ignore "." and ".." as a matter of course.
		next if ($dir_entry eq ".");
		next if ($dir_entry eq "..");

		# Warn and ignore if it is a symbolic link.
		if (-l "$the_dir/$dir_entry") {
			print STDERR "$c:  ignoring symbolic link ",
				"\"$the_dir/$dir_entry\"\n";
			next;
			}

		# At levels 1, 2, and 3, we should only see directories.
		# At level 4, either files or directories are allowable.
		if ($dir_level <= 3) {
			unless (-d "$the_dir/$dir_entry") {
				print STDERR "$c:  ignoring \"$the_dir/",
					"$dir_entry\" because it is not a ",
					"directory\n";
				next;
				}
			}
		else {
			unless ((-d "$the_dir/$dir_entry") || (-f _)) {
				print STDERR "$c:  ignoring \"$the_dir/",
					"$dir_entry\" because it is neither a ",
					"directory nor a file\n";
				next;
				}
			}

		# At level 1, we should see only NAANs (i.e., numbers).
		if ($dir_level == 1) {
			unless ($dir_entry =~ /^\d+$/) {
				print STDERR "$c:  ignoring \"$the_dir/",
					"$dir_entry\" because its name should ",
					"be only numeric digits\n";
				next;
				}
			}

		# At level 2, the subdirectory name should be 2 characters.
		if ($dir_level == 2) {
			unless ($dir_entry =~ /^[a-z0-9]{2}$/) {
				print STDERR "$c:  ignoring \"$the_dir/",
					"$dir_entry\" because its name should ",
					"be two characters\n";
				next;
				}
			}

		# At level 3, the subdirectory name should be an ARK number,
		# so its last two characers should match the name of the
		# directory it's in.  And ARK numbers have a certain format.
		if ($dir_level == 3) {
			unless ((length($dir_entry) > 2) &&
				(substr($dir_entry, -2) eq $sub_dir_name)) {
				print STDERR "$c:  ignoring \"$the_dir/",
					"$dir_entry\" because the last two ",
					"characters should match the name ",
					"of the next higher level directory\n";
				next;
				}
			unless ($dir_entry =~ /^[a-z0-9]+$/) {
				print STDERR "$c:  ignoring \"$the_dir/",
					"$dir_entry\" because it does not ",
					"appear to be an ARK number\n";
				next;
				}
			}

		# Save it in either the subdirectory list or the file hash.
		if (-d _) {
			push @subdirs, $dir_entry;
			}
		else {
			$files{$dir_entry} = 1;
			}
		}
	undef @dir_contents;

	# If we're procesing ARK number directories, we don't need to recurse,
	# and we're only interested in the files in this directory.
	if ($dir_level >= 4) {
		# If there is an "ARKNUMBER.xml" file in this directory,
		# examine it.  If it's contents is "<ead>" XML, then this
		# is an EAD file, and is the one to "watch".  The name of
		# the directory we're in is the ARK number in question.
		if (exists($files{"$sub_dir_name.xml"})) {
			eval {
				$xml_document = $parser->parse_file(
					"$the_dir/$sub_dir_name.xml");
				};
			if (length($@) != 0) {
				die "$c:  unable to parse the XML in file ",
					"\"$the_dir/$sub_dir_name.xml\", $@, ",
					"stopped";
				}
			if ($xml_document->documentElement( )->nodeName( ) eq
				"ead") {
				process_file($the_dir, "EAD",
					"$sub_dir_name.xml");
				return;
				}
			undef $xml_document;
			}

		# Either the "ARKNUMBER.xml" file doesn't exist in this
		# directory, or it does not contain "<ead>" XML.  We need
		# to watch the "ARKNUMBER.mets.xml" file.  Make sure it
		# exists, first.
		unless (exists($files{"$sub_dir_name.mets.xml"})) {
			print STDERR "$c:  WARNING:  there is no METS XML ",
				"file in directory \"$the_dir\"\n";
			return;
			}

		# "Watch" the METS XML file.
		process_file($the_dir, "METS", "$sub_dir_name.mets.xml");
		return;
		}

	# Process the subdirectories.
	foreach $dir_entry (@subdirs) {
		process_dir("$the_dir/$dir_entry", $dir_level + 1, $dir_entry);
		}
	}

# -----
# Subroutine to process a file.  If we have data from the last last, this
# involves determining if the file is new or updated.
sub process_file {
	my $the_dir = $_[0];
	my $the_type = $_[1];
	my $the_file = $_[2];

	my $document;
	my $md5_sum;
	my $new_or_updated;
	my @nodes;
	my @run_info;
	my @stat;
	my $type_specific;
	my $yyyymmdd;

	# Get the size, mtime, and ctime for the file.
	@stat = stat("$the_dir/$the_file");
	unless (@stat) {
		die "$c:  the \"stat( )\" function failed on ",
			"\"$the_dir/$the_file\", $!, stopped";
		}

	# If we don't have data from the last run, then the "%last_runs_info"
	# hash will be empty.

	# If the directory existed as of the last run, and its type, file,
	# size, MTIME, and CTIME are the same as the last run's, use the MD5
	# checksum and type-specific data from the last run as this run's,
	# and consider the file neither new nor updated.
	if (exists($last_runs_info{$the_dir})) {
		@run_info = @{$last_runs_info{$the_dir}};
		if (
			# this run's type is the same as the last run's
			(lc($the_type) eq $run_info[0]) &&
			# this run's file is the same as the last run's
			($the_file eq $run_info[1]) &&
			# this run's size is the same as the last run's
			($stat[7] == $run_info[2]) &&
			# this run's mtime is the same as the last run's
			($stat[9] == $run_info[3]) &&
			# this run's ctime is the same as the last run's
			($stat[10] == $run_info[4])) {

			# Use the MD5 checksum and type-specific data from
			# the last run, and consider this file neither new
			# nor updated.
			print OUTF "$the_dir $the_type $the_file $stat[7] ",
				"$stat[9] $stat[10] $run_info[5] ",
				"\"$run_info[6]\"\n";
			$count_exactly_same++;
			return;
			}
		}

	# Calculate the MD5 sum of the contents of the file.
	$md5_sum = Digest::MD5->new( );
	open(FILE, "<", "$the_dir/$the_file") ||
		die "$c:  unable to open file \"$the_dir/$the_file\" for ",
			"input, $!, stopped";
	while(<FILE>) {
		$md5_sum->add($_);
		}
	close(FILE);
	$md5_sum = $md5_sum->hexdigest( );

	# If the directory existed as of the last run, and its type, file,
	# size, and MD5 checksum are the same as the last run's, use the
	# the last run's type-specific data, and consider the file neither
	# new nor updated.
	if (exists($last_runs_info{$the_dir})) {
		# @run_info = @{$last_runs_info{$the_dir}};
		if (
			# this run's type is the same as the last run's
			(lc($the_type) eq $run_info[0]) &&
			# this run's file is the same as the last run's
			($the_file eq $run_info[1]) &&
			# this run's size is the same as the last run's
			($stat[7] == $run_info[2]) &&
			# this run's MD5 checksum is the same as the last run's
			($md5_sum eq $run_info[5])) {

			# Use the type-specific data from the last run, and
			# consider this file neither new nor updated.
			print OUTF "$the_dir $the_type $the_file $stat[7] ",
				"$stat[9] $stat[10] $md5_sum ",
				"\"$run_info[6]\"\n";
			$count_same_md5sum++;
			return;
			}
		}

	# This file is either new or updated, so we'll need the type-specific
	# data.  Parse the file, in order to get it.
	eval {
		$document = $parser->parse_file("$the_dir/$the_file");
		};
	if (length($@) != 0) {
		die "$c:  unable to parse file \"$the_dir/$the_file\", $@, ",
			"stopped";
		}

	# Get the type-specific data.
	if ($the_type eq "EAD") {
		@nodes = $document->findnodes("/*[local-name(.) = 'ead']" .
			"/*[local-name(.) = 'eadheader']" .
			"/*[local-name(.) = 'eadid']" .
			"/\@*[local-name(.) = 'parent']");
		if (scalar(@nodes) == 0) {
			die "$c:  unable to find /ead/eadheader/eadid/",
				"\@parent value in file ",
				"\"$the_dir/$the_file\", stopped";
			}
		if (scalar(@nodes) > 1) {
			die "$c:  found ", scalar(@nodes),
				" /ead/eadheader/eadidets/\@parent values in ",
				"file \"$the_dir/$the_file\", stopped";
			}
		$type_specific = $nodes[0]->getValue( );
		unless (defined($type_specific)) {
			die "$c:  found undefined value for ",
				"/ead/eadheader/eadid/\@parent in file ",
				"\"$the_dir/$the_file\", stopped";
			}
		unless (length($type_specific) > 0) {
			die "$c:  found length zero value for ",
				"/ead/eadheader/eadid/\@parent in file ",
				"\"$the_dir/$the_file\", stopped";
			}
		}
	else {
		@nodes = $document->findnodes("/*[local-name(.) = 'mets']" .
			"/\@*[local-name(.) = 'PROFILE']");
		if (scalar(@nodes) == 0) {
			die "$c:  unable to find /mets/\@PROFILE value in ",
				"file \"$the_dir/$the_file\", stopped";
			}
		if (scalar(@nodes) > 1) {
			die "$c:  found ", scalar(@nodes), " /mets/\@PROFILE ",
				"values in file \"$the_dir/$the_file\", ",
				"stopped";
			}
		$type_specific = $nodes[0]->getValue( );
		unless (defined($type_specific)) {
			die "$c:  found undefined value for /mets/\@PROFILE ",
				"in file \"$the_dir/$the_file\", stopped";
			}
		unless (length($type_specific) > 0) {
			die "$c:  found length zero value for /mets/\@PROFILE ",
				"in file \"$the_dir/$the_file\", stopped";
			}
		}
	undef $document;

	# If info on this directory was not present in the last run, or it
	# was, but the type was different or the file was different, this
	# object is new.
	# "new" indication.
	if ((! exists($last_runs_info{$the_dir})) ||
		(lc($the_type) ne $run_info[0]) ||
		($the_file ne $run_info[1])) {
		$new_or_updated = "new";
		}
	# Info on this directory was present in the last run, and the type
	# is the same as the last run, and the file is the same as the last
	# run.  This object was updated.
	else {
		$new_or_updated = "updated";
		}

	# Write the info for the next run.
	print OUTF "$the_dir $the_type $the_file $stat[7] $stat[9] $stat[10] ",
		"$md5_sum \"$type_specific\"\n";

	# If we had data for the last run, write out whether this object
	# is new or updated.
	if (defined($input_info_file)) {
		# Write the info in the file.
		print NEWUPD "$the_dir $the_type $the_file $new_or_updated ",
			$stat[9], " \"$type_specific\"\n";
		}
	}
