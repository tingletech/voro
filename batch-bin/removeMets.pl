use strict;
use XML::LibXML;
use XML::LibXSLT;
use Data::Dumper;
use LWP::UserAgent;
use Archive::Tar;
use Compress::Zlib;
use File::Path;

use Carp;

# sub getVals {        goes through an XML::LibXML::NodeList and returns a array of values
# sub stringMe {       goes through an XML::LibXML::NodeList and ->toString's each node
# sub mintbatch {      returns a array of new arks
# sub lwpMint {        uses LWP::UserAgent to fetch one ark
# sub readNew {        parse with sx and transform the submission to XML
# sub getPrimeInfo {   get ark's etc from the last version of the file
# sub titleNormal {    for NTITLE -- do we need this still?
# sub infile2cdlprime  figures out the path to the cdlprime file
# sub infile2repo {    figures out the path to the repository metadata file
# sub poi2file {       figures out the path to the METS from the ARK
# sub spitMets {       makes METS for all the sub objects in the EAD
# sub premetsToMets {  does an XML tranformation needed by spitMets
# sub cdlToCdlprime {  writes out the new cdlprime file


$| = 1;

my $debug="1";
my $eadroot = "$ENV{OACDATA}" || "/voro/data/oac-ead";

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


#print "just ";
#spitMets($cdlprime);

#chdir($eadroot);
#print "making tar";
#system("/voro/local/bin/gtar zcf mets-ead.tgz mets");

exit;

##

sub getVals {
	#print Dumper @_; exit;
	my ($in) = @_;
	my @out;
	for (@{$in}) {
		push @out, $_->findvalue('.');
		#push @out, $_->findvalue('@poi');
		# print $_->findvalue('@poi');
	}
	return @out;
}

sub mintbatch {
        my ($size) = @_;
        my @return;
        for (my $i = 0; $i < $size; $i++) {
                my $string = lwpMint();
                #push @return, "ark:/$string" ."a";
                push @return, "ark:/$string";
        }
        return @return;
}

sub lwpMint {
      my $ua = LWP::UserAgent->new;
      my $req = HTTP::Request->new(GET => 'http://ark.cdlib.org/cgi/poi/kt7.cgi?mint(1)');
      #my $req = HTTP::Request->new(GET => 'http://ark.cdlib.org/cgi/poi/kt7.cgi?play(1)');
      $req->authorization_basic('tingle', $ARGV[1] );
         my $request = $ua->request($req);
        die unless ($request->code == "200");
      my $newpoi = $request->content;
      $newpoi =~ s,\n,,;
        #$newpoi = "ark:/$newpoi";
       return $newpoi;
}



sub readNew {
	my ($file) = (@_);
	my $xml;
	my $was;
	die ("$0: $eadroot/sgml/$file not found") if (!(-e "$eadroot/sgml/$file"));
	if ($file =~ m/.sgm$/){
		#print STDERR "/sx.sh $eadroot/sgml/$file\n";
		$xml = `/voro/code/batch-bin/sx.sh $eadroot/sgml/$file`;
		$was = "sgm";
	} elsif ($file =~ m/.xml$/){
		$xml = `/voro/code/batch-bin/sxxml.sh $eadroot/sgml/$file`;
		$was = "xml";
	} else {
		die ("$1: $file must be .xml of .sgm");
	}
	#print $xml;
	my $doc = $parser->parse_string($xml) || die ("$0 $!");
	my $root = $doc->getDocumentElement;
	
	#my $xslt = XML::LibXSLT->new();

	my $transform = $parser->parse_file("/voro/code/htdocs/xslt/ead2cdl.xsl");

	## add parameter for CDLPATH
	my $stylesheet = $xslt->parse_stylesheet($transform);


	my $results = $stylesheet->transform($doc) || die ("$0: $!");


	#my $root = $results->getDocumentElement;

	my $title = $root->findvalue("/processing-instruction('filetitle')");
	# A different sx invocation gets called for .xml (for codepage
	# detection) files ...  mysteriously a side effect is an extra '?' 
	# so chop'ing it off
	#chop($title) if ($was eq "xml");
	
	#my $title;
	#my @kidcount = $root->findnodes("/ead/archdesc//daogrp");
	my @kidcount = $root->findnodes("/ead/archdesc//dao[starts-with(\@role,'http://oac.cdlib.org/arcrole/define')] | /ead/archdesc//daogrp");
	my $kidcount = scalar @kidcount;

	#print $results->toString;
	#print $root, $results;
	my $biteme = $results->getDocumentElement;
	#print $biteme;
	#return $biteme, $title, $kidcount ;
	return $results, $title, $kidcount ;



}

sub getPrimeInfo {
	## extract info from the old file, or make
	## some of it up by reading repository MD
	my ($ffile) = (@_);
	my $file = infile2cdlprime($ffile);
        my $doc;
        if (-e $file) {
                if (!($doc = $parser->parse_file($file) ) ) {
                        print STDERR "$0: LibXML parse_file($file) failed";
                        return 0;
                }
                my $root = $doc->getDocumentElement;
                my @daos = $doc->findnodes("/ead/archdesc//dao[starts-with(\@role,'http://oac.cdlib.org/arcrole/define')] | /ead/archdesc//daogrp");
                #my @pois = $doc->findnodes('/ead/archdesc//dao/@poi | /ead/archdesc//daogrp/@poi');
                my @pois = $doc->findnodes('/ead/archdesc//dao[starts-with(@role,"http://oac.cdlib.org/arcrole/define")]/@poi | /ead/archdesc//daogrp/@poi');
                #my @pois = 
                #my @pois = $doc->findnodes('/ead/archdesc//daogrp/@poi');
                my $eadid = $doc->findvalue('/ead/eadheader/eadid[@type="CDL-POI"]');
				my $title = $doc->findvalue('/ead/CDLTITLE');
				my $cdlpath = $doc->findnodes('/ead/CDLPATH');
                my $todo;
				#print $doc->toString; exit;
                return $title, $eadid, $cdlpath, [@pois], [@daos] ;
        } else {
				#if this is a new file, there is no "prime" info to get
				# So we send, in $cdlpath/cdlpathref, an xml parse
				# of the reposity info file to get parent ark/path
                #print "|" . infile2repo($ffile) . "|" ;
                if (!($doc = $parser->parse_file(infile2repo($ffile)) ) ) {
                        print STDERR "$0: LibXML parse_file($ffile) failed";
                        return 0;
                }
        my $root = $doc->getDocumentElement;
		my $out = new XML::LibXML::NodeList;
		##

				my $transform = $parser->parse_file("/voro/code/htdocs/xslt/repo-cdlpath.xslt");
    			my $stylesheet = $xslt->parse_stylesheet($transform)|| die ("$0 $!");;

    			my $results = $stylesheet->transform($doc);

				#print $results->toString;
				my $cdlpath = $results->findnodes('/root/CDLPATH');

                return undef , undef, $cdlpath ;


		
		}
	undef $doc;
}

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
    return $eadroot . "/cdlprime/" . $file;
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
        my $poi = shift;
        $poi =~ s,[.|/],,g;
        my $dir = substr($poi, -2);
        $poi =~ s|ark:13030|$eadroot/mets/$dir/|;
		if (! -e "$eadroot/mets/$dir" ) {
			mkpath("$eadroot/mets/$dir");
		}
        return "$poi";
}


sub spitMets {
# working on this
	#print Dumper @_; exit;
	my ($cdlprime) = @_;
	
 	my $doc = $parser->parse_file($cdlprime);
	#my $xslt = XML::LibXSLT->new();
    my $transform = $parser->parse_file("/voro/code/htdocs/xslt/cdlprime2objs.xsl");
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
    my $transform = $parser->parse_file("/voro/code/htdocs/xslt/premets2mets.xsl");
    my $stylesheet = $xslt->parse_stylesheet($transform)|| die ("$0 $!");;
    my %bs = ( "noindex", "'true'");
    my $results = $stylesheet->transform($doc, %bs);
	#print $results->toString;
	#print "premetsToMets";
	return $results->toString;
}

sub cdlToCdlprime { 
	#print Dumper @_; exit;
	my ($file, $results, $filetitle, $cdlpathref, $poi, @kids) = @_;	

	print "!|! $filetitle !|!";

#print Dumper $cdlpathref; exit;
	$file = infile2cdlprime($file);

 	# my $parser = XML::LibXML->new() || carp ("$0 $!: could not make new parser");
	
 	my $doc = $parser->parse_string($results->toString);

	my $root = $doc->getDocumentElement;



        # get the eadheader and add a new <eadid>
        #
        (my $eadheader) = $root->findnodes('/ead/eadheader');
        (my $eadid) = $root->findnodes('/ead/eadheader/eadid[1]');
        my ($cdltitle) = $root->findnodes('/ead/CDLTITLE[1]');
        #my $cdlpath = $root->findvalue('/ead/CDLPATH[1]');
        # print "- $cdlpath\n";
		my $newid = XML::LibXML::Element->new( 'eadid' );
        #my $newid = $root->createElement('eadid');
        $newid->setAttribute('type', 'CDL-POI' );

        my $text = XML::LibXML::Text->new("$poi");
        $newid->appendChild($text);
        $eadheader->insertAfter($newid, $eadid) || die("$0 $! $ARGV[0] $poi");

        # change the <CDLTITLE> and add <NTITLE>
        #
		my $newtitle = XML::LibXML::Element->new( 'CDLTITLE' );
        #my $newtitle = $doc->createElement('CDLTITLE');

		my $normal = XML::LibXML::Element->new( 'NTITLE' );
        #my $normal = $doc->createElement('NTITLE');

        my $newtitleT = XML::LibXML::Text->new($filetitle);
        #my $normalT = XML::LibXML::Text->new(titleNormal($filetitle));
        my $filenorm = titleNormal($filetitle);
        my $normalT = XML::LibXML::Text->new($filenorm);
        #my $newtitleT = XML::LibXML::Text->new(encodeToUTF8("iso-8859-1",$filetitle));
        #my $normalT = XML::LibXML::Text->new(encodeToUTF8("iso-8859-1",$filenormal));

		#print $newtitleT;
#print "waa ;("; exit;

        $newtitle->appendChild($newtitleT);
        $normal->appendChild($normalT);
#print "waa ;("; exit;

        $root->insertAfter($normal, $cdltitle) || die ("$0: $!");
        $root->replaceChild($newtitle, $cdltitle) ;
#print "waa ;("; exit;
                 # unless ($cdltitle->getData ne "[no ?filetitle]");
	

                for ($cdlpathref->get_nodelist()) {
                        $root->insertBefore($_, $eadheader) || die ("$0 $!");
                        #$root->insertBefore($_, $normal) || die ("$0 $!");
                }
	

		#$root->insertAfter(@{$cdlpathref}[-1], $normal) || die("$0 $!");;

#print "waa ;("; exit;

        # assign IDs to DAOs
        #
        my $count = 0;
#"/ead/archdesc//dao[starts-with(\@role,'http://oac.cdlib.org/arcrole/define')] | /ead/archdesc//daogrp"
        for my $dao ($root->findnodes('/ead/archdesc//dao[starts-with(@role,"http://oac.cdlib.org/arcrole/define")] | /ead/archdesc//daogrp')) {
                #my $href = $dao->findvalue(.//@href);
                #print $href;
                $dao->setAttribute('poi', $kids[$count]);

                $count++;
        }
		#system ("cvs commit $file");

		#$doc->setEncoding("iso-8859-1");
		#open (OUTFILE, ">$file") || die ("$0 $!: $file can't open for write");

        $doc->toFile($file) || die ("$0 $!");
        
        #close OUTFILE;
	#undef $doc;
	
	return $file;
	#return \$root || die ("$0 $!");
	#return $doc->toString || die ("$0 $!");
}
