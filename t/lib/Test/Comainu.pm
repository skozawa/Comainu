package Test::Comainu;

use strict;
use warnings;
use utf8;

use Exporter qw(import);
use File::Temp;
use Encode;
use Test::Mock::Guard;

our @EXPORT = qw(
    create_tmp_file
    guard_write_to_file
    read_from_file
);

sub create_tmp_file {
    my $data = shift;

    my $fh   = File::Temp->new;
    my $file = $fh->filename;
    print $fh encode_utf8 $data;
    close $fh;

    return ($file, $fh);
}

sub guard_write_to_file {
    my ($pkg, $data) = @_;

    mock_guard($pkg, {
        write_to_file => sub {
            my ($tmp_file, $buff) = @_;
            $$data = $buff;
        }
    });
}

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


1;
