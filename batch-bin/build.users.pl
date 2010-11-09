use BerkeleyDB ;
use Fcntl;
use MLDBM qw(DB_File Storable) ;
use File::Path;

my $home = $ENV{'HOME'};
my ($userref, $groupref, $gdirsref) = parseTabFiles();

#NOTE: the update_voroEAD.py script parses the DAV.conf
#NOTE: it may be problem when changing the DAV.conf


mkpath("$home/users/apache");

open (OUT, ">$home/users/apache/DAV.conf");
print OUT apacheconf($groupref, $gdirsref);
close (OUT);

open (OUT, ">$home/users/apache/groups");
print OUT apachegroups($userref, $groupref);
close (OUT);

userbdb($userref);


sub userbdb {
	my $filename = "$home/users/apache/test.user.bdb";
	my ($userref) = @_;
	my %tmpu = %{$userref};
	my %out;
	my $db = tie (%out, "MLDBM", "$filename",  O_CREAT | O_RDWR, 0644);
	%out = %tmpu;
	$db->sync;
 	untie %out;
}


sub apachegroups{
	my $out;
	# make up group file for basic authentecation
	#print Dumper @_;
	my ($userref, $groupref) = @_;
	
	my %tmpg = %{$groupref};
	for (keys %tmpg) {
		$out .= "$_: ";
		#print Dumper  $tmpg{$_}->{who};
		$out .= join(" ", @{$tmpg{$_}->{who}});
		$out .= "\n";
	}
	return $out;
}


sub apacheconf {
	# make up apache config for basic authentication in webDAV
	#print Dumper @_;
	my $out;
	my ($t, $gdirsref) = @_;
	my %tmp = %{$t};
	#print Dumper %tmp;
	#Eprint $t{clsu}
	for (keys %tmp) {
		#print Dumper $tmp{$_};
		$out .= apachelocation($_, $tmp{$_}, $gdirsref)
	}
	return $out;
}

sub apachelocation {
	#print Dumper @_;
	my ($group, $gref, $gdirsref) = @_;
	my $directory = $gref->{dir};
	my $supergroup = $gref->{supergroup};
	my $altgroup;
	if ($supergroup) {
		$altgroup = $gdirsref->{$supergroup};
	}
	my $out=<<EOF;
<Directory $home/data/in/oac-ead/submission/$directory>
	<LimitExcept OPTIONS GET>
	require group $group $altgroup caoiucdl
	</LimitExcept>
</Directory>
<Directory $home/workspace/test-oac/submission/$directory>
	<LimitExcept OPTIONS GET>
	require group $group $altgroup caoiucdl
	</LimitExcept>
</Directory>
<Directory $home/data/oac-ead/in/marc/$directory>
	<LimitExcept OPTIONS GET>
	require group $group $altgroup caoiucdl
	</LimitExcept>
</Directory>
<Directory $home/data/oac-ead/in/user-pdf/$directory>
	<LimitExcept OPTIONS GET>
	require group $group $altgroup caoiucdl
	</LimitExcept>
</Directory>
EOF

	return $out;
}


sub parseTabFiles {

	my %users;
	my %groups;
	my %gdirs;

	my $userfile = "$home/users/in/voro.users.txt";
	my $groupfile = "$home/users/in/voro.groups.txt";


	open (USER , "<$userfile") || die ("$! $_ $userfile");
	open (GROUP , "<$groupfile") || die ("$! $_ $groupfile");

	while (<GROUP>) {
        next if ( m/^#/ );
		chomp;
#webDAV group    Dynaweb directory   Main Institution^M
        my ($group, $dir, $institution) = split /\t/;
		next unless ($group);
		$institution =~ s,\c[m]$,,;
		my $sg;
		if ( $dir =~ m,^(.*)/, ) {
			$sg = $1;
		}
		$groups{$group} = { 
			dir => $dir, 
			institution => $institution ,
			who => [] ,
			supergroup=> $sg,
			};	
		$gdirs{$dir} = $group;
	}

	while (<USER>) {
        next if ( m/^#/ );
        chomp;
#webDAV user    webDAV group    Primary Contact Name    Primary Contact Email   Primary Cont act Phone^
        my ($user, $groupin, $name, $email, $phone) = split /\t/;
		next unless ($user);
		@groups = split (/,/ , $groupin);
		my $group = $groups[0];
        $phone =~ s,^",,;
        $phone =~ s,^\s*,,;
        $phone =~ s,\s*$,,;
        $phone =~ s,"$,,;
        $phone =~ s,\s*$,,;
		my @dirs;
		for (@groups) {
			push @dirs, $groups{$_}{dir}
		}
		my $start_dir;
		my $dir_count = @dirs;
		$start_dir = $groups{$group}{dir};

		for (@dirs) {
			if (m,/,) {
				my $foo = $_;
				$foo =~ s,/.*$,,;
				$start_dir = $foo;
			}
		}

		$users{$user} = { name => $name,
							group => $group,
							dir => $start_dir,
							dirs => [ @dirs ] ,
							institution => "$groups{$group}{institution}",
							email => $email,
							phone => $phone, };
		for (@groups) {
			push @{$groups{$_}{who}}, $user;
		}
		#print Dumper $users{$user};
		
	}

	return \%users, \%groups, \%gdirs;


}
