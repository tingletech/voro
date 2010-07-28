#!/bin/env perl
# 
# Take finished pdf directories and package them for voro.cdlib.org
$| = 0;

#use strict;
use Data::Dumper;
use File::Path;

use XML::LibXML;
use XML::LibXSLT;

$eadroot = $ENV{OACDATA} || "/voro/data/oac-ead";
$dynaroot = $ENV{DYNROOT} || "/voro/XTF/data";

sub poi2pdf {
	#print Dumper @_;
        my $poi = shift;
        $poi =~ s,[.|/],,g;
        my $dir = substr($poi, -2);
        $poi =~ s|ark:13030(.*)|$dynaroot/13030/$dir/$1/files/$1.pdf|;
	my $part = $1;
                if (! -e "$dynaroot/13030/$dir/$part/files" ) {
                        mkpath("$dynaroot/13030/$dir/$part/files");
                }
        return "$poi";
}


use Getopt::Long;
$ret = GetOptions qw(--onefile+);


#$ENV{OACDATA} = "/voro/data/oac-ead";
# use OacBatch;

$| = "1";


local $parser = XML::LibXML->new() || die ("$0: could not make new parser");


if ($opt_onefile) {

	do_it(@ARGV);

} else {


opendir (BASE, "$eadroot/prime2002") || die ("$! $_ $eadroot/prime2002");

#while ( my $subdir = readdir(BASE)) {
while ( my $subdir = readdir(BASE)) {
	next if ($subdir eq "." || $subdir eq ".." || $subdir eq "CVS");
	#print "subdir $subdir\n";
	opendir(SUB, "$eadroot/prime2002/$subdir") || die ("$eadroot/prime2002/$subdir $! $_");
	while (my $repdir = readdir(SUB)) {
		next if ($repdir eq "." || $repdir eq ".." || $repdir eq "CVS");
		#print "$repdir\n";
		if ($repdir =~ m,\.xml$,){
			do_it("$eadroot/prime2002/$subdir/$repdir");
		} else {
			opendir(REP, "$eadroot/prime2002/$subdir/$repdir") || die ("$eadroot/prime2002/$subdir/$repdir $! $_");
			while (my $file = readdir(REP)) {
				do_it("$eadroot/prime2002/$subdir/$repdir/$file") if ($file =~ m,\.xml$,);
			}
		}
	}
}

}

exit;

sub do_it {
	my ($match) = @_;
	
	# the ead xml file in prime2002
	my $xml = $match;

	# the path to the PDF file
	$match =~ s,/prime2002/,/pdf/,;
	$match =~ s,\.xml$,.pdf,;

	# if the PDF has been created
	if (-e $match and -s $match) {

		# look up ARK in EAD
		my $ark = geteadid($xml);
		# side effect of poi2pdf, mkdirs the directory for the pdf
		my $pdf_dest = poi2pdf($ark);

		# copy PDF file from /voro/data/oac-ead/pdf/ to /voro/XTF/
		# copy PDF from OACDATA to DYNAXML
		my $cmd = "/usr/bin/cp -p $match $pdf_dest";
		#print "$cmd\n";
		#print `$cmd`;
		system($cmd);
	}
}

sub geteadid {
        my ($file) = @_;
        if (-e $file) {
                my @return;
                my $doc;
                if (!($doc = $parser->parse_file($file) ) ) {
                        print STDERR "$0: LibXML parse_file($file) failed";
                        return 0;
                }
                my $root = $doc->getDocumentElement;
                ($eadid) = $doc->findnodes('/ead/eadheader/eadid/@identifier');
                return $eadid->textContent();
        } else {
                return 0;
        }
}


exit;
