package Comainu::Util;

use strict;
use warnings;
use utf8;

use Encode qw(encode_utf8 decode_utf8);
use Exporter 'import';

our @EXPORT_OK = qw(
    read_from_file
    write_to_file
    check_file
    get_dir_files
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
    $data = encode_utf8 $data if Encode::is_utf8 $data;
    open(my $fh, ">", $file) or die "Cannot open '$file'";
    binmode($fh);
    print $fh $data;
    close($fh);
    undef $data;
}

sub check_file {
    my $file = shift;
    unless ( -f $file ) {
        printf(STDERR "Error: '%s' not Found.\n", $file);
        die;
    }
}

sub get_dir_files {
    my ($target, $ext) = @_;
    if ( -f $target ) {
        return [ $target ];
    } elsif ( -d $target ) {
        my $files = [];
        opendir(my $dh, $target);
        while ( my $file = readdir($dh) ) {
            push @$files, $file if $file =~ /\.$ext$/;
        }
        closedir($dh);
        return $files;
    }
}

1;
