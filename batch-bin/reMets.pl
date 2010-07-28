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

# sub titleNormal {    for NTITLE 
# sub infile2cdlprime  figures out the path to the cdlprime file
# sub infile2repo {    figures out the path to the repository metadata file
# sub poi2file {       figures out the path to the METS from the ARK
# sub spitMets {       makes METS for all the sub objects in the EAD


$| = 1;

my $debug="1";
my $eadroot = "$ENV{OACDATA}";
my $allroot = "$ENV{ALLDATA}" || "/voro/data/oac-ead";
        

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


sub titleNormal {
	my ($title) = @_;
	$title = uc $title;
	$title =~ s,\W, ,g;
	$title =~ s,\s+, ,g;
	#print $title;
	return $title;
}

sub infile2cdlprime {
	my ($file) = (@_);
	$file =~ s/.sgm$/.xml/;
    $file =~ m,/([^/]*)/([^/]*).xml,;
        # if $1 eq $2 then its a composite file
        if ( ($1 && $2) && ($1 eq $2) && ( $1 ne 'bancroft' ) ) {
                $file =~ s,$1/,,;
        }
    return $eadroot . "/prime2002/" . $file;
}

sub infile2repo {
	my ($file) = (@_);
	$file =~ s/.sgm$/.xml/;
    $file =~ m,/([^/]*)/([^/]*).xml,;
        # if $1 eq $2 then its a composite file
        if ( ($1 && $2) && ($1 eq $2) && ( $1 ne 'bancroft' ) ) {
                $file =~ s,$1/,,;
        }
	$file =~ s,/[^/]*.xml,/repo.xml,;
    return $eadroot . "/repodata/" . $file;
}

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

    # meh, should remove this first cdlprime2objs transform but it is still using this to 
    # to get the EAD's ARK and I'm working on another issue right now
    #
    my $transform = $parser->parse_file("/voro/code/htdocs/xslt/cdlprime2objs.xsl");
    my $stylesheet = $xslt->parse_stylesheet($transform)|| die ("$0 $!");;

    my $results = $stylesheet->transform($doc);

    # need to get the file name of the orignial prime 2002 file into the METS file
    # in order to find the correct path to the PDF file.
    my $transform2 = $parser->parse_file("/voro/code/htdocs/xslt/cdlprime2mets.xsl");
    my $stylesheet2 = $xslt->parse_stylesheet($transform2)|| die ("$0 $!");

    my $results2 = $stylesheet2->transform($doc, 'cdlpath', "'" . cdlprime2cdlpath($cdlprime) . "'");


	my $root = $results->getDocumentElement;


	my ($super) = $root->findnodes('/eadobjs/super');
        my $superID = $root->findvalue('/eadobjs/super/@poi');
        my ($xout1, $xout2) = poi2file($superID);
        print " $superID -- $xout1 $xout2\n\n";
	my $fileOut =  $results2->toString();
        #open (OUT1 ,">$xout1.mets.xml") || die("$0 $! $_: can't open $xout1.mets.xml");
        #print OUT1 $fileOut; 
        #close OUT1;

		# if $xout2.mets.xml is older than $cdlprime

		my $cdlprimeStat = stat("$cdlprime");
		my $metsStat = stat("$xout2.mets.xml");

		if ( ( (@ARGV) || !( -e "$xout2.mets.xml")) || ( $cdlprimeStat->mtime > $metsStat->mtime) ) {
        	open (OUT2 ,">$xout2.mets.xml") || die("$0 $! $_: can't open $xout2.mets.xml");
        	print OUT2 $fileOut;
        	close OUT2;
		}

	$doc->toFile("$xout2.xml");
	undef $doc;


}
