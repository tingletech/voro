use strict;
use XML::LibXML;
use XML::LibXSLT;
use XML::LibXML::XPathContext;
use Data::Dumper;
use LWP::UserAgent;
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
# sub scanForIllegalChar {scans for illegal HTML characters, as chars and as numeric character references


$| = 1;

my $debug="1";
my $eadroot = "/dsc/data/in/oac-ead";

my $sendmail = "/usr/lib/sendmail -i -t";
my $getMets = "/dsc/branches/production/voro/batch-bin/getMETS.pl";

	my $parser = XML::LibXML->new();
	$parser->recover(1);
	my $xslt = XML::LibXSLT->new();

#read the "new" submission
my ($results, $title, $kidcount, $neadid) =  readNew($ARGV[0]);

#print "readNew: $results $title, $kidcount\n";

# read the "old" cdlprime file
my ($ptitle, $oeadid, $cdlpathref, $poi_aref, $dao_aref) = getPrimeInfo($ARGV[0]);
#print Dumper $ptitle, $oeadid, $cdlpathref, $poi_aref, $dao_aref; exit;

my $eadid = $neadid || $oeadid;

# do some ark validation here TODO

if ( $neadid && $oeadid ) {
	die unless ($neadid == $oeadid);
}

my @pois = getVals($poi_aref);
#print Dumper @pois ;

# use the old file if they did not have a filetitle
$title = $title || $ptitle;

die("$0 $ARGV[0] no title") unless ($title);

#print Dumper getPrimeInfo($ARGV[0]);

# print Dumper $poi_aref->[0];
#my $pkidcount = scalar grep (/ark:/, @{$poi_aref}) ;
my $pkidcount = scalar @{$poi_aref} if ($poi_aref);

my $checkfile = infile2cdlprime($ARGV[0]);

die ("$checkfile needs to be writable") unless (-w $checkfile || !(-e $checkfile));

if (! -e $checkfile) {
	if ( system ("touch $checkfile") ne 0) {
		die;
	} else { 
		system ("rm $checkfile"); 
	}
}


my $cdlprime;

#old file
# ark:/13030/tf100001sq 82 0
print "$ARGV[0] $eadid $kidcount $pkidcount\n" if ($debug);

if ($pkidcount > $kidcount) { die ("$0 $! $pkidcount > $kidcount lost objects") };

if ($eadid && ($kidcount == $pkidcount)) {
	print "1 same number of ids before\n" if ($debug); exit if ($debug == 2);
	#I've got enough ark's
	$cdlprime = cdlToCdlprime($ARGV[0], $results, $title, $cdlpathref, $eadid, @pois);	

# first time we've see this guy with kids
} elsif ($eadid && ($kidcount != $pkidcount) && ($pkidcount == 0) ) {
	print "2 new kids\n" if ($debug); exit if ($debug == 2);
	#The number of arks does not match, but all the new arks are in
	# the <dao>'s
	# !! need to check that output file is writable before minting arks
	my (@npois) = mintbatch($kidcount);
	#print Dumper @npois;
	$cdlprime = cdlToCdlprime($ARGV[0], $results, $title, $cdlpathref, $eadid, @npois);	

# number of attached objects changed
} elsif ($eadid && ($kidcount != $pkidcount) && ($pkidcount > 0) ) {
	print "3: dao mismatch $kidcount $pkidcount\n" if ($debug); exit if ($debug == 2);
	#The number of arks does not match, and this guy had <dao>'s before
	# !! need to check that output file is writable before minting arks
	$cdlprime = mergeCdlprime($ARGV[0], $results, $title, $cdlpathref, $eadid, $dao_aref);

#new file
} else {
	print "4: new one $kidcount $pkidcount\n" if ($debug); exit if ($debug == 2);
	# !! need to check that output file is writable before minting arks
	my ($eadid, @npois) = mintbatch (1 + $kidcount); 
	print "|$eadid| $cdlpathref|";
	$cdlprime = cdlToCdlprime($ARGV[0], $results, $title, $cdlpathref, $eadid, @npois);	
	#my $cmd = "cvs -d /voro/cvsdata add " . infile2cdlprime($ARGV[0]);
	#print $cmd . "\n";
	#system ($cmd);
}



# print XML::LibXML->get_last_error();
## $cdlprime is an XML document

print "just ";
#spitMets($cdlprime);
print " ignore bus errors and core dumps here...";
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

sub getLinks {
	#print Dumper @_; exit;
	my ($in) = @_;
	my %out;
	for (@{$in}) {
		#print Dumper $_->toString;
		my $fhref = $_->findvalue('@href | daoloc[@role="thumbnail"]/@href');
		$fhref =~ m,.*/(.*)$,;
		$fhref = $1;

		$out{ $fhref } = $_->findvalue('@poi');
		#push @out, $_->findvalue('@poi');
		# print $_->findvalue('@poi');
	}
	return \%out;

	#print Dumper %out;
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
      #my $req = HTTP::Request->new(GET => 'http://ark-dev.cdlib.org:8084/foo');
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
	die ("$0: $eadroot/submission/$file not found") if (!(-e "$eadroot/submission/$file"));
	# scanForIllegalChar("$eadroot/submission/$file", $file);
	if ($file =~ m/.xml$/){
		$xml = `xsltproc /dsc/branches/production/at2oac/at2oac.xsl $eadroot/submission/$file`;
		$was = "xml";
	} else {
		die ("$1: $file must be .xml");
	}
	#print $xml;
	my $doc = $parser->parse_string($xml) || die ("$0 $! $xml");
	
	my $transform = $parser->parse_file("/dsc/branches/production/voro/xslt/ead2cdl.xsl");
	my $transform2 = $parser->parse_file("/dsc/branches/production/voro/xslt/Remove-Namespaces.xsl");

	my $stylesheet = $xslt->parse_stylesheet($transform);
	my $stylesheet2 = $xslt->parse_stylesheet($transform2);

	my $noNameSpaceDoc = $stylesheet2->transform($doc) || die ("$0: $!");
	my $results = $stylesheet->transform($noNameSpaceDoc) || die ("$0: $!");

	#print $results->toString;

	#my $root = $results->getDocumentElement;
	my $root = $noNameSpaceDoc->getDocumentElement;

	#print Dumper $root->toString;

	my ($eadid_node) = $root->findnodes('//eadid');

	my $ids = $eadid_node->toString();

	# regex it up to clean up the ARK
	$ids =~ m,^(.*)?(ark:/13030/\w*)[/]?.*$,;

	my $neadid = $2;

        if ($neadid =~ m,13030/sc,) { die; }

	#print "$2|\n"; exit;

	# write the normalized ARK back to where XTF will expect it

	$eadid_node->setAttribute('identifier', $neadid);

	$neadid = undef unless ($neadid =~ m,ark:/,);

	my $title = $root->findvalue('/ead//titleproper[@type="filing"]');
	
	#my $title;
	#my @kidcount = $root->findnodes("/ead/archdesc//daogrp");
	my @kidcount = $root->findnodes
		(
"/ead/archdesc//dao[starts-with(\@role,'http://oac.cdlib.org/arcrole/define')] 
| /ead/archdesc//dao[starts-with(\@content-role,'http://oac.cdlib.org/arcrole/define')] 
| /ead/archdesc//daogrp[not(starts-with(\@content-role,'http://oac.cdlib.org/arcrole/link'))]");
	my $kidcount = scalar @kidcount;

	#print $root, $results;
	#my $biteme = $results->getDocumentElement;
	#print $biteme;
	#return $biteme, $title, $kidcount ;
	return $results, $title, $kidcount , $neadid;



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

		# set up xpath context
        	my $xc = XML::LibXML::XPathContext->new($root);
        	$xc->registerNs('cdlpath', 'http://www.cdlib.org/path/');

                my @daos = $doc->findnodes("/ead/archdesc//dao[starts-with(\@role,'http://oac.cdlib.org/arcrole/define')] | /ead/archdesc//daogrp[not(starts-with(\@content-role,'http://oac.cdlib.org/arcrole/link'))]");
                #my @pois = $doc->findnodes('/ead/archdesc//dao/@poi | /ead/archdesc//daogrp/@poi');
                my @pois = $doc->findnodes('/ead/archdesc//dao[starts-with(@role,"http://oac.cdlib.org/arcrole/define")]/@poi | /ead/archdesc//daogrp[not(starts-with(@content-role,"http://oac.cdlib.org/arcrole/link"))]/@poi');
                #my @pois = 
                #my @pois = $doc->findnodes('/ead/archdesc//daogrp/@poi');
                my $eadid = $doc->findvalue('/ead/eadheader/eadid/@identifier');
				my $title = $doc->findvalue('/ead/eadheader/filedesc/titlestmt/titleproper[@type="filing"]');
				my $cdlpath = $xc->findnodes('/ead/eadheader/eadid/@*[namespace-uri()="http://www.cdlib.org/path/"]');
				

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

				my $transform = $parser->parse_file("/dsc/branches/production/voro/xslt/repo-cdlpath.xslt");
    			my $stylesheet = $xslt->parse_stylesheet($transform)|| die ("$0 $!");;

    			my $results = $stylesheet->transform($doc);
			my $xc = XML::LibXML::XPathContext->new($results);
                	$xc->registerNs('cdlpath', 'http://www.cdlib.org/path/');


				#print $results->toString;
				my $cdlpath = $results->findnodes('/root/@*[namespace-uri()="http://www.cdlib.org/path/"]');


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
        my $poi = shift;
        $poi =~ s,[.|/],,g;
        my $dir = substr($poi, -2);
        $poi =~ s|ark:13030|$eadroot/mets/$dir/|;
        return "$poi";
}


sub spitMets {
# working on this
	#print Dumper @_; exit;
	my ($cdlprime) = @_;
	
 	my $doc = $parser->parse_file($cdlprime);
	#my $xslt = XML::LibXSLT->new();
    my $transform = $parser->parse_file("/dsc/branches/production/voro/xslt/cdlprime2objs.xsl");
    my $stylesheet = $xslt->parse_stylesheet($transform)|| die ("$0 $!");;

    my $results = $stylesheet->transform($doc);



	#print $results->toString;

	my $root = $results->getDocumentElement;

#print "what?"; exit;

	my ($super) = $root->findnodes('/eadobjs/super');
        my $superID = $root->findvalue('/eadobjs/super/@poi');
        my $xout = poi2file($superID);
        # print " $superID -- $xout";
        #open (OUT ,">$xout.mets.xml") || die("$0 $! $_: can't open $xout.mets.xml");
        # print $super->toString;
		#print OUT premetsToMets($super);
        #close OUT;

	
        #foreach my $node ($root->findnodes('/eadobjs/sub/c') ) {
		
                #my $poi = $node->findvalue('@poi');
                #my $xout = poi2file($poi);
                #print "$poi -- $xout \n";
                #if ($xout eq "") { print STDERR "$0: skipping null poi in $ARGV[0]\n"; next; }
                #$node->setAttribute('parent', $superID);
                #open (OUT ,">$xout.mets.xml") || die ("$0 $! $_ $xout.mets.xml");
                #print OUT premetsToMets($node);
                #close OUT;

        #}
	undef $doc;


}

sub premetsToMets {
	#print "premetsToMets";
	my ($cdlprime) = @_;
	#print Dumper $cdlprime;
 	my $doc = $parser->parse_string($cdlprime->toString);
	#my $xslt = XML::LibXSLT->new();
    my $transform = $parser->parse_file("/dsc/branches/production/voro/xslt/premets2mets.xsl");
    my $stylesheet = $xslt->parse_stylesheet($transform)|| die ("$0 $!");;

    my $results = $stylesheet->transform($doc);
	#print $results->toString;
	#print "premetsToMets";
	return $results->toString;
}

sub cdlToCdlprime { 
	my ($file, $results, $filetitle, $cdlpathref, $poi, @kids) = @_;	

	print " $filetitle ";

	$file = infile2cdlprime($file);
	print "$file\n";

 	my $doc = $parser->parse_string($results->toString);


	my $root = $doc->getDocumentElement;
	my $xc = XML::LibXML::XPathContext->new($root);
        $xc->registerNs('cdlpath', 'http://www.cdlib.org/path/');

	my $wtf1 = $xc->findnodes('/ead/archdesc//dao[starts-with(@role,"http://oac.cdlib.org/arcrole/link/grab")]');
	my $wtf11 = $xc->findnodes('/ead/archdesc//dao[starts-with(@role,"http://oac.cdlib.org/arcrole/grab")]');
	#my $wtf1 = $xc->findnodes('/ead/archdesc//dao');
	my $wtf2 = $ARGV[2];
	print "bogus role http://oac.cdlib.org/arcrole/grab\n" if ($wtf11);

	print "!$wtf1 ---- !$wtf2";
	if ( $wtf1 && $wtf2 ) {

		open(SENDMAIL, "|$sendmail") or die "can't run $sendmail";
                print SENDMAIL "Reply-to: $ARGV[2]\n";
                print SENDMAIL "From: voro user <$ARGV[2]>\n";
                print SENDMAIL "To: oacops\@cdlib.org\n";
		print SENDMAIL "Subject: voroEAD/voroBasic processing\n";

		print SENDMAIL "\n$ARGV[2] submitted a finding aid $ARGV[0] using voroEAD\n";

 print SENDMAIL qq{which contains links to associated METS digital objects: these are
 <dao> Digital Archival Object links with ROLE attributes set to
 "http://oac.cdlib.org/arcrole/link/grab/" and HREF attributes with
 URLs for METS objects.\n};

print SENDMAIL<<EOF;

OAC Operations Group staff are now scheduling and processing the ingest
of the associated METS digital objects, which may take several days.

You will be informed if there are any problems with your submission,
and you will be emailed the link to its final processing report if it
the submission is accepted.

Thank you,

OAC Operations Group
oacops\@cdlib.org

EOF


		close SENDMAIL;

		return;

	}
	(my $eadid) = $xc->findnodes('/ead/eadheader/eadid');
	
	my ($local_ark) =  $xc->findnodes('/ead/eadheader/eadid/@identifier[starts-with(.,"ark:/")]');

	unless ($local_ark) {
		$eadid->setAttribute('identifier', $poi);
	}

	$eadid->setNamespace("http://www.cdlib.org/path/","cdlpath",0);

                for ($cdlpathref->get_nodelist()) {
			$eadid->setAttributeNS ("http://www.cdlib.org/path/", $_->nodeName, $_->getValue);
                }

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

	# hook to voroBASIC METS ingestion

	for my $dao ($root->findnodes('/ead/archdesc//dao[starts-with(@role,"http://oac.cdlib.org/arcrole/link/grab")] | /ead/archdesc//daogrp[starts-with(@role,"http://oac.cdlib.org/arcrole/link/grab")]')) {



		my $file = $dao->findvalue('@href');
		print "$getMets $file\n";
		my $message = `$getMets $file`;
		print "$message";
		my ($action, $type, $gark) = split (m/\|/, $message);
		$gark =~ s,\n,,gs;
		#print STDERR "$action $type $gark\n";
		$dao->removeAttribute("href");
		$dao->removeAttribute("content-role");
		$dao->setAttribute("href", "http://ark.cdlib.org/$gark");
		$dao->setAttribute("content-role", "http://oac.cdlib.org/arcrole/link/$type");
	}

		#system ("cvs commit $file");

		#$doc->setEncoding("iso-8859-1");
		#open (OUTFILE, ">$file") || die ("$0 $!: $file can't open for write");

        $doc->toFile("$file") || die ("$0 $!");
        
        #close OUTFILE;
	#undef $doc;
	
	return $file;
	#return \$root || die ("$0 $!");
	#return $doc->toString || die ("$0 $!");
}

sub mergeCdlprime {
	#die ("untested on 2002");
	my ($file, $results, $title, $cdlpathref, $eadid, $dao_aref) = @_;
	$file = infile2cdlprime($file);
	my $ark_hash = getLinks($dao_aref);


	 my $doc = $parser->parse_string($results->toString);

        my $root = $doc->getDocumentElement;


	#print "here\n";
	#print $results->toString;
	my $nodes = qq{/ead/archdesc//dao[starts-with(\@role,'http://oac.cdlib.org/arcrole/define')] | /ead/archdesc//dao[starts-with(\@content-role,'http://oac.cdlib.org/arcrole/define')] | /ead/archdesc//daogrp[not(starts-with(\@content-role,'http://oac.cdlib.org/arcrole/link'))]};
	#print $nodes;
	my @res;
	#print Dumper $@ if $@;
	#print $results->toString;
	for my $dao ($root->findnodes("$nodes")) {

		my $href = $dao->findvalue('@href | daoloc[@role="thumbnail"]/@href');
		$href =~ m,.*/(.*)$,;
                my $fhref = $1;

		my $ark;
		if ($ark_hash->{$fhref}) {
			$ark = $ark_hash->{$href}
		} else {
			($ark) = mintbatch(1);
		}
		print "$href:$ark\n" unless ($ark_hash->{$fhref});

                $dao->setAttribute('poi', $ark);
                #$count++;
        }

        $doc->toFile("$file") || die ("$0 $!");
	return $file;
}

# -----
# (2009/9/14 2:45pm MAR)
# Scan input file for characters which are illegal in HTML, either as
# actual characers, or as numeric character references.  These are "&#129;"
# through "&#159;", which might also be expressed as "&#x81;" through
# "&#x9f;", or as actual characters with decimal values between 129 and 159,
# inclusive.
#
# It appears that the way we report errors is to "die".
#
sub scanForIllegalChar {
	my $input_file = $_[0];
	my $file_name_for_message = $_[1];

	my $char_number;
	my $char_ord;
	my $is_hex;
	my @found_bad;
	my $line_number;
	my $ncr;
	my $ncr_value;
	my $rest_of_line;

	# Open the input file.
	open(INPFIL, "<", $input_file) ||
		die "$0 $file_name_for_message - unable to open ",
			"\"$input_file\" for input, $!, stopped";

	# Process each line.
	$line_number = 0;
	@found_bad = ( );
	while (<INPFIL>) {
		chomp;
		$line_number++;

		# Scan the line for numeric character references.
		for ($char_number = 1; length($_) > 0;) {

			# Does $_ start with a numeric character reference?
			if (/^(&#(x?)([a-f0-9]+);)(.*)$/i) {
				# Yes.  See if it's one of the illegal ones.
				$ncr = $1;
				$is_hex = $2;
				$ncr_value = $3;
				$rest_of_line = $4;

				# If it was hex, convert it to decimal.
				if (length($is_hex) != 0) {
					$ncr_value = hex($ncr_value);
					}

				# If it's in the problematic range, make note
				# of it.
				if (($ncr_value >= 129) &&
					($ncr_value <= 159)) {
					push @found_bad, "\tline " .
						"$line_number, character " .
						"$char_number:  \"$ncr\"\n";
					}

				# Update the character number within the line.
				$char_number += length($ncr);
				$_ = $rest_of_line;

				# Look at what follows the NCR.
				next;
				}

			# No, the line does not start with a numeric
			# character reference.  Does it start with an
			# actual character in the problematic range?
			$char_ord = ord(substr($_, 0, 1));
			$_ = substr($_, 1);

			# If it's problematic, make note of it.
			if (($char_ord >= 129) && ($char_ord <= 159)) {
				push @found_bad, "\tline $line_number, " .
					"character $char_number:  character " .
					"with hexadecimal representation " .
					sprintf("%02x", $char_ord) . "\n";
				}

			# Update the characer number within the line.
			$char_number++;
			}
		}
	close(INPFIL);

	# If we found anything at all that was problematic, "die".
	if (scalar(@found_bad) == 1) {
		die "$0 $file_name_for_message - found a character that is ",
			"illegal in HTML:\n",
			@found_bad,
			"stopped";
		}
	if (scalar(@found_bad) > 1) {
		die "$0 $file_name_for_message - found several characters ",
			"that are illegal in HTML:\n",
			@found_bad,
			"stopped";
		}

	# Everything was OK.
	return;
	}
