#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

sub main {
    # Usage string
    my $usage = "Usage: perl gene2go.pl [gene2go]";
    
    # Check arguments
    if(scalar(@ARGV) != 1){
        print "$usage\n";
        exit;
    }
    my $fname = $ARGV[0] || die $usage;
    
    # Read database credentials
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

    # Connect to the database
    my $dbh = DBI->connect("dbi:mysql:$db:localhost",$user,$password,
        {RaiseError => 1, AutoCommit => 0}) or die;

    # Run the true main method
    eval {
        exec_main($dbh, $fname);
    };

    # Rollback changes if there are errors
    if ($@) {
        print "Error encountered: rolling back changes.\n";
        $dbh->rollback();
        exit 1;
    }
    # Or commit the changes if we're error free
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

    # Inserts an entry to annotate a gene with a GO term
    my $annotation_query = $dbh->prepare("INSERT IGNORE INTO go_annotations (entrez_id, go_id) VALUES (?, ?)");
    # Inserts the details of the GO term
    my $term_query = $dbh->prepare("INSERT IGNORE INTO go_terms (go_id, go_term, category) VALUES (?, ?, ?)");

    # Start parsing the file
    while (my $line = <$IN>) {
        next if $line =~ m/^#/; # skip comments
        next if $line !~ m/^9606\t/; # skip non-human genes

        chomp $line;
        my @terms = split(/\t/,$line);

        my $eid       = $terms[1];
        my $go_id     = $terms[2];
        # my $evidence  = $terms[3]; # Not currently used
        my $qualifier = $terms[4];
        my $go_term   = $terms[5];
        my $category  = $terms[7];

        # Necessary conditional for not adding annotations
        # with the NOT qualifier (which is not always written properly)
        if($qualifier !~ m/not/i) {
            $annotation_query->execute($eid,$go_id);
            $term_query->execute($go_id, $go_term, $category);
        }
    }
    close $IN;
}

main();
