package Comainu::Util;

use strict;
use warnings;
use utf8;

use Encode qw(encode_utf8 decode_utf8);
use Exporter 'import';

our @EXPORT_OK = qw(
    read_from_file write_to_file
);

sub read_from_file {
    my $file = shift;
    my $data = "";
    open( my $fh, $file ) or die "Cannot open '$file'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $data .= $line;
    }
    close($fh);
    $data = decode_utf8 $data;
    return $data;
}

sub write_to_file {
    my ($file, $data) = @_;
    $data = encode_utf8 $data;
    open(my $fh, ">", $file) or die "Cannot open '$file'";
    binmode($fh);
    print $fh $data;
    close($fh);
}

1;
