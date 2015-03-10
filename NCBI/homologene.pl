#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

sub main {
    my $usage = "Usage: perl homologene.pl [homologene.data]";
    
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

    # Read the homology file (found at ftp://ftp.ncbi.nih.gov/pub/HomoloGene/current/homologene.data)
    #
    #homologene.data is a tab delimited file containing the following
    #columns:
    
    #1) HID (HomoloGene group id)
    #2) Taxonomy ID
    #3) Gene ID
    #4) Gene Symbol
    #5) Protein gi
    #6) Protein accession
    print "Reading file...\n";
    open(IN,"<$fname") or die "Failed to open homology file $fname: $!\n";
    my %hom_map;
    while(<IN>) {
        chomp;
        my($hid,$tax_id,$gene_id,$gene_symbol,$p_gi,$p_ac) = split(/\t/,$_);
        if(!exists($hom_map{$hid})) {
            $hom_map{$hid} = [];
        }
        push(@{$hom_map{$hid}},$gene_id);
    }
    close IN;

    # Insert all the data we found
    print "Inserting data...\n";
    my $sth = $dbh->prepare("INSERT INTO homologs (h_group, entrez_id) VALUES (?, ?)");
    while ( my ($hid, $eids) = each %hom_map ) {
        foreach my $eid(@$eids) {
            $sth->execute($hid,$eid);
        }
    }

    print "Cleaning up bad Entrez IDs...\n";
    # Deal with bad Entrez IDs (seems no NCBI database is perfectly consistent)
    my $discontinued_query = <<EOF;
    SELECT entrez_id, missing.eid
    FROM discontinued_genes
    JOIN (
        SELECT DISTINCT homologs.entrez_id AS eid
        FROM homologs
        LEFT JOIN genes
        ON homologs.entrez_id = genes.entrez_id
        WHERE genes.entrez_id IS NULL
    ) AS missing
    ON discontinued_genes.discontinued_id = missing.eid;
EOF
    $sth = $dbh->prepare($discontinued_query);
    $sth->execute();
    my $update_query = $dbh->prepare("UPDATE homologs SET entrez_id = ? WHERE entrez_id = ?");
    while(my $row = $sth->fetch()) {
        $update_query->execute($row->[0],$row->[1]);
    }

    my $missing_query = <<EOF;
    SELECT homologs.entrez_id
    FROM homologs
    LEFT JOIN genes
    ON homologs.entrez_id = genes.entrez_id
    WHERE genes.entrez_id IS NULL;
EOF
    $sth = $dbh->prepare($missing_query);
    $sth->execute();
    my $delete_query = $dbh->prepare("DELETE FROM homologs WHERE entrez_id = ?");
    while(my $row = $sth->fetch()) {
        $delete_query->execute($row->[0]);
    }
}

main();
