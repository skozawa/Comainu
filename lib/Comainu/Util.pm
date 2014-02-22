package Comainu::Util;

use strict;
use warnings;
use utf8;

use Config;
use File::Temp qw(tempfile);
use Encode qw(encode_utf8 decode_utf8);
use Exporter 'import';

our @EXPORT_OK = qw(
    any
    read_from_file
    write_to_file
    check_file
    get_dir_files
    proc_stdin2stdout
    proc_stdin2file
    proc_file2stdout
    proc_file2file
);

# from List::MoreUtils
sub any (&@) {
    my $f = shift;
    foreach ( @_ ) {
        return 1 if $f->();
    }
    return 0;
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
            push @$files, $target . "/" . $file if $file =~ /\.$ext$/;
        }
        closedir($dh);
        return $files;
    }
}

sub proc_stdin2stdout {
    my ($proc, $in_data, $tmp_dir, $file_in_p) = @_;
    my $out_data = "";
    my ($tmp_in_fh, $tmp_in)   = $tmp_dir ? tempfile(DIR => $tmp_dir) : tempfile;
    my ($tmp_out_fh, $tmp_out) = $tmp_dir ? tempfile(DIR => $tmp_dir) : tempfile;
    close($tmp_in_fh);
    close($tmp_out_fh);
    write_to_file($tmp_in, $in_data);
    proc_file2file($proc, $tmp_in, $tmp_out, $file_in_p);
    $out_data = read_from_file($tmp_out);
    unlink($tmp_in);
    unlink($tmp_out);
    undef $in_data;
    return $out_data;
}

sub proc_stdin2file {
    my ($proc, $in_data, $out_file, $tmp_dir, $file_in_p) = @_;
    my ($tmp_in_fh, $tmp_in) = $tmp_dir ? tempfile(DIR => $tmp_dir) : tempfile;
    write_to_file($tmp_in, $in_data);
    proc_file2file($proc, $tmp_in, $out_file, $file_in_p);
    unlink($tmp_in);
    undef $in_data;
}

sub proc_file2stdout {
    my ($proc, $in_file, $tmp_dir, $file_in_p) = @_;
    my ($tmp_out_fh, $tmp_out) = $tmp_dir ? tempfile(DIR => $tmp_dir) : tempfile;
    close($tmp_out_fh);
    proc_file2file($proc, $in_file, $tmp_out, $file_in_p);
    my $out_data = read_from_file($tmp_out);
    unlink($tmp_out);
    return $out_data;
}

sub proc_file2file {
    my ($proc, $in_file, $out_file, $file_in_p) = @_;
    my $out_data = "";
    my $redirect_in = $file_in_p ? "" : "<";
    my $proc_com = $proc." ".$redirect_in." \"".$in_file."\" > \"".$out_file."\"";
    if ( $Config{"osname"} eq "MSWin32" ) {
        $proc_com =~ s/\//\\/gs;
    }
    system($proc_com);
    return;
}

1;
