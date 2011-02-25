#!/bin/env perl

# ------------------------------------
#
# Project:	VORO admin data in Django 
#
# Task:		To dump the Django data to create the "repodata" XML files,
#		the VORO users file, the VORO groups file, and an htdigest
#		file.
#
# Name:		dump_django.pl
#
# Command line parameters:
#		1 - required - the name of the directory into which to
#			write the "repodata" XML files
#		2 - required - the name of the file into which to write
#			the VORO users data
#		3 - required - the name of the file into which to write
#			the VORO group data
#		4 - required - the name of the file into which to write
#			the htdigest data
#		5 - optional - the host name of the MySQL server.  if this
#			parameter is omitted or of length zero, use
#			"mysql-dev.cdlib.org".
#		6 - optional - the port number of the MySQL server.  if this
#			parameter is omitted or of length zero, use "3340".
#		7 - optional - the MySQL database.  if this parameter is
#			omitted or of length zero, use "oac4dev".
#		8 - optional - the MySQL user name.  if this parameter is
#			omitted or is of length zero, use "oac4devro".
#		9 - optional - the MySQL password.  if this parameter is
#			omitted or of length zero, use "oac4devro".
#		10 - optional - the location of the "mysql" command binary.
#			if this parameter is omitted or of length zero,
#			use "/dsc/local/bin/mysql";
#
# Note:		I tried to install DBD::mysql, but ran into a lot of trouble,
#		and gave up.
#
# Author:	Michael A. Russell
#
# Revision History:
#		2008/10/7 - MAR - Initial writing
#		2008/10/8 - MAR - Encode "&", "<", and ">" in XML data.
#		2008/10/8 - MAR - Also encode the "<oldurl>" data.
#		2008/10/24 - MAR - Add the creation of an "htdigest" file.
#			Change the way the group file is generated, due to
#			a configuration change of the database.
#
#			I can no longer produce the group file using the
#			institution_id column in the oac_groupprofile table
#			because it no longer exists.  The link between
#			the oac_groupprofile table and the oac_institution
#			table is now through a new table
#			oac_groupprofile_institutions.  That change ended
#			up generating lines in which the first two columns
#			of the output file were the same.  To make the
#			col1/col2 pair unique, combine the col3 values for
#			identical col1/col2 pairs by concatenating them.
#		2008/12/8 - MAR - Look at the value of the "voroead_account"
#			column in the "oac_userprofile" table, before
#			writing out.
#		2008/12/11 - MAR - For the output VORO users data, collapse
#			multiple lines for a given "webDAVuser" into a single
#			line, putting commas between differing values in the
#			other columns.
#		2009/1/13 - Mark Redar - Uses the oca_institution cdlpath
#			value for web dav directories instead of the group
#			profile directory field. The group directory is to
#			be dropped.
#		2009/6/30 - MAR - A contributor added an accute accent an
#			"e" in the institution name, and LibXML objected.
#			Ask "mysql" to return UTF8, since that's what
#			LibXML is expecting.
#		2009/7/6 - MAR - The UTF8 we're getting back from MySQL
#			needs to be written out as UTF8 in the "repo.xml"
#			files.
#
# ------------------------------------

use strict;
use warnings;

# List our variable names.
use vars qw(
	$c
	@children
	@child_text
	$column
	$column_value
	$columns_the_same
	$command
	$command_output
	$db_handle
	$document
	$error_message
	$groups_file
	%group_col1_col2_to_col3
	$htdigest_file
	$htdigest_password
	$i
	$j
	$mysql_command
	@nodes
	@old_urls
	$output_repodata_file
	$parser
	$pos
	$rc
	$repodata_dir
	$sql_command
	$sql_database
	$sql_host
	$sql_password
	$sql_port
	$sql_user
	$user
	%users
	$users_file
	$work
	);

# Pull in code we'll need.
use XML::LibXML;
use File::Path;

# Get command name for error messages.
$pos = rindex($0, "/");
$c = ($pos > 0) ? substr($0, $pos + 1) : $0;
undef $pos;

# Examine command line parameters.
if (scalar(@ARGV) < 4) {
	die "$c:  this command requires at least four parameters, stopped";
	}
$repodata_dir = $ARGV[0];
$users_file = $ARGV[1];
$groups_file = $ARGV[2];
$htdigest_file = $ARGV[3];
if ((scalar(@ARGV) >= 5) && (length($ARGV[4]) > 0)) {
	$sql_host = $ARGV[4];
	}
else {
	$sql_host = "mysql-dev.cdlib.org";
	}
if ((scalar(@ARGV) >= 6) && (length($ARGV[5]) > 0)) {
	$sql_port = $ARGV[5];
	}
else {
	$sql_port = "3340";
	}
if ((scalar(@ARGV) >= 7) && (length($ARGV[6]) > 0)) {
	$sql_database = $ARGV[6];
	}
else {
	$sql_database = "oac4dev";
	}
if ((scalar(@ARGV) >= 8) && (length($ARGV[7]) > 0)) {
	$sql_user = $ARGV[7];
	}
else {
	$sql_user = "oac4devro";
	}
if ((scalar(@ARGV) >= 9) && (length($ARGV[8]) > 0)) {
	$sql_password = $ARGV[8];
	}
else {
	$sql_password = "oac4devro";
	}
if ((scalar(@ARGV) >= 10) && (length($ARGV[9]) > 0)) {
	$mysql_command = $ARGV[9];
	}
else {
	$mysql_command = "/dsc/local/bin/mysql";
	}
if (scalar(@ARGV) > 10) {
	print STDERR "$c:  this command uses only the first 10 command line ",
		"parameters - all beyond that have been ignored\n";
	}

unless (-e $repodata_dir) {
	die "$c:  directory \"$repodata_dir\" does not exist, stopped";
	}
unless (-d _) {
	die "$c:  \"$repodata_dir\" is not a directory, stopped";
	}

unless (-x $mysql_command) {
	die "$c:  \"$mysql_command\" is not executable, stopped";
	}

# Create an XML parser.
$parser = XML::LibXML->new( );

# Construct the SQL that we'll need to get the user data.
$sql_command = "select a.username, c.name, a.first_name, a.last_name, " .
	"a.email, d.phone from auth_user a, auth_user_groups b, " .
	"auth_group c, oac_userprofile d where a.id=b.user_id and " .
	"b.group_id=c.id and a.id=d.user_id and d.voroead_account != 0";

# Construct the command.
$command = "$mysql_command --host=$sql_host --port=$sql_port " .
	"--user=$sql_user --password=$sql_password --database=$sql_database " .
	"--batch --xml --default-character-set=utf8 \"--execute=$sql_command\"";

# Run the command and retrieve the results.
$command_output = `$command`;
$rc = $? >> 8;
unless ($rc == 0) {
	die "$c:  command \"$command\" terminated with exit code $rc, stopped";
	}

# It should be XML.  Parse it.
eval {
	$document = $parser->parse_string($command_output);
	};
if (length($@) != 0) {
	die "$c:  unable to parse the output of command \"$command\", ",
		"$@, stopped";
	}
undef $command_output;

# Process the data into the "%users" hash (in order to collapse all lines
# for a given "webDAVuser" into a single line).  Start by getting the
# list of rows.
@nodes = $document->findnodes("/resultset/row");

# Process each row.
%users = ( );
foreach (@nodes) {
	# Get the "<field>" nodes in this row.
	@children = $_->findnodes("field");

	# Convert the array contents from a node to the text content.
	foreach (@children) {
		$_ = $_->textContent( );
		unless (defined($_)) {
			$_ = "";
			}
		}

	# If this "webDAVuser" is not already in the hash, add it, and go on.
	if (! exists($users{$children[0]})) {
		$users{$children[0]} = {
			"webDAVgroup" =>  [ $children[1] ],
			"contactName" =>  [ $children[2] . " " . $children[3] ],
			"contactEMail" => [ $children[4] ],
			"contactPhone" => [ $children[5] ]
			};
		next;
		}

	# This "webDAVuser" has appeared before.  Store this line's
	# data next to the data of the previous line(s).
	push @{$users{$children[0]}{"webDAVgroup"}}, $children[1];
	push @{$users{$children[0]}{"contactName"}},
		$children[2] . " " . $children[3];
	push @{$users{$children[0]}{"contactEMail"}}, $children[4];
	push @{$users{$children[0]}{"contactPhone"}}, $children[5];
	}
undef @children;
undef @nodes;

# Collapse the data for each user.  For each of the other 4 columns, look
# at the values we have collected.  If they are all the same, then just
# use the single value for the user.  If there are different ones, then
# combine them.  (Change the values of the hash from hashes to scalars.)
foreach $user (keys %users) {
	foreach $column ("contactName", "contactEMail", "contactPhone",
		# (Process "webDAVgroup" last, because its value may
		# be necessary when processing the other columns.
		"webDAVgroup") {
		# (Make a short name for the reference to the array.)
		$work = $users{$user}{$column};

		# If there's only one entry in the array, there is
		# no work to do.  Just put the scalar back as the
		# value of the hash.
		if (scalar(@$work) == 1) {
			$users{$user}{$column} = $$work[0];
			next;
			}

		# If this is the "webDAVgroup", then just combine the
		# values with commas in between them.
		if ($column eq "webDAVgroup") {
			$users{$user}{$column} = join(",", @$work);
			next;
			}

		# We have more than one value.  Compare them.  If they
		# are all the same, just use that value.
		$column_value = $$work[0];
		$columns_the_same = 1;
		for ($i = 1; $i < scalar(@$work); $i++) {
			# If they are the same, then keep looking.
			next if ($column_value eq $$work[$i]);

			# If they aren't the same, if one of them is the
			# null string, take whichever isn't the null
			# string as the column's value, and keep looking.
			if ($column_value eq "") {
				$column_value = $$work[$i];
				next;
				}
			if ($$work[$i] eq "") {
				next;
				}

			# They are really different.  Say so.
			$columns_the_same = 0;
			last;
			}

		# If all the columns were the same, then just use that
		# as the value.
		if ($columns_the_same) {
			$users{$user}{$column} = $column_value;
			next;
			}

		# Build a composite value for this column.
		$column_value = "";
		for ($i = 0; $i < scalar(@$work); $i++) {
			if ($$work[$i] ne "") {
				if ($column_value eq "") {
					$column_value = $$work[$i] . "(group " .
						$users{$user}{"webDAVgroup"}[$i]
						. ")";
					}
				else {
					$column_value .= "," . $$work[$i] .
						"(group " .
						$users{$user}{"webDAVgroup"}[$i]
						. ")";
					}
				}
			}

		# Save the column's new value.
		$users{$user}{$column} = $column_value;
		}
	}

# The data from multiple lines has been collapsed into one.  Write out the
# data now.  Open the output file.
open(USERS, ">", $users_file) ||
	die "$c:  unable to open \"$users_file\" for output, $!, stopped";

# Write the heading line.
print USERS ".webDAVuser\twebDAVgroup\tPrimary Contact Name\t",
	"Primary Contact Email\tPrimary Contact Phone\n";

# Might as well write them out in sorted order.
foreach $user (sort keys %users) {
	print USERS $user, "\t", $users{$user}{"webDAVgroup"}, "\t",
		$users{$user}{"contactName"}, "\t",
		$users{$user}{"contactEMail"}, "\t",
		$users{$user}{"contactPhone"}, "\n";
	}

# Close the file.
close(USERS);

# Free up stuff.
undef @children;
undef @nodes;
undef $document;

# Construct the SQL that we'll use to get the group data.
#$sql_command = "select c.name, e.directory, f.name from auth_group c, " .
#	"oac_groupprofile e, oac_institution f where c.id=e.group_id and " .
#	"e.institution_id=f.id";
$sql_command = "select c.name, f.cdlpath, f.name from auth_group c, " .
	"oac_groupprofile e, oac_institution f, " .
	"oac_groupprofile_institutions g where " .
	"c.id=e.group_id and " .
	"e.id=g.groupprofile_id and " .
	"g.institution_id=f.id";

# Construct the command.
$command = "$mysql_command --host=$sql_host --port=$sql_port " .
	"--user=$sql_user --password=$sql_password --database=$sql_database " .
	"--batch --xml --default-character-set=utf8 \"--execute=$sql_command\"";

# Run the command and retrieve the results.
$command_output = `$command`;
$rc = $? >> 8;
unless ($rc == 0) {
	die "$c:  command \"$command\" terminated with exit code $rc, stopped";
	}

# It should be XML.  Parse it.
eval {
	$document = $parser->parse_string($command_output);
	};
if (length($@) != 0) {
	die "$c:  unable to parse the output of command \"$command\", ",
		"$@, stopped";
	}
undef $command_output;

# The column 1/column 2 pair should be unique in the output file.  The
# results of the query are going to give multiple rows where the
# column 1/column 2 pair are the same.  Combine the values of column 3
# for such lines.
@nodes = $document->findnodes("/resultset/row");
%group_col1_col2_to_col3 = ( );
for ($i = 0; $i < scalar(@nodes); $i++) {
	@children = $nodes[$i]->childNodes( );

	# Identify the child nodes which are XML_ELEMENT_NODEs.
	@child_text = ( );
	for ($j = 0; $j < scalar(@children); $j++ ) {
		next unless ($children[$j]->nodeType( ) == XML_ELEMENT_NODE);
		push @child_text, $children[$j]->textContent( );
		}

	# Make sure we got three.
	unless (scalar(@child_text) == 3) {
		die "$c:  did not find 3 XML_ELEMENT_NODE children of ",
			"\"<row>\" number ", ($i + 1), " in the XML results ",
			"to the SQL query \"$sql_command\", found ",
			scalar(@child_text), " child XML_ELEMENT_NODE(s), ",
			"stopped";
		}

	# The pair of values in columns 1 and 2 should be unique.
	if (exists($group_col1_col2_to_col3{$child_text[0] . "\t" .
		$child_text[1]})) {
		# We already encountered this pair.  Append this one's
		# column 3 value to what we have already.
		$group_col1_col2_to_col3{$child_text[0] . "\t" .
			$child_text[1]} .= ", " . $child_text[2];
		}
	else {
		# We haven't seen this pair yet.  Create a new hash entry.
		$group_col1_col2_to_col3{$child_text[0] . "\t" .
			$child_text[1]} = $child_text[2];
		}
	}
undef @nodes;
undef @children;
undef @child_text;

# Write out the contents of our hash.
open(GROUPS, ">", $groups_file) ||
	die "$c:  unable to open \"$groups_file\" for output, $!, stopped";
print GROUPS "#webDAV group\tDynaweb directory\tMain Institution\n";
foreach (sort keys %group_col1_col2_to_col3) {
	print GROUPS "$_\t", $group_col1_col2_to_col3{$_}, "\n";
	}
undef %group_col1_col2_to_col3;
close(GROUPS);

# Construct the SQL that we'll use to retrieve all "<oldurl>" data.
$sql_command = "select institution_id, url from oac_institutionurl";

# Construct the command.
$command = "$mysql_command --host=$sql_host --port=$sql_port " .
	"--user=$sql_user --password=$sql_password --database=$sql_database " .
	"--batch --xml --default-character-set=utf8 \"--execute=$sql_command\"";

# Run the command and retrieve the results.
$command_output = `$command`;
$rc = $? >> 8;
unless ($rc == 0) {
	die "$c:  command \"$command\" terminated with exit code $rc, stopped";
	}

# It should be XML.  Parse it.
eval {
	$document = $parser->parse_string($command_output);
	};
if (length($@) != 0) {
	die "$c:  unable to parse the output of command \"$command\", ",
		"$@, stopped";
	}
undef $command_output;

# File the information away in an array.
@nodes = $document->findnodes("/resultset/row");
@old_urls = ( );
foreach (@nodes) {
	@children = $_->findnodes("field");
	$children[1] = $children[1]->textContent( );
	$children[1] =~ s/&/&amp;/g;
	$children[1] =~ s/</&lt;/g;
	$children[1] =~ s/>/&gt;/g;
	push @old_urls, $children[0]->textContent( ), $children[1];
	}
undef @children;
undef @nodes;
undef $document;

# Construct the SQL to get the repodata info.
$sql_command = "select ark, parent_ark, name, mainagency, cdlpath, url, " .
	"region, id from oac_institution";

# Construct the command.
$command = "$mysql_command --host=$sql_host --port=$sql_port " .
	"--user=$sql_user --password=$sql_password --database=$sql_database " .
	"--batch --xml --default-character-set=utf8 \"--execute=$sql_command\"";

# Run the command and retrieve the results.
$command_output = `$command`;
$rc = $? >> 8;
unless ($rc == 0) {
	die "$c:  command \"$command\" terminated with exit code $rc, stopped";
	}

# It should be XML.  Parse it.
eval {
	$document = $parser->parse_string($command_output);
	};
if (length($@) != 0) {
	die "$c:  unable to parse the output of command \"$command\", ",
		"$@, stopped";
	}
undef $command_output;

# File the information away in an array.
@nodes = $document->findnodes("/resultset/row");
foreach (@nodes) {
	@children = $_->findnodes("field");
	foreach (@children) {
		$_ = $_->textContent( );
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		}

	# children[0] is ark
	# children[1] is parent_ark
	# children[2] is name
	# children[3] is mainagency
	# children[4] is cdlpath
	# children[5] is url
	# children[6] is region
	# children[7] is id

	# cdlpath tells us where this one will go.
	if ($children[4] =~ /^\@\@\@\@\@(.+)$/) {
		$output_repodata_file = $repodata_dir . "/" . $1;
		}
	else {
		$output_repodata_file = $repodata_dir . "/" . $children[4] .
			"/repo.xml";
		}

	# Make any directories necessary.
	$output_repodata_file =~ m|^(.+)/[^/]+$|;
	mkpath($1, 0, 0755);

	# Open the output file.
	open(REPODATA, ">:utf8", $output_repodata_file) ||
		die "$c:  unable to open \"$output_repodata_file\" for ",
			"output, $!, stopped";

	# Write out what we got.
	print REPODATA "<repository poi=\"$children[0]\">\n";
	print REPODATA "  <label>$children[2]</label>\n";
	if (length($children[1]) > 0) {
		print REPODATA "  <parent poi=\"$children[1]\"/>\n";
		}
	print REPODATA "  <region>$children[6]</region>\n";
	if ($children[4] !~ /^\@\@\@\@\@/) {
		print REPODATA "  <CDLPATH>$children[4]</CDLPATH>\n";
		}
	print REPODATA "  <url>$children[5]</url>\n";
	if (length($children[3]) > 0) {
		print REPODATA "  <mainagency>$children[3]</mainagency>\n";
		}

	# Put out any old URLs.
	for ($i = 0; $i < scalar(@old_urls); $i += 2) {
		if ($old_urls[$i] eq $children[7]) {
			print REPODATA "  <oldurl>$old_urls[$i + 1]</oldurl>\n";
			}
		}

	print REPODATA "</repository>\n";
	close(REPODATA);
	}
undef @nodes;
undef @children;
undef @old_urls;
undef $document;
undef @old_urls;

# Construct the SQL to get the htdigest info.
$sql_command = "select password from auth_user;";

# Construct the command.
$command = "$mysql_command --host=$sql_host --port=$sql_port " .
	"--user=$sql_user --password=$sql_password --database=$sql_database " .
	"--batch --xml --default-character-set=utf8 \"--execute=$sql_command\"";

# Run the command and retrieve the results.
$command_output = `$command`;
$rc = $? >> 8;
unless ($rc == 0) {
	die "$c:  command \"$command\" terminated with exit code $rc, stopped";
	}

# It should be XML.  Parse it.
eval {
	$document = $parser->parse_string($command_output);
	};
if (length($@) != 0) {
	die "$c:  unable to parse the output of command \"$command\", ",
		"$@, stopped";
	}
undef $command_output;

# Get all the results fields.
@nodes = $document->findnodes("/resultset/row/field");

# Open the output file.
open(HTDIG, ">", $htdigest_file) ||
	die "$c:  unable to open \"$htdigest_file\" for output, $!, stopped";
for ($i = 0; $i < scalar(@nodes); $i++) {
	# Pull out the text content of this element.
	$htdigest_password = $nodes[$i]->textContent( );

	# Some of them are null.  Ignore those.
	next if ($htdigest_password =~ /^\s*$/);

	# Split the value on dollar signs.
	@child_text = split(/\$/, $htdigest_password);
	unless (scalar(@child_text) == 3) {
		die "$c:  did not find three \"\$\"-separated values in the ",
			"field in row number ", ($i + 1), " in the XML ",
			"results to the SQL query \"$sql_command\", found ",
                        scalar(@child_text), " value(s), stopped";
                }

	# Ignore the line unless the first one is "md5".
	next unless ($child_text[0] eq "md5");

	# Write out the second two values, concatenated.
	print HTDIG $child_text[1], $child_text[2], "\n";
	}
close(HTDIG);
