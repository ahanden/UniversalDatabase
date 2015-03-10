#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

#
# The names.dmp is contained in a tarball.
# The tarball can be found at ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
# To extract the names file, run
#     tar -xvzf taxdump.tar.gz names.dmp
#

sub main {
    my $usage = "Usage: perl tax_names.pl [names.dmp]";
    
    if(scalar(@ARGV) != 1){
        print "$usage\n";
        exit;
    }
    
    ReadMode 1;
    print "dbname: ";
    my $db = <STDIN>;
    chomp $db;
    ReadMode 1;
    print "username: ";
    my $user = <STDIN>;
    chomp $user;
    ReadMode 2;
    print "password: ";
    my $password = <STDIN>;
    print "\n";
    chomp $password;
    ReadMode 1;

    my $fname = $ARGV[0] || die $usage;
    my $dbh = DBI->connect("dbi:mysql:$db:localhost",$user,$password,
        {RaiseError => 1, AutoCommit => 0}) or die;

    eval {
        exec_main($dbh, $fname);
    };

    if ($@) {
        print "Error encountered: rolling back changes.\n";
        $dbh->rollback();
        exit 1;
    }
    else {
        $dbh->commit();
        print "Done.\n";
        exit 0;
    }
}

sub exec_main {
    my ($dbh, $fname) = @_;
    open my $IN, '<', $fname or die "Failed to open $fname: $!\n";

    print "Populating database...\n";

    my $sth = $dbh->prepare("INSERT INTO taxonomies (tax_id, name) VALUES (? ,?)");
    
    while (my $line = <$IN>) {
        next if $line =~ m/^#/;
        chomp $line;
        my ($tax_id, $name, $unique, $class) = split(/\t\|\t/,$line);
        $class =~ s/\t\|$//;
        if($class eq "scientific name") {
            $sth->execute($tax_id,$name);
        }
    }
    close $IN;
}

main();
