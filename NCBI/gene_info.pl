#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

sub main {
    my $usage = "Usage: perl gene_info.pl [gene_info]";
    
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
        print "Done inserting genes\n";
        exit 0;
    }
}

sub exec_main {
    my ($dbh, $fname) = @_;
    open my $IN, '<', $fname or die "Failed to open $fname: $!\n";

    print "Filling database. This may take several minutes...\n";

    my $genes_query    = $dbh->prepare("INSERT INTO genes (entrez_id, symbol, name, tax_id) VALUES (?, ?, ?, ?)");
    my $location_query = $dbh->prepare("INSERT IGNORE INTO gene_locations (entrez_id, map_location) VALUES (?, ?)");
    my $xref_query     = $dbh->prepare("INSERT IGNORE INTO gene_xrefs (entrez_id, Xref_db, Xref_id) VALUES (?, ?, ?)");
    my $synonym_query  = $dbh->prepare("INSERT IGNORE INTO gene_synonyms (entrez_id, symbol) VALUES (?, ?)");
    while (my $line = <$IN>) {
        next if $line =~ m/^#/;
        chomp $line;
        my @terms = split(/\t/,$line);

        my $tax         = $terms[0];
        my $id          = $terms[1];
        my @synonyms    = $terms[4] eq "-" ? () : split(/\|/,$terms[4]);
        my @xrefs       = $terms[5] eq "-" ? () : split(/\|/,$terms[5]);
        my @map_locs    = $terms[7] eq "-" ? () : split(/\|/,$terms[7]);
        my $symbol      = $terms[10] eq "-" ? undef : $terms[10];
        my $name        = $terms[11] eq "-" ? undef : $terms[11];
        if($terms[2] ne "-" && ($terms[10] eq "-" || $terms[2] ne $terms[10])) {
            push(@synonyms,$terms[2]);
        }

        $genes_query->execute($id,$symbol,$name,$tax);

        foreach my $location(@map_locs) {
            $location_query->execute($id,$location);
        }

        foreach my $xref(@xrefs) {
            $xref =~ /(.*):(.*)/;
            $xref_query->execute($id,$1,$2);
        }

        foreach my $synonym(@synonyms) {
            $synonym_query->execute($id,$synonym);
        }
    }
    close $IN;
}

main();
