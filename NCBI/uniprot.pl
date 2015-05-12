#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

sub main {
    my $usage = "Usage: perl uniprot.pl [gene2accession] [gene_refseq_uniprot_collab]";
    my $updater = myUpdate->new("usage" => $usage);
    $updater->update();
}


{
    BEGIN {
        unshift(@INC,'/home/adam/UniversalDatabase/');
    }
    package myUpdate;
    use base ("Update");
    use Getopt::Long;

    sub checkArgs {
        my $self = shift;

        my $verbose = 0;
        if(GetOptions('verbose' => \$verbose) && @ARGV == 2) {
            $self->{verbose} = $verbose;
            $self->{g2a} = $ARGV[0];
            $self->{gruc} = $ARGV[1];
            return 1;
        }
        return 0;
    }

    sub exec_main {
        my $self = shift;

        $self->log("Parsing gene2accession file...\n");
        my %ncbi_map;
        open(IN,"<$self->{g2a}") or die "Failed to open $self->{g2a}: $!\n";
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


        $self->log("Filling database...\n");
        my $sth = $self->{dbh}->prepare("INSERT IGNORE INTO gene_xrefs (entrez_id, Xref_db, Xref_id) VALUES (?, 'UniProt', ?)");
        open(IN,"<$self->{gruc}") or die "Failed to open $self->{gruc}: $!\n";
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
        $self->log("Done\n");
    }
}

main();
