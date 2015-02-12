#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

sub main {
    my $usage = "Usage: perl psi-mi_cv.pl [psi-mi25.obo]";
    
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
        print "Done\n";
        exit 0;
    }
}

sub exec_main {
    my ($dbh, $fname) = @_;
    open my $IN, '<', $fname or die "Failed to open $fname: $!\n";

    print "Populating database tables...\n";

    my $term_query = $dbh->prepare("INSERT INTO psi_terms (psi_id, name) VALUES (?, ?)");
    my $tree_query = $dbh->prepare("INSERT INTO psi_tree  (psi_id, is_a) VALUES (?, ?)");
    while (my $line = <$IN>) {
        next if $line !~ m/^\[Term\]/; # Skip to first entry

        my ($id,$name,@is_a);

        do {
            $line = <$IN>;
            chomp $line;
            if($line =~ m/^id: (MI:\d{4})/){
                $id = $1;
            }
            elsif($line =~ m/^name: (.*)$/){
                $name = $1;
            }
            elsif($line =~ m/^is_a: (MI:\d{4})/){
                push(@is_a,$1);
            }
        } while($line);
        $term_query->execute($id, $name);
        foreach my $term(@is_a) {
            $tree_query->execute($id,$term);
        }
    }
    close $IN;
}

main();
