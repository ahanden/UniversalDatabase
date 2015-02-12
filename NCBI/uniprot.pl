#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

sub main {
    my $usage = "Usage: perl uniprot.pl [gene2accession] [gene_refseq_uniprot_collab]";
    
    if(scalar(@ARGV) != 2){
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

    my ($file1,$file2) = @ARGV;
    my $dbh = DBI->connect("dbi:mysql:$db:localhost",$user,$password,
        {RaiseError => 1, AutoCommit => 0}) or die;

    eval {
        exec_main($dbh, $file1, $file2);
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
    my ($dbh, $g2a, $gruc) = @_;

    print "Parsing gene2accession file...\n";
    my %ncbi_map;
    open(IN,"<$g2a") or die "Failed to open $g2a: $!\n";
    while(<IN>) {
        my $line = $_;
        next if $line =~ m/^#/; # Skip comments
        next if $line !~ m/^9606\t/; # Skip non-humans

        chomp $line;
        
        my @terms = split(/\t/,$line);
        my $eid = $terms[1] eq "-" ? undef : $terms[1];
        my $pid = undef;
        if($terms[5] ne "-") {
            if($terms[5] =~ m/^(.*)\./){
                $pid = $1;
            }
            else{
                $pid = $terms[5];
            }
        }

        if(defined($eid) && defined($pid)) {
            if(!exists($ncbi_map{$pid})) {
                $ncbi_map{$pid} = {$eid=>1};
            }
            else {
                $ncbi_map{$pid}->{$eid} = 1;
            }
        }
    }
    close IN;


    print "Filling database...\n";
    my $sth = $dbh->prepare("INSERT IGNORE INTO gene_xrefs (entrez_id, Xref_db, Xref_id) VALUES (?, 'UniProt', ?)");
    open(IN,"<$gruc") or die "Failed to open $gruc: $!\n";
    while(<IN>){
        chomp;
        my ($pid,$uniprot) = split(/\t/,$_);
        if(exists($ncbi_map{$pid})) {
            foreach my $eid(keys(%{$ncbi_map{$pid}})){
                $sth->execute($eid,$uniprot);
            }
        }
    }
    close IN;
}

main();
