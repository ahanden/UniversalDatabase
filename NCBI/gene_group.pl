#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

sub main {
    my $usage = "Usage: perl gene_group.pl [gene_group]";
    
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
        print "Done inserting data\n";
        exit 0;
    }
}

sub exec_main {
    my ($dbh, $fname) = @_;
    open my $IN, '<', $fname or die "Failed to open $fname: $!\n";

    print "Filling database...\n";

    my $sth = $dbh->prepare("INSERT INTO orthologs (human_id, ortholog_id, ortholog_taxonomy) VALUES (?, ?, ?)");
    while (my $line = <$IN>) {
        next if $line =~ m/^#/; # skip comments
        next if $line !~ m/(^|\t)9606\t/; # skip non-human ortholog sets
        next if $line =~ m/^9606\t.*\t9606\t/; # skip human-human orthologs
        next if $line !~ m/Ortholog/; # only look at orthologs

        chomp $line;
        my ($tax1,$eid1,$rel,$tax2,$eid2) = split(/\t/,$line);

        if($tax1 eq '9606') {
            $sth->execute($eid1,$eid2,$tax2);
        }
        else {
            $sth->execute($eid2,$eid1,$tax1);
        }

    }
    close $IN;
}

main();
