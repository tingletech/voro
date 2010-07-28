use strict;
use XML::LibXML;
use XML::LibXSLT;
use Data::Dumper;
use LWP::UserAgent;
use Archive::Tar;
use Compress::Zlib;
use File::Path;
use File::stat;

use Carp;

# sub poi2file {       figures out the path to the METS from the ARK
# sub cdlprime2cdlpath {
# sub spitMets {       makes METS for all the sub objects in the EAD


$| = 1;

my $debug="1";
my $eadroot = "$ENV{OACDATA}";
my $allroot = "$ENV{ALLDATA}" || "$ENV{HOME}/data/in/oac-ead";
        

my $parser = XML::LibXML->new();
$parser->recover(1);
my $xslt = XML::LibXSLT->new();

if (@ARGV) {
	for (@ARGV) {
		spitMets($_);
	}
} else {

opendir (BASE, "$eadroot/prime2002") || die ("$! $_ $ENV{OACDATA}/prime2002");

while ( my $subdir = readdir(BASE)) {
        next if ($subdir eq "." || $subdir eq ".." || $subdir eq "CVS");
        #print "subdir $subdir\n";
        opendir(SUB, "$ENV{OACDATA}/prime2002/$subdir") || die ("$ENV{OACDATA}/prime2002/$subdir $! $_");
        while (my $repdir = readdir(SUB)) {
                next if ($repdir eq "." || $repdir eq ".." || $repdir eq "CVS");
                #print "$repdir\n";
                if ($repdir =~ m,\.xml$,){
                        spitMets("$ENV{OACDATA}/prime2002/$subdir/$repdir");
                } else {
                        opendir(REP, "$ENV{OACDATA}/prime2002/$subdir/$repdir") || die ("$ENV{OACDATA}/cdlprim
e/$subdir/$repdir $! $_");
                        while (my $file = readdir(REP)) {
                                spitMets("$ENV{OACDATA}/prime2002/$subdir/$repdir/$file") if ($file =~ m,\.xml$,)
;
                        }
                }
        }
}



}

exit;

##

sub poi2file {
        #print Dumper @_;
        my $poi = shift;
        $poi =~ s,[.|/],,g;
        my $dir = substr($poi, -2);
        $poi =~ s|ark:(\d\d\d\d\d)(.*)|$allroot/data/$1/$dir/$2/$2|;
        my $part = $2;
                if (! -e "$allroot/data/$1/$dir/$part" ) {
                        mkpath("$allroot/data/$1/$dir/$part");
                        mkpath("$allroot/data/$1/$dir/$part/files");
                }
        my @out = ('', $poi);
	return @out;
}

sub cdlprime2cdlpath {
	my $in = shift;
	$in =~ s,^.*/prime2002/(.*)\.xml$,$1,;
	return $in;
}

sub spitMets {
	#print Dumper @_; exit;
	my ($cdlprime) = @_;
	
 	my $doc = $parser->parse_file($cdlprime);
	#my $xslt = XML::LibXSLT->new();

	# need to get the file name of the orignial prime 2002 file into the METS file
	# in order to find the correct path to the PDF file.
	my $transform2 = $parser->parse_file("$ENV{VOROBASE}/xslt/cdlprime2mets.xsl");
	my $stylesheet2 = $xslt->parse_stylesheet($transform2)|| die ("$0 $!");
	
	my $results2 = $stylesheet2->transform($doc, 'cdlpath', "'" . cdlprime2cdlpath($cdlprime) . "'");


	my $root = $results2->getDocumentElement;


        my $superID = $root->findvalue('/*[local-name()="mets"]/@OBJID');
        my ($xout1, $xout2) = poi2file($superID);
        #print " $superID -- $xout1 $xout2\n\n";
	my $fileOut =  $results2->toString();

	my $cdlprimeStat = stat("$cdlprime");
	my $metsStat = stat("$xout2.mets.xml");

	#write out the METS file
	if ( ( (@ARGV) || !( -e "$xout2.mets.xml")) || ( $cdlprimeStat->mtime > $metsStat->mtime) ) {
        	open (OUT2 ,">$xout2.mets.xml") || die("$0 $! $_: can't open $xout2.mets.xml");
        	print OUT2 $fileOut;
        	close OUT2;
	}

	# write out the EAD file to the XTF directory
	$doc->toFile("$xout2.xml");
	undef $doc;

}
