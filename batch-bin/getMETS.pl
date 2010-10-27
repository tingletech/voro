#!/bin/env perl -w
# voroBASIC: getMETS.pl

use strict;
use BSD::Resource;
use Time::HiRes qw(gettimeofday tv_interval sleep);
use bytes;
use Image::Size;

my %mime2ext = ( 'image/jpeg' => 'jpg',
		 'video/quicktime' => 'mov' );

my $localBase = "/dsc/data/in/new";
my $urlBase = "http://content.cdlib.org/dynaxml"; 
our $validate_command = "/voro/local/bin/validate";
our $gif2png_command = "/voro/local/bin/gif2png -O";
our $pdftotext_command = "/cdlcommon/products/xpdf-3.02/bin/pdftotext";

# turn UCSD structMap to UCB structMap
my $trimXslt = "/voro/code/htdocs/xslt/structMapTrim.xsl";
# turn UCB structMap to 7train structMap
my $buffXslt = "/voro/code/htdocs/xslt/structMapBuff.xsl";
# generate Krik's XTF structMap from a TEI (not used any more; should remove this?)
my $teiBuff = "/voro/code/htdocs/xslt/teiBuff.xsl";

my $imgsize;

# if carefree, then processing goes forward, even if input has not changed
my $carefree = 1;
my $regen = 1;
my $forgive_mets = 0;
my $forgive_tei = 0;

$| ="1";

use utf8;
use strict;

# gnome libxml2
use XML::LibXML;
# gives the DOM access to full XPath API (ie set namespaces)
use XML::LibXML::XPathContext;
use XML::LibXSLT;
#use XML::Schematron::LibXSLT;

use Carp;
use Data::Dumper;
use Storable;
 $Storable::interwork_56_64bit = 1 ; 



# lets play nice
setpriority( PRIO_PROCESS, 0 , 19) || die ("$0: $! not nice\n");

# exports magic mkpath (recursive mkdir) command
use File::Path;

# set up  global $sha2obj to make checksums type SHA-256
use Digest::SHA;
my $sha2obj = new Digest::SHA;

my $parser = XML::LibXML->new() || carp ("$0: could not make new parser");

$parser->load_ext_dtd(1);
$parser->recover(0);


# libwwwperl
use LWP;
use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->agent("voroBasic (510)987-0443 brian.tingle\@ucop.edu");

# graphics library for composite thumbnail
use GD;

# holds XML::LibXML::XPathContext for the last run of a file (read-only)
our $lxc;

unless (@ARGV) {
	print "$0: usage
command tries to ingest every METS file listed on the command line
$0 URL-to-a-METS-file
returns the object TYPE and OBJID upon successful processing\n";
	exit;

}

# main for loop
# command tries to ingest every METS file listed on the command line
for (@ARGV) {
        #my $mets = $ua->head($_);
	my $doc;
	my $lastMets;
	# METS/ARK/OBJECT level loop
	# since we don't know the ARK yet, we can't do a conditional
	# GET on the METS
	# load the $_ into an XML::LibXML::Document 
	my $t0 = [gettimeofday];
	my $urlRewrit = $_;
	# work around UCB throttle
	$urlRewrit =~ s,^http://digitalassets.berkeley.edu/,http://sunsite2.berkeley.edu/special_access/da/,;
        if (!($doc = $parser->parse_file($urlRewrit) ) ) {
                print STDERR "$0: LibXML parse_file($urlRewrit) failed\n";
                return 0;
        }
	next unless $doc;
    	my $root = $doc->getDocumentElement;

	# take checksum before it gets changed
	$sha2obj->add($doc->toString);
	my $check2 = $sha2obj->hexdigest();
	$sha2obj->reset();

	# set up xpath context
        my $xc = XML::LibXML::XPathContext->new($root);
	$xc->registerNs('mets', 'http://www.loc.gov/METS/');
	$xc->registerNs('mods3', 'http://www.loc.gov/mods/v3');
	$xc->registerNs('xlink', "http://www.w3.org/1999/xlink");

	# ****
	# figure out ARK
	my $ark = $xc->findvalue('/mets:mets/@OBJID');
	$ark =~ s,^(.*)ark:/,ark:/,;

	# validate ARK???  at least its got to have one!!
	# should do something better than die silently...
	next unless ($ark =~ m,^ark:/,);
	#$ark =~ s,non-ark,ark,;
	
	# write the normalized ARK back to the METS
	$root->setAttribute('OBJID', $ark);	

	my $actionTaken;

	# ****
	# figure out PROFILE -> "true" cdl TYPE
	my $type = $xc->findvalue('/mets:mets/@TYPE') || 'generic';
	my $profile = $xc->findvalue("/mets:mets/\@PROFILE");
	my ($typeNode) = $xc->findnodes('/mets:mets/@TYPE');
	$type =~ s, ,+,gs;
	if ($type eq "item") { 
		my $modsType = $xc->findvalue('/mets:mets/mets:dmdSec/mets:mdWrap[@MDTYPE="MODS"][1]/mets:xmlData//*[local-name()="typeOfResource"][1]');
		#print STDERR $modsType;
		if ($modsType eq "text") {
			$type = "facsimile text";
		} else {
			$type = "image collection";
		}
	}

	if ($type eq "still+image" or $type="mixed+media") {
		my $structLook = $xc->findvalue
                	("count(//mets:fileGrp[starts-with(\@USE,'thumbnail') or \@USE='image/thumbnail'][1]/mets:file)");
		my $structLookTei = $xc->findvalue
                	("count(//mets:fileGrp[starts-with(\@USE,'tei') or \@USE='text/tei'][1]/mets:file)");

		#print "|$structLook|$structLookTei";
		if ($structLook == 1  and !($structLookTei > 0)) {
			$type = 'image';
		} elsif ($structLook > 1 and !($structLookTei > 0)) {
			$type = 'image collection';
		} elsif ($structLookTei == 1) {
			$type = 'text';
		} elsif ($structLookTei > 1) {
			die ("$0: $_ too many tei files \n");
		}
	}
		
	if ($type eq "text") {
		my $structLookTei = $xc->findvalue
                	("count(//mets:fileGrp[starts-with(\@USE,'tei') or \@USE='text/tei'][1]/mets:file)");

		if ($structLookTei > 1) {
			die ("$0: $_ too many tei files \n");
		} elsif ( 
		     ( $profile eq "http://www.loc.gov/standards/mets/profiles/00000002.xml" )
			or
		     ( $profile eq "http://www.loc.gov/standards/mets/profiles/00000003.xml" )
			and not 
		     ( $structLookTei == 1 )
		) {
			$type = "facsimile text" 
		}
	}

	# figure out file names
	# - something/data/rt/arkpart/ = BASE directory for object
	# this needs to change to match Kirk's format
	# - BASE/source.mets.xml = copy of the METS submitted to CDL
	# - BASE/cache_info.storable = Hash of Hash seralized to disk
	#	This file contains info to do conditional GETS
	#	also, store checksums here too?
	# - BASE/arkpart.mets.xml = METS after processing
	# - BASE/files/arkpart-FID1.gif = file[@ID='FID1'] where the file extension on the href is .gif
	# - BASE/arkpart.xml	= content for indexing ( TEI or EAD ) special case
	# - BASE/files/arkpart-thumbnail.png  = constructed thumbnail image

	# this is the base directory/filename to save METS and files to
	my $objectBaseName = poi2text($ark);
	my $objectBaseDir = $objectBaseName;
	$objectBaseDir =~ s,([^/]*)/([^/]*)$,$1,;
	my $sigpart = $2;
	my $filesBaseName = "$objectBaseDir/files/$sigpart";

	my $sourceMets =  "$objectBaseDir/source.mets.xml";
	my $cacheFile =  "$objectBaseDir/cache_info.storable";
	my $newMets = "$objectBaseName.mets.xml";
	my $thumbnailF = "$objectBaseDir/$sigpart/thumbnail.png";
	#print "$ark\nobn $objectBaseName\nobd $objectBaseDir\nsm $sourceMets\n$processLog\n";
	#
	# if there is a $sourceMets; take its checksum, and see if it has changed.
	if (-e $sourceMets) {
		# take the checksum
		#print $sourceMets;
		open (CHK, "<$sourceMets");
		$sha2obj->addfile(*CHK);
		my $checksum = $sha2obj->hexdigest();
		$sha2obj->reset();
		close(CHK);
		$sha2obj->reset();
		close(CHK);
		if ( $checksum eq $check2 ) {	
			#print STDERR "$0: the file is the same as before, remove $sourceMets to reprocess\n";
			$actionTaken = "0";
		 	unless ($carefree) {
				print "$actionTaken|$type|$ark\n";
				next;
			};
			$actionTaken = "R";
		} else {
			print STDERR "$0: the METS Document file has changes\n";
			## save update  $sourceMets
			print STDERR "$sourceMets";
			$doc->toFile($sourceMets);
			$actionTaken = "U";
		}
	# else no "source" METS, is a new file
	} else {
		$doc->toFile($sourceMets);
		$actionTaken = "N";
	}

	# newMets is not really the new mets yet, but the "expanded" METS
	# from a previous time this was run		
	if (-e $newMets) {
        		if (!($lastMets = $parser->parse_file($newMets) ) ) {
                		print STDERR "$0: LibXML parse_file($lastMets) failed";
                		next;
        		}
			my $lroot = $lastMets->getDocumentElement;
        		$lxc = XML::LibXML::XPathContext->new($lroot);
        		$lxc->registerNs('mets', 'http://www.loc.gov/METS/');
        		$lxc->registerNs('mods', "http://www.loc.gov/mods/");
        		$lxc->registerNs('mods3', "http://www.loc.gov/mods/v3");
        		$lxc->registerNs('xlink', "http://www.w3.org/1999/xlink");
	}

	# now that we have a copy of the METS locally, 
	# let's validate it for good luck

	my $message = `$validate_command $sourceMets`;
	my $exit = $? >> 8;

	print $message if ( $exit != 0 );
	next if ( ($exit != 0) && (!$forgive_mets) );
	
	$typeNode->setValue($type) if $typeNode;
 	
	# hash reference
	# retrieve exported by Storable 
	# (will be empty if we've not seen this one)
	my $cacheInfo = {};
	if (-e $cacheFile) {
		$cacheInfo = retrieve($cacheFile);
	}

	if (($profile eq 'http://www.loc.gov/mets/profiles/00000027.html') or ($profile eq "Archivists' Toolkit Profile") ) {
		# normalize fileGrp/@USE
		my $fixUSE = $xc->findnodes('/mets:mets/mets:fileSec//mets:fileGrp[@USE]');
		foreach my $node ($fixUSE->get_nodelist) {
			my $old_use = $node->getAttribute("USE");
			my $new_use;
			if ($old_use =~ m,Master,) {
				$new_use = "archive";
			} elsif ($old_use =~ m,Thumbnail,) {
				$new_use = "thumbnail";
			} elsif ($old_use =~ m,Service,) {
				$new_use = "reference";
			} else {
				$new_use = $old_use;
			}
			$node->setAttribute( "USE", $new_use );
		}

		# find the MODS record
		my ($fixMODS) =   $xc->findnodes('(/mets:mets/mets:dmdSec/mets:mdWrap/mets:xmlData/mods3:mods)[1]');
		# find the notes we want to move
		my ($wrongNote) = $xc->findnodes('(/mets:mets/mets:dmdSec/mets:mdWrap/mets:xmlData/mods3:mods)[1]/mods3:note[starts-with(translate(@displayLabel,"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz"),"digital object made available by")]');
		if ($wrongNote) {
			my $location = XML::LibXML::Element->new("location");
        		$location->setNamespace("http://www.loc.gov/mods/v3");
			my $physicalLocation = XML::LibXML::Element->new("physicalLocation");
        		$physicalLocation->setNamespace("http://www.loc.gov/mods/v3");
			$physicalLocation->appendText( $wrongNote->findvalue(".") );
			$location->appendChild($physicalLocation);
			$fixMODS->appendChild($location);
			$fixMODS->removeChild($wrongNote);
		}
		# also check for mdRef to try to make sure it is redundent?
		my ($redundantRelatedItem) = $xc->findnodes('(/mets:mets/mets:dmdSec/mets:mdWrap/mets:xmlData/mods3:mods)[1]/mods3:relatedItem[@type="host"]');
		if ($redundantRelatedItem) {
			$fixMODS->removeChild($redundantRelatedItem);
		}
	}

	# this XPath can be tuned (based on PROFILE and type)
	# but right now this tries to do its stuff on all
	# files in the file inventory
	#my $filenodes = $xc->findnodes("/mets:mets/mets:fileSec//mets:file");
	my $filenodes = $xc->findnodes
		(q{
	/mets:mets/mets:fileSec//mets:file
		[not(starts-with(@USE,'archive'))]
		[not(starts-with(../@USE,'archive'))]
		[not(contains(@USE,'/master'))]
		[not(contains(@USE,'-Master'))]
		[not(contains(../@USE,'/master'))]
		[not(contains(../@USE,'-Master'))]
		[not(@MIMETYPE='image/sid')]
		[not(@MIMETYPE='image/x-mrsid-image')]
		[not(@MIMETYPE='image/tiff')]
		[not(@MIMETYPE='image/jp2')]
		[mets:FLocat]
	});

	# okay, everything is set up, now we can get to work

	# the loop goes through the file section, collecting files
	foreach my $context ($filenodes->get_nodelist) {
		print Dumper $context->toString;
		# harvestFileNode alters $context (passed by reference)
		# it also alters $xc or $root
		harvestFileNode(\$xc, \$context, \$ark, \$cacheInfo, $filesBaseName, $objectBaseName, $_);
	}

	# okay, now we are almost done! 
	# final cleanup on the METS

	# create composite image, update file inventory
	my $count = $xc->findvalue
		("count(//mets:fileGrp[starts-with(\@USE,'thumbnail') or \@USE='image/thumbnail'][1]/mets:file)");
	# todo TODO test if this is an image object ...
	# if this is a multi image object

	if ($count > 1 and not $profile eq "Archivists' Toolkit Profile") {
		my $label = "$count";
		if ($type eq "text") {
			$label .= " pages";
		} else {
			$label .= " images";
		}
		$label .= "..." if ($count > 3);

		compositeThumbnails(\$root, $label, $filesBaseName);
	} elsif 
	  (my $id = $xc->findvalue('//mets:fileGrp[starts-with(@USE,"thumbnail") or @USE="image/thumbnail"][1]/mets:file[1]/@ID')  
	    ) {
		# rename file/@ID='FID1' to 'thumbnail'
		# !! unless there allready is a file/@ID thumbnail??!
		my ($thumb) = $xc->findnodes(qq{//mets:file[\@ID="$id"]});
		$thumb->setAttribute("ID","thumbnail");
		
		#				 <mets:fptr   FILEID="FID1"/>
		my ($point) = $xc->findnodes(qq{//mets:fptr[\@FILEID="$id"]});
		#print Dumper $point->toString;	
		$point->setAttribute("FILEID","thumbnail");
		$imgsize->{'thumbnail'} = $imgsize->{$id};
	}

	# open up the XSLT that buffs out the structMap
	my $buff;
	
	#print "$type $profile\n";
	if ($type ne "text") {	
		$buff = $buffXslt;
	} else {
		$buff = $teiBuff;
	}

	#print STDERR "$type: $buff\n";;

	my $results;

	if ( $profile eq "http://www.loc.gov/mets/profiles/00000010.xml") {
		$root->setAttribute("xmlns:cdl", "http://www.cdlib.org/");
		addInfo($xc);
		$results = $doc;
	} elsif ( $profile eq "Archivists' Toolkit Profile" ) {
		my $trimStyle = $parser->parse_file($trimXslt);
		my $buffStyle = $parser->parse_file($buff);
		my $xslt = XML::LibXSLT->new();
		my $trimmer = $xslt->parse_stylesheet($trimStyle);
		my $buffer = $xslt->parse_stylesheet($buffStyle);
		addInfo($xc);
		$results = $buffer->transform($trimmer->transform($doc));
	} else {
		my $buffStyle = $parser->parse_file($buff);
		my $xslt = XML::LibXSLT->new();
		my $buffer = $xslt->parse_stylesheet($buffStyle);
		addInfo($xc);
		$results = $buffer->transform($doc);
	}



	my $res = $results->getDocumentElement;

	# header as an alt ID ...
	my ($header) = $res->getElementsByLocalName("metsHdr");
	unless ($header) {
		$header = XML::LibXML::Element->new("metsHdr");
		my $fc = $res->firstChild;
		#print Dumper $fc;
		$res->insertBefore($header, $fc);
	}
	
	my $altID = XML::LibXML::Element->new("altRecordID");
	$altID->appendText("$_");
	$header->appendChild($altID);

	# Lets save the processed METS
	$results->toFile($newMets);
	print "$actionTaken|$type|$ark\n";

	# since there is no place in the METS for the etag nor last-modified-; 
	# we need to save this hash to disk
	store $cacheInfo, $cacheFile;
}


## for a 'mets:file' XML::LibXML::Element, file main
# main sub called by the inner loop
sub harvestFileNode {
	my ($xc, $context, $ark, $cacheInfo, $filesBaseName, $objectBaseName, $baseHref) = @_;

	my $lc = XML::LibXML::XPathContext->new($$context);
	$lc->registerNs('mets', 'http://www.loc.gov/METS/');
	$lc->registerNs('xlink', "http://www.w3.org/1999/xlink");

	# check to see if this one has been processed before?
	# well, we don't really need to, LWP and HTTP sort of
	# handel that...  If we have succeeded in downloading the
	# file in the past, the saved E-Tag and Last-Modified info is
	# feed to LWP and an HTTP conditional GET is performed.
	# it will only fetch it if it needs to.
	
	#remote file name
	my $file = $lc->findvalue("mets:FLocat/\@xlink:href");

	# poor man's relative links	
	unless ( $file =~ m,^http://, ) {
		my $trueBase = $baseHref;
		$trueBase =~ s,^(.*)/[^/].*?$,$1/,;
		$file = $trueBase . $file;
	}

	#compute local file name
	#$file =~ m,[^\.]*?\.([^\.|^\?]*)$,;
	#my $ext = $1;
	#$ext = substr($ext, 0, 3);
	#print "file: $file\n";
	#print "ext: $ext\n";
	my $id = $$context->getAttribute("ID");
	#my $filesBaseName = poi2text($$ark);
	my $outfile = "$filesBaseName-$id";
	# do the actual LWP in a sub routine
	my ($size, $checksum, $mime) = getFile($xc, $file, $outfile, $cacheInfo, $id, $objectBaseName, $filesBaseName);

	my $ext = mime2ext($mime);
	if (-e $outfile) {
		rename( $outfile, "$outfile.$ext") || die ("$0: $? $outfile $ext\n");
	}
	# try to rip some text if it looks like a pdf
	if ($ext eq 'pdf') {
		my $message = `$pdftotext_command $outfile.$ext $outfile.txt`;
    	my $exit = $? >> 8;
    	print $message if ( $exit != 0 );
	}
	my $outURL = file2url("$outfile.$ext");
	return unless ($size && $checksum);
	
	# manipulate the DOM to change around $$context (reference)
	#print "$size $checksum\n";
	$$context->setAttribute("SIZE",$size);
	$$context->setAttribute("CHECKSUM",$checksum);
	$$context->setAttribute("CHECKSUMTYPE","SHA-256");
	$$context->setAttribute("MIMETYPE",$mime);
	# get the "old" FLocat, so we can insert ourself's before it
	my ($oFLocat) = $lc->findnodes("mets:FLocat");
	# the new one, set its URL
	my $nFLocat = XML::LibXML::Element->new("mets:FLocat");
	$nFLocat->setNamespace("http://www.loc.gov/METS/");
	$nFLocat->setAttribute("xlink:href",$outURL);

	## For BAMPFA; per agreement we need to give preference /
	## send users to thier version; so insert After for them
	if ( $file =~ m,bampfa\.berkeley\.edu/, ) {
		$$context->insertAfter($nFLocat, $oFLocat);
	} else {
		$$context->insertBefore($nFLocat, $oFLocat);
	}
	# will add on a new fileGrp to the document, representing 
	# all the files that just got spidered
	#print "hi\n";
}


# LWP called from here ... copies $file (URL) to $outfile (local)
# spider / mirror logic stores cache data in $cache hash ref
# ID is key of hash 
sub getFile {
	my ($xc, $file, $outfile, $cache, $id, $objectBaseName, $filesBaseName) = @_;
	$file =~ s,^http://digitalassets.berkeley.edu,http://sunsite2.berkeley.edu/special_access/da/,;
	my $ark = $$xc->findvalue("/mets:mets/\@OBJID");
	my $t0 = [gettimeofday];
	my $req = HTTP::Request->new(GET => $file);
	my $elasped = tv_interval ( $t0 );
	# set HEADERS; if the hash is empty, no HEADER are set
	#print Dumper $cache;
	#print $cache;
	$req->header(%{$$cache->{$id}}) if ($$cache->{$id});
        my $res = $ua->request($req, $outfile);
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, 
		$atime,$mtime,$ctime,$blksize,$blocks);
	my $checksum;
	my $xmlout;
	my $mime;
	my $valid;

	if ($res->code() eq "503") {
print STDERR $res->code();
print STDERR " $file\n";
print STDERR $res->header("Retry-After");
sleep(30);
print STDERR "\n";
	}

	if ($res->code() eq "304") {
		# file not modified...  need some way to load
		# in the values from the last time we took the
		# checksum and filesize.  We may not have the files
		# locally anymore (they could be shipped off to 
		# production) so we should copy them from the old
		# arkpart.mets.xml

		my ($fptr);
		if ( $lxc->findnodes(qq(//mets:file[\@ID="$id"]))) {
			$size =     $lxc->findvalue(qq{//mets:file[\@ID="$id"]/\@SIZE});
			$checksum = $lxc->findvalue(qq{//mets:file[\@ID="$id"]/\@CHECKSUM});
			$mime = $lxc->findvalue(qq{//mets:file[\@ID="$id"]/\@MIMETYPE});
			($fptr) = $lxc->findnodes(qq{//mets:fptr[\@FILEID="$id"]});
		} elsif ( $lxc->findvalue(qq(//mets:file[\@ID="thumbnail"]))) {
			$size =     $lxc->findvalue(qq{//mets:file[\@ID="thumbnail"]/\@SIZE});
			$checksum = $lxc->findvalue(qq{//mets:file[\@ID="thumbnail"]/\@CHECKSUM});
			$mime = $lxc->findvalue(qq{//mets:file[\@ID="thumbnail"]/\@MIMETYPE});
			($fptr) = $lxc->findnodes(qq{//mets:fptr[\@FILEID="thumbnail"]});
		}
		# grab X and Y for the file if they are in the old METS
		if ($fptr) {
			my $fptr_xc = XML::LibXML::XPathContext->new($fptr);
			$fptr_xc->registerNs('cdl','http://www.cdlib.org/');
			my $x = $fptr_xc->findvalue('@cdl:X');
			my $y = $fptr_xc->findvalue('@cdl:Y');
			if ($x && $y) {
				$imgsize->{$id} = [ $x, $y ];
			}
		}
		if ( ($mime eq "text/xml" or $mime eq "application/xml") && $regen) {
			#print "\nhello?!\n";
                        ## call xml processer
                        # will change $xc (reference to LibXML object)
                        $valid = processXML($xc, $cache, $file, $outfile, $ark, $objectBaseName, $filesBaseName)
                } else {
                        $valid = "no change";
                }

	}

        #if ( ($res->is_success) && ($res->code() ne "304") ) {
        if ( ($res->is_success) ) {
		#print "";
		## $xmlout set down below
		# SIZE is there a better way to get the size of a file?
		($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
                    $atime,$mtime,$ctime,$blksize,$blocks)
                        = stat($outfile);

		# CHECKSUM take the checksum
		open (CHK, "<$outfile");
		$sha2obj->addfile(*CHK);
		$checksum = $sha2obj->hexdigest();
		close(CHK);
		$sha2obj->reset();
		#print "$size $checksum\n";

		# record these headers, they will let us pretend like we are a cacheing
		# proxy server, and send conditional GETs next time we see this file
		$$cache->{$id}{'If_None_Match'} = $res->header('ETag');
    		$$cache->{$id}{'If_Last_Modified'} = $res->header('Last-Modified');


		# What is the MIME type? Content-type:
		# if I've just fetched an XML file, I need to see what it is;
		# validate it, and then fetch files that it needs
		$mime = $res->header('Content-type');
		# record the height and width (if its an image)
		if ($mime =~ m,^image/,) {
			# imgsize exported by Image::Size
			$imgsize->{$id} = [ imgsize($outfile) ];
			#print STDERR Dumper $imgsize->{$id};
			#print STDERR Dumper $outfile;
		}

		if ($mime eq "video/quicktime") {
			$imgsize->{$id} = [ qtvrsize($outfile) ];
		}

		if ($mime eq "text/xml" or $mime eq "application/xml") {
			## call xml processer
			# will change $xc (reference to LibXML object)
			$valid = processXML($xc, $cache, $file, $outfile, $ark, $objectBaseName, $filesBaseName)
		} else {
			$valid = "not XML";
		}

	} else {
		# print Dumper $res;
	}

	if ($valid) {
		return ($size, $checksum, $mime);
	} else {
		return (undef, undef, undef);
	}
}

sub processXML {
	my ($xc, $cacheInfo, $rfile, $file, $ark, $objectBaseName, $filesBaseName) = @_;
	## add new fileGrp to METS document
	my ($ffg) = $$xc->findnodes("/mets:mets/mets:fileSec/mets:fileGrp[1]");
	my $newGrp = XML::LibXML::Element->new("fileGrp");
	$newGrp->setNamespace("http://www.loc.gov/METS/");
	
	# validate here
	my $tei = $parser->parse_file("$rfile");
	
	## DTD validate it here
	#print STDERR "is valid: " , $tei->is_valid(), "\n";

	if (!($tei->is_valid()) && !($forgive_tei)){
		eval { $tei->validate(); };
		print $@;
	}

	for (stripTEI(\$tei, "$objectBaseName.xml")) {
		my ($id, $lfile) = @{$_};

		#compute local file name
        	$lfile =~ m,[^\.]*?\.([^\.]*)$,;
        	my $ext = $1;
  		#my $outfile = poi2text($ark);
        	my $outfile = "$filesBaseName-$id.$ext";

		my ($size, $checksum, $mime) = getFile($xc, $lfile, $outfile, $cacheInfo, $id, $objectBaseName, $filesBaseName);
		my $fileEl = XML::LibXML::Element->new("file");
		$fileEl->setNamespace("http://www.loc.gov/METS/");
		$fileEl->setAttribute("ID",$id);
		$fileEl->setAttribute("SIZE",$size);
		$fileEl->setAttribute("CHECKSUM",$checksum);
		$fileEl->setAttribute("CHECKSUMTYPE", "SHA-256");
		# also set mime type
		$fileEl->setAttribute("MIMETYPE", $mime);
		my $locat = XML::LibXML::Element->new("FLocat");
		$locat->setNamespace("http://www.loc.gov/METS/");
		$filesBaseName =~ m,files/([^/]*)$,;
		$locat->setAttribute("xlink:href", "files/$1-$id.$ext");
		#$locat->setAttribute("xlink:href", "$outfile");
		#print Dumper $fileEl;
		$fileEl->appendChild($locat);
		$newGrp->appendChild($fileEl);
	}
	
	$ffg->addSibling($newGrp);

	return 1;
	
}

sub stripTEI {
	#print Dumper @_;
	my ($tei, $file) = @_;
	## take out all the DTD stuff	
	my @out;
	my $dtd = $$tei->removeExternalSubset;
	$dtd = $$tei->removeInternalSubset;
	if ($dtd) {
		for ($dtd->childNodes) {
			my $entity = $_->toString;
			next if ($entity =~ m,<!ENTITY %,);
			$entity =~ m,<!ENTITY (.*) SYSTEM \"(http://.*)\" NDATA,;
			push @out, [ $1, $2 ];
		}
	}
	#print "$file";
	$$tei->toFile($file);
	#print "!$file\n";
	return unless ($dtd);
	return @out;
}

sub file2url {
	my ($file) = @_;
	$file =~ s,$localBase,$urlBase,;
	return $file;
}

sub poi2text {
        #print Dumper @_;
        my $poi = shift;
        $poi =~ s,[.|/],,g;
        my $dir = substr($poi, -2);
        $poi =~ s|ark:(\d\d\d\d\d)(.*)|$localBase/data/$1/$dir/$2/$2|;
        my $part = $2;
                if (! -e "$localBase/data/$1/$dir/$part" ) {
                        mkpath("$localBase/data/$1/$dir/$part");
                        mkpath("$localBase/data/$1/$dir/$part/files");
                }
        return "$poi";
}

# this figures out all the file names to composite, and creates the
# png files ... calls compThumb
sub compositeThumbnails {
	my ($root, $string, $base ) = @_;
	#print Dumper @_;
	# do some Xpath, get first 3 file nodes for thumbnails
	my $file1n = $$root->findvalue('(//mets:fileGrp[starts-with(@USE,"thumbnail") or @USE="image/thumbnail"])[1]/mets:file[1]/@ID');
	my $file2n = $$root->findvalue('(//mets:fileGrp[starts-with(@USE,"thumbnail") or @USE="image/thumbnail"])[1]/mets:file[2]/@ID');
	my $file3n = $$root->findvalue('(//mets:fileGrp[starts-with(@USE,"thumbnail") or @USE="image/thumbnail"])[1]/mets:file[3]/@ID');
	my $file1gif = "$base-$file1n.gif";
	my $file2gif = "$base-$file2n.gif";
	my $file3gif = "$base-$file3n.gif";
	# make png files out of the gif files.
	print STDERR `$gif2png_command $file1gif` if ($file1n && -e $file1gif);
	print STDERR `$gif2png_command $file2gif` if ($file2n && -e $file2gif);
	print STDERR `$gif2png_command $file3gif` if ($file3n && -e $file3gif);
	my $file1 = "$base-$file1n.png" if ($file1n && -e $file1gif);
	my $file2 = "$base-$file2n.png" if ($file2n && -e $file2gif);
	my $file3 = "$base-$file3n.png" if ($file3n && -e $file3gif);
	$file1 = "$base-$file1n.jpg" if (-e "$base-$file1n.jpg");
	$file2 = "$base-$file2n.jpg" if (-e "$base-$file2n.jpg");
	$file3 = "$base-$file3n.jpg" if (-e "$base-$file3n.jpg");

	#print "-------------\n$file1, $file2, $file3, $string\n";
	compThumb($file1, $file2, $file3, "$base-thumbnail.png", $string);
	## need to figure out the URL to reach $base-thumbnail.png !!!

	# update $$root to add new file element (and fileGrp??)
	my ($ffg) = $$root->findnodes("/mets:mets/mets:fileSec/mets:fileGrp[1]");
        my $newGrp = XML::LibXML::Element->new("fileGrp");
        $newGrp->setNamespace("http://www.loc.gov/METS/");

	my $newfile = XML::LibXML::Element->new("file");
        $newfile->setNamespace("http://www.loc.gov/METS/");
        $newfile->setAttribute("ID","thumbnail");
	my $locat = XML::LibXML::Element->new("FLocat");
	$locat->setNamespace("http://www.loc.gov/METS/");
	my $url = file2url("$base-thumbnail.png");
        $locat->setAttribute("xlink:href","$url" );
        $newfile->addChild($locat);
        $newGrp->addChild($newfile);
	$ffg->addSibling($newGrp);	
}

# take 3 png files and make a composite thumbnail
sub compThumb {
	my ($file1, $file2, $file3, $newF, $string) = @_;
	#print Dumper @_;
	my ($image1, $image2, $image3);
	if (-e $file1 && $file1 =~ m/png$/) { $image1 = GD::Image->newFromPng($file1) || die; }
	if (-e $file2 && $file2 =~ m/png$/) { $image2 = GD::Image->newFromPng($file2) || die; }
	if (-e $file3 && $file3 =~ m/png$/) { $image3 = GD::Image->newFromPng($file3) || die; }

	if (-e $file1 && $file1 =~ m/jpg$/) { $image1 = GD::Image->newFromJpeg($file1) || die; }
	if (-e $file2 && $file2 =~ m/jpg$/) { $image2 = GD::Image->newFromJpeg($file2) || die; }
	if (-e $file3 && $file3 =~ m/jpg$/) { $image3 = GD::Image->newFromJpeg($file3) || die; }

	# could trust these values from the METS file	
	# but didn't have acces to it in during test
	my ($W1,$H1) = $image1->getBounds() if ($image1);
	my ($W2,$H2) = $image2->getBounds() if ($image2);
	my ($W3,$H3) = $image3->getBounds() if ($image3);
	
	my $F1 = $W1;
	my $F2 = $W2;
	my $F3 = $W3;
	
	#print "$W1 $H1 : $F1 \n";
	#print "$W2 $H2 : $F2 \n";
	#print "$W3 $H3 : $F3 \n";
	
	$F1 = 170 unless ($W1 <= 170);
	$F2 = 170 unless ($W2 <= 170);
	$F3 = 170 unless ($W3 <= 170);
	
	#print "$W1 $H1 : $F1 \n";
	#print "$W2 $H2 : $F2 \n";
	#print "$W3 $H3 : $F3 \n";
	
	my $N1 = ($F1/$W1)*$H1 if ($W1);
	my $N2 = ($F2/$W2)*$H2 if ($W2);
	my $N3 = ($F3/$W3)*$H3 if ($W3);
	# width, height, width, height
	#print "$W1 $H1 : $F1 *$N1\n";
	#print "$W2 $H2 : $F2 $N2\n";
	#print "$W3 $H3 : * $F3 $N3\n";
	# F=W' N=H'
	my $x =  $F1;
	$x = $F2+15 if (($F2+15) > $x);
	$x = $F3+30 if (($F3+30) > $x);
	my $y =  $N1+45;
	$y = $N2+30 if (($N2+30) > $y);
	$y = $N3+15 if (($N3+15) > $y);
	#print "x $x, y $y \n";
	#my $im = new GD::Image(60,600);
	my $im = new GD::Image($x, $y);
	my $white = $im->colorAllocate(255,255,255);
	my $black = $im->colorAllocate(0,0,0);
	$im->transparent($white);

	#$image->copyResampled($sourceImage,$dstX,$dstY,
        #$srcX,$srcY,$destW,$destH,$srcW,$srcH)
	$im->copyResampled($image3, 30,  0,  0,  0,$F3,$N3,$W3,$H3) if ($image3);
	$im->copyResampled($image2, 15, 15,  0,  0,$F2,$N2,$W2,$H2) if ($image2);
	$im->copyResampled($image1,  0, 30,  0,  0,$F1,$N1,$W1,$H1) if ($image1);

	$im->string(gdSmallFont,2,($N1+30),"$string",$black);


    	#$im->stringFT($black,'/voro/local/fonts/realpol.ttf',10,0,2,($N1+40),
#                      "$count images ...",
#                      {linespacing=>0.6,
#                       charmap  => 'Unicode',
#                      });

	#$apricot = $myImage->colorClosest(255,200,180);

	open (NT, ">$newF");	
	binmode NT;
	print NT $im->png;
	close(NT);

}

sub mime2ext {
	my ($in) = @_;
	my $ext;
	if ($mime2ext{$in}) {
		$ext = $mime2ext{$in};
	} else {
		$in =~ m,/(.*),;
		$ext = $1;
	}
	return $ext;
}

sub addInfo {
	my ($xc) = @_;
	for ($xc->findnodes(qq{/mets:mets/mets:structMap//mets:fptr})) {
		my $fptrNode = $_;
		my $fileID = $fptrNode->findvalue('@FILEID');
		#print $fileID;
		if ($imgsize->{$fileID}) {
			$fptrNode->setAttribute("cdl:X", $imgsize->{$fileID}->[0]);
			$fptrNode->setAttribute("cdl:Y", $imgsize->{$fileID}->[1]);
		}
	}
	return $xc;
}

# -----
# Subroutine to return the width and height of a "qtvr" movie.
#
# Arguments:	1 - the string representation of the file's path name
#
# Returns:	on success, an array of length two, first array element is
#			the width, and the second array element is the height
#
#		on failure, an error message is printed on STDERR, and
#			"undef" is returned
#
# Author:	Michael A. Russell
#
# Revision History:
#		2007/3/2 - MAR - Initial writing.
#
sub qtvrsize {
	my $file = $_[0];

	# Name the command we'll use to decipher the info.
	my $info_cmd = "/voro/local/bin/oqtinfo";

	# If the command doesn't exist, or isn't executable, there's not
	# much we can do.
	unless (-e $info_cmd) {
		print STDERR "qtvrsize( ):  necessary command \"$info_cmd\" ",
			"does not exist\n";
		return;
		}
	unless (-x _) {
		print STDERR "qtvrsize( ):   necessary command \"$info_cmd\" ",
			"is not executable\n";
		return;
		}

	# Build the command we'll run.
	my $cmd = "$info_cmd $file";

	# Run the command on the specified file, and capture all the output.
	my $cmd_out = `$cmd 2>&1`;

	# Check the exit status.
	my $rc = int ($? / 256);

	# If it wasn't zero, then something is wrong.
	unless ($rc == 0) {
		print STDERR "qtvrsize( ):  command \"$cmd\" failed with ",
			"exit code $rc, the command's output follows:\n";
		print STDERR "$cmd_out\n";
		return;
		}

	# Search for "NNNxNNN" in the output.  We want to be sure that
	# there is one and only one such sequence in the output.
	my $width;
	my $height;
	my $second_search;
	if ($cmd_out =~ /^(.*) (\d+)x(\d+)\. depth (.*)$/s) {
		$second_search = "$1 $4";
		$width = $2;
		$height = $3;
		unless ($second_search =~ /^.* \d+x\d+\. depth .*$/s) {
			# The sequence occurs only once.  Return the
			# values we found.`
			return($width, $height);
			}

		# Tell the user we weren't sure which width and height
		# to return.
		print STDERR "qtvrsize( ):  the width and height appeared ",
			"to occur twice in the output of command \"$cmd\",\n";
		print STDERR "\tthe command's output follows:\n";
		print STDERR "$cmd_out\n";
		return;
		}

	print STDERR "qtvrsize( ):  unable to find width and height in the ",
		"output of command \"$cmd\", the command's output follows:\n";
	print STDERR "$cmd_out\n";
	return;
	}
