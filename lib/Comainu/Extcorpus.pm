# migrated from extcorpus.pl
package Comainu::Extcorpus;
use strict;
use warnings;
use utf8;
use DBI;
use Encode;

use constant {
    NULL_STRING => '*',
    INPUT_DELIMITER => "\t",
    OUTPUT_DELIMITER => "\t",
    INPUT_EOS_STRING => 'EOS',
    OUTPUT_EOS_STRING => 'EOS',

    INPUT_FIELDS => ['sLabel', 'orth', 'pron', 'lForm', 'lemma', 'pos', 'cType', 'cForm'],
    INPUT_OPTIONAL_FIELDS => ['cType', 'cForm'],
    OUTPUT_FIELDS => ['sLabel', 'orth', 'pron', 'lForm', 'lemma', 'pos', 'cType', 'cForm', 'goshu', 'form', 'formBase', 'formOrthBase', 'formOrth'],
    OUTPUT_OPTIONAL_FIELDS => ['cType', 'cForm'],
    KEY_FIELDS => ['lForm', 'lemma', 'pos', 'cType', 'cForm', 'orth', 'pron'],
};

sub new {
    my ($class, %args) = @_;
    bless { use_cache => 1, %args }, $class;
}

sub cache {
    my ($self, $inputs, $outputs) = @_;
    return unless $self->{use_cache};
    my $cache_key = $self->cache_key($inputs);
    $self->{_cache}->{$cache_key} = $outputs if $outputs;
    $self->{_cache}->{$cache_key};
}

sub cache_key {
    my ($self, $inputs) = @_;
    return join ';', map { $inputs->{$_} } sort keys %$inputs;
}

sub dbh {
    my $self = shift;
    $self->{_dbh} ||= DBI->connect("dbi:SQLite:dbname=" . $self->{'unidic-db'}, undef, undef,  {
        AutoCommit => 0,
        RaiseError => 1,
    });
}

sub disconnect {
    my $self = shift;
    return unless $self->{_dbh};
    $self->{_dbh}->disconnect || warn $!;
    $self->{_dbh} = undef;
}

sub run {
    my ($self, $input_file) = @_;

    open(my $fh_input, '<', $input_file) or die "Cannot open '$input_file'";

    my $buff = '';
    while ( my $line = <$fh_input> ) {
        $line =~ s/\r?\n//;

        next if $line =~ /^\#/;

        if ( $line eq INPUT_EOS_STRING ) {
            $buff .= OUTPUT_EOS_STRING . "\n";
            next;
        }

        my $inputs = $self->_parse_input($line);
        my $outputs = $self->search_outputs($inputs);

        $buff .= join(OUTPUT_DELIMITER, map { $outputs->{$_} } @{OUTPUT_FIELDS()}) . "\n";
    }

    close($fh_input);

    return decode_utf8 $buff;
}

sub _parse_input {
    my ($self, $line) = @_;
    my $inputs = {};
    my @input_values = split INPUT_DELIMITER, $line;
    for my $i ( 0 .. scalar @input_values - 1 ) {
        next unless INPUT_FIELDS->[$i];
        $inputs->{INPUT_FIELDS->[$i]} = $input_values[$i];
    }

    $inputs->{$_} //= NULL_STRING for @{INPUT_FIELDS()};
    foreach my $key ( @{INPUT_OPTIONAL_FIELDS()} ) {
        $inputs->{$key} = NULL_STRING if $inputs->{$key} eq '';
    }

    return $inputs;
}

sub search_outputs {
    my ($self, $inputs) = @_;
    my $res = $self->cache($inputs) || $self->select_from_db($inputs);
    my $outputs = { %$inputs, %$res };
    $outputs->{$_} //= NULL_STRING for @{$self->select_fields};
    foreach my $key ( @{OUTPUT_OPTIONAL_FIELDS()} ) {
        $outputs->{$key} = '' if $outputs->{$key} eq NULL_STRING;
    }

    return $outputs;
}

sub select_from_db {
    my ($self, $inputs) = @_;
    my $select_fields = join ',', @{$self->select_fields};
    my $where = join ' AND ', map { "$_=?" } @{KEY_FIELDS()};
    my $query = sprintf('SELECT %s FROM lex WHERE %s', $select_fields, $where);
    my @values = map { $inputs->{$_} } @{KEY_FIELDS()};

    my $sth = $self->dbh->prepare_cached($query);
    my $res = $self->dbh->selectall_arrayref($sth, { Slice => {} }, @values);

    print STDERR "Warning: key is not unique for <@values>\n" if @$res > 1;

    $self->cache($inputs, @$res ? $res->[0] : {});

    return {} unless @$res;
    return $res->[0];
}

sub select_fields {
    my $self = shift;
    $self->{_select_fields} ||= do {
        my %diff;
        $diff{$_}++ for @{OUTPUT_FIELDS()};
        delete $diff{$_} for @{INPUT_FIELDS()};

        [ keys %diff ];
    };
}

sub DESTROY {
    my $self = shift;
    $self->{_cache} = undef;
    $self->disconnect;
}

1;
