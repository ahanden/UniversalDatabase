#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

sub main {
    my $usage = "Usage: perl gene_history.pl [gene_history]";
    
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

    my $sth = $dbh->prepare("INSERT INTO discontinued_genes (entrez_id, discontinued_id, discontinued_symbol) VALUES (?, ?, ?)");
    while (my $line = <$IN>) {
        next if $line =~ m/^#/; # discard comments
        next if $line !~ m/^9606\t/; #ignore non-human genes

        chomp $line;
        my @terms = split(/\t/,$line);

        my $id          = $terms[1] eq "-" ? undef : $terms[1];
        my $dis_id      = $terms[2] eq "-" ? undef : $terms[2];
        my $dis_symbol  = $terms[3] eq "-" ? undef : $terms[3];

        if($id) {
            $sth->execute($id,$dis_id,$dis_symbol);
        }
    }
    close $IN;
}

main();
