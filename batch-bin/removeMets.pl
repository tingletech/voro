use strict;
use XML::LibXML;
use XML::LibXSLT;
use Data::Dumper;
use LWP::UserAgent;
use Archive::Tar;
use Compress::Zlib;
use File::Path;

use Carp;

# sub poi2file {       figures out the path to the METS from the ARK
# sub spitMets {       makes METS for all the sub objects in the EAD
# sub premetsToMets {  does an XML tranformation needed by spitMets


$| = 1;

my $debug="1";
my $eadroot = "$ENV{OACDATA}" || "$ENV{HOME}/data/in/oac-ead";
my $allroot = "$ENV{ALLDATA}" || "$ENV{HOME}/data/xtf";

opendir (BASE, "$eadroot/remove") || die ("$! $_ $eadroot/remove");


        my $parser = XML::LibXML->new();
        $parser->recover(1);
        my $xslt = XML::LibXSLT->new();

while ( my $subdir = readdir(BASE)) {
        next if ($subdir eq "." || $subdir eq ".." || $subdir eq "CVS");
        #print "subdir $subdir\n";
        opendir(SUB, "$eadroot/remove/$subdir") || warn ("$eadroot/remove/$subdir $! $_");
        while (my $repdir = readdir(SUB)) {
                next if ($repdir eq "." || $repdir eq ".." || $repdir eq "CVS");
                #print "$repdir\n";
                if ($repdir =~ m,\.xml$,){
                        spitMets("$eadroot/remove/$subdir/$repdir");
                } elsif ( -d $repdir ) {
                        opendir(REP, "$eadroot/remove/$subdir/$repdir") || warn ("$eadroot/remove/$subdir/$repdir $! $_");
                        while (my $file = readdir(REP)) {
                                spitMets("$eadroot/remove/$subdir/$repdir/$file") if ($file =~ m,\.xml$,)
;
                        }
                }
        }
}


exit;

##

sub poi2file {
        my $poi = shift;
        $poi =~ s,[.|/],,g;
        my $dir = substr($poi, -2);
        $poi =~ s|ark:13030|$allroot/mets/$dir/|;
		if (! -e "$eadroot/mets/$dir" ) {
			mkpath("$allroot/mets/$dir");
		}
        return "$poi";
}


sub spitMets {
# working on this
	#print Dumper @_; exit;
	my ($cdlprime) = @_;
	
 	my $doc = $parser->parse_file($cdlprime);
	#my $xslt = XML::LibXSLT->new();
    my $transform = $parser->parse_file("$ENV{VOROBASE}/xslt/cdlprime2objs.xsl");
    my $stylesheet = $xslt->parse_stylesheet($transform)|| die ("$0 $!");;
	
    my $results = $stylesheet->transform($doc);



	#print $results->toString;

	my $root = $results->getDocumentElement;

#print "what?"; exit;

	my ($super) = $root->findnodes('/eadobjs/super');
        my $superID = $root->findvalue('/eadobjs/super/@poi');
        my $xout = poi2file($superID);
        # print " $superID -- $xout";
        open (OUT ,">$xout.mets.xml") || die("$0 $! $_: can't open $xout.mets.xml");
        # print $super->toString;
		print OUT premetsToMets($super);
        close OUT;

	
        foreach my $node ($root->findnodes('/eadobjs/sub/c') ) {
		
                my $poi = $node->findvalue('@poi');
                unless ($poi =~ m,ark:/,) { print STDERR "$0: skipping $poi in $cdlprime; not an ARK\n"; next; }
                my $xout = poi2file($poi);
                if ($xout eq "") { print STDERR "$0: skipping null poi in $cdlprime\n"; next; }
                $node->setAttribute('parent', $superID);
                open (OUT ,">$xout.mets.xml") || die ("$0 $! $_ $xout.mets.xml");
                print OUT premetsToMets($node);
                close OUT;

        }
	undef $doc;


}

sub premetsToMets {
	#print "premetsToMets";
	my ($cdlprime) = @_;
	#print Dumper $cdlprime;
 	my $doc = $parser->parse_string($cdlprime->toString);
	#my $xslt = XML::LibXSLT->new();
	# add paramater to trigger the removed behaviour
    my $transform = $parser->parse_file("$ENV{VOROBASE}/xslt/premets2mets.xsl");
    my $stylesheet = $xslt->parse_stylesheet($transform)|| die ("$0 $!");;
    my %bs = ( "noindex", "'true'");
    my $results = $stylesheet->transform($doc, %bs);
	#print $results->toString;
	#print "premetsToMets";
	return $results->toString;
}

