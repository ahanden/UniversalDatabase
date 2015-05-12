# UniversalDatabase
Compiled data from external biological datbases, including NCBI, REACTOME, and DrugBank, among others.

## Dependencies
MySQL and Perl and required.

For Perl, the following packages are necessary
* DBI
* GetOpt::Long
* IO::Handle
* Term::ReadKey
* XML::Parser

The update.sh script is also dependant on the following Unix utilities:
* gunzip
* tar
* unzip
* wget

## Installation
If installing or updating the database, just run update.sh
