#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;
use IO::Handle;

my ($synonym_query, $discontinued_query, $basic_query, %gene_cache);
STDOUT->autoflush(1);

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


    $basic_query = $dbh->prepare("SELECT entrez_id FROM genes WHERE symbol = ?");
    $synonym_query = $dbh->prepare("SELECT entrez_id FROM gene_synonyms WHERE symbol = ?");
    $discontinued_query = $dbh->prepare("SELECT entrez_id FROM discontinued_genes WHERE discontinued_symbol = ?");

    eval {
        exec_main($dbh, $fname);
    }

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
    my @data;
    my %symbols;
    open(IN,"<$fname") or die "Failed to open $fname: $!\n";
    while(<IN>){
        chomp;
        my @fields = split("\t",$_);
        my $pubmed = $fields[1];
        my $trait = $fields[7];
        my $gene = $fields[13];
        if($gene && $gene !~ m/intergenic/i && $gene ne 'NR' && $trait) {
            my @genes = split(/,\s*/,$gene);
            foreach $gene(@genes) {
                chomp $gene;
                $symbols{$gene} = 1;
                push(@data,[$pubmed, $trait, $gene]);
            }
        }
    }
    close IN;

    foreach my $symbol(keys(%symbols)) {
        get_eid($dbh,$symbol);
    }
    print "\n";

    my $sth = $dbh->prepare("INSERT IGNORE INTO gwas (pubmed_id,trait,entrez_id) VALUES (?, ?, ?)");

    foreach my $entry(@data) {
        my $eid = $gene_cache{$entry->[2]};
        if($eid) {
            $sth->execute($entry->[0],$entry->[1],$eid);
        }
    }
    print "\n";

    print "Filling database. This may take several minutes...\n";
}

sub get_eid {
    my($dbh,$symbol) = @_;
    $basic_query->execute($symbol);
    my $eid = $basic_query->fetch();
    if(!$eid) {
        $synonym_query->execute($symbol);
        $eid = $synonym_query->fetch();
        if(!$eid) {
            $discontinued_query->execute($symbol);
            $eid = $discontinued_query->fetch();
        }
    }
    $gene_cache{$symbol} = $eid->[0];
}

main();
