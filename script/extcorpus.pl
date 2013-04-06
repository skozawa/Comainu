#!/usr/bin/perl -w
# ----------------------------------------------------------------------
# $Id: extcorpus.pl 12 2013-01-24 13:56:24Z den $
# extends morph information in a corpus with consulting the database
# Copyright (c) 2011 The UniDic consortium. All rights reserved.
# ----------------------------------------------------------------------
use strict;
use Getopt::Long;
use DBI;

# ----------------------------------------------------------------------
my $myself = $0;
my ($dirname,$basename) = ($myself =~ /(.*)\/(.*)/);

# ----------------------------------------------------------------------
# Process command line args
# ----------------------------------------------------------------------
my $ConfigFile = "corpus.def";
my $NullString = "*";
my $InDelimiter = "\t";
my $OutDelimiter = "\t";
my $InEOSString = "EOS";
my $OutEOSString = "EOS";

my $usage_msg = "usage: $basename [Options] wordsFile
  where Options are
    -C Path	Path of the configuration file [default=$ConfigFile]
    -n Name	String for the null value [default=$NullString]
    --input-delimiter=Name
		Field delimiter for the input file [default=$InDelimiter]
    --output-delimiter=Name
		Field delimiter for the output file [default=$OutDelimiter]
    --input-eos=Name
		EOS string for the input file [default=$InEOSString]
    --output-eos=Name
		EOS string for the output file [default=$OutEOSString]\n";

sub usage
{
    die $usage_msg;
}

my $help;

GetOptions('C=s' => \$ConfigFile,
	   'n=s' => \$NullString,
	   'input-delimiter=s' => \$InDelimiter,
	   'output-delimiter=s' => \$OutDelimiter,
	   'input-eos=s' => \$InEOSString,
	   'output-eos=s' => \$OutEOSString,
	   'h'   => \$help);

usage
    if $help;

# ----------------------------------------------------------------------
# Read configuration file
# ----------------------------------------------------------------------
my %config;

open(FILE, $ConfigFile) ||
    die "Error: can't open config file `$ConfigFile'\n";

while (<FILE>) {
    s/\x0D?\x0A?$//;

    next
	if /^\#/;

    $config{$1} = $2
        if /^(.*?):\s*(.*)/;
}

close(FILE);

# Check if all the required variables have been specified
my @required = ('dbfile','table','input','output','key');

foreach my $name (@required) {
    die "Error: [$name] is required\n"
	unless defined $config{$name};
}

# ----------------------------------------------------------------------
# Functions
# ----------------------------------------------------------------------
# Function: set difference
sub setdiff
{
    my ($ref_set1,$ref_set2) = @_;
    my %tmp;

    foreach my $element (@$ref_set1) {
	$tmp{$element} = 1;
    }
    foreach my $element (@$ref_set2) {
	delete $tmp{$element};
    }

    return keys %tmp;
}

# ----------------------------------------------------------------------
# Variables
# ----------------------------------------------------------------------
# Key fields: List of key field names to be used in a query
my @keyFields = split(/,/, $config{'key'});

# Input fields: List of input field names
my $re_input = $config{'input'};
$re_input =~ s/\?/\\?/g;
$re_input =~ s/\w+/(.*?)/g;
$re_input =~ s/\[/(?:\\[/g;
$re_input =~ s/\]/\\])?/g;

my @inputFields = ($config{'input'} =~ /^$re_input$/);

# Omissible input fields: List of input fields whose values can be empty
my $re_input2 = $config{'input'};
$re_input2 =~ s/\?/\\?/g;
$re_input2 =~ s/\[/\\[/g;
$re_input2 =~ s/\]/\\]/g;
$re_input2 =~ s/\w+(?=\\\?)/(.*?)/g;

my @inputFields2 = ($config{'input'} =~ /^$re_input2$/);
@inputFields2 = ()
    if @inputFields2 == 1 && $inputFields2[0] eq 1;

# Input pattern: Regex against which an input line is matched
my $inputPattern = $config{'input'};
$inputPattern =~ s/,/$InDelimiter/g;
$inputPattern =~ s/\?//g;
$inputPattern =~ s/\w+/(.*?)/g;
$inputPattern =~ s/\[/(?:/g;
$inputPattern =~ s/\]/)?/g;

# Check if all the key fields are included in the input fields
my @missing = setdiff(\@keyFields, \@inputFields);

die "Error: fields `@missing' are not in the input fields\n"
    if @missing;

# Output fields: List of output field names
my $re_output = $config{'output'};
$re_output =~ s/\?/\\?/g;
$re_output =~ s/\w+/(.*?)/g;
$re_output =~ s/\[/(?:\\[/g;
$re_output =~ s/\]/\\])?/g;

my @outputFields = ($config{'output'} =~ /^$re_output$/);

# Omissible output fields: List of output fields whose values can be empty
my $re_output2 = $config{'output'};
$re_output2 =~ s/\?/\\?/g;
$re_output2 =~ s/\[/\\[/g;
$re_output2 =~ s/\]/\\]/g;
$re_output2 =~ s/\w+(?=\\\?)/(.*?)/g;

my @outputFields2 = ($config{'output'} =~ /^$re_output2$/);
@outputFields2 = ()
    if @outputFields2 == 1 && $outputFields2[0] eq 1;

# Output string: String to be produced as an output line
my $outputString = $config{'output'};
$outputString =~ s/,/."$OutDelimiter"./g;
$outputString =~ s/\?//g;
$outputString =~ s/(\w+)/\$_{"$1"}/g;
$outputString =~ s/\[([^\$]+)/._f("$1",/g;
$outputString =~ s/\]/)/g;

# Auxiliary function used in the output string
sub _f { $_[1] eq $NullString ? '' : $_[0] . $_[1] }

# Fields to be retrieved from the database
my @returnFields = setdiff(\@outputFields, \@inputFields);

# Fields to be copied from the input fields
my @copyFields = setdiff(\@outputFields, \@returnFields);

# Query string
my $where = "";
$where = "WHERE " . join(" AND ", map { "$_=?" } @keyFields)
    if @keyFields;
my $queryString = "";
$queryString = sprintf("SELECT %s FROM %s %s",
		       join(',', @returnFields), $config{'table'}, $where)
    if @returnFields;

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
my $dbh = DBI->connect("dbi:SQLite:dbname=$config{'dbfile'}", undef, undef,
		       {
			   AutoCommit => 0,
			   RaiseError => 1,
		       });
my %cache;

while (<>) {
    s/\x0D?\x0A?$//;

    # Comment line
    if (/^\#/) {
	print $_,"\n";

	next;
    }
    # EOS line
    if (/^$InEOSString$/) {
	print $OutEOSString,"\n";

	next;
    }

    # Parse input
    my %input;
    my @inputValues = ($_ =~ /^$inputPattern$/);
    for (my $i = 0; $i < @inputValues; $i ++) {
	$inputValues[$i] = $NullString
	    unless defined $inputValues[$i];
    }
    @input{@inputFields} = @inputValues;

    # Check if an omissible input field has an empty value
    foreach my $field (@inputFields2) {
	$input{$field} = $NullString
	    if $input{$field} eq '';
    }

    # Produce output
    my %output;
    # 1. by sending a query to the database
    if ($queryString ne "") {
	my @values = map { $input{$_} } @keyFields;

	# consult the cache
	if (defined(my $cached = $cache{join($;, @values)})) {
	    # if cached, restore the cached result
	    %output = split($;, $cached);
	} else {
	    # otherwise, issue a query,
	    my $sth = $dbh->prepare_cached($queryString);
	    my $ref_outputs = $dbh->selectall_arrayref($sth, { Slice => {} }, @values);

	    print STDERR "Warning: key is not unique for <@values>\n"
		if @$ref_outputs > 1;

	    if (defined $ref_outputs->[0]) {
		%output = %{$ref_outputs->[0]};
	    }
	    foreach my $rf (@returnFields) {
		$output{$rf} = $NullString
		    unless defined $output{$rf};
	    }

	    # and record the result
	    my @cached = ();
	    while (my ($key,$value) = each(%output)) {
		# ... wasting a memory
		push(@cached, join($;, $key,$value));
	    }
	    $cache{join($;, @values)} = join($;, @cached);
	}
    }
    # 2. by coping from the input line
    foreach my $field (@copyFields) {
	$output{$field} = $input{$field};
    }

    # Check if an omissible output field should have an empty value
    foreach my $field (@outputFields2) {
	$output{$field} = ''
	    if $output{$field} eq $NullString;
    }

    # Print output
    %_ = %output;
    print eval($outputString),"\n";
}

$dbh->disconnect || warn $!;

# ----------------------------------------------------------------------
1;
