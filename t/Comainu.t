package t::Comainu;
use strict;
use warnings;
use utf8;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

use Encode;
use File::Temp;

use Comainu;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu';
};

sub dummy : Test(1) {
    ok 1;
}

# sub add_column : Tests {};
# sub poscreate : Tests {};
# sub pp_ctype : Tests {};
# sub check_args : Tests {};


sub create_tmp_file {
    my $data = shift;

    my $fh   = File::Temp->new;
    my $file = $fh->filename;
    print $fh encode_utf8 $data;
    close $fh;

    return ($file, $fh);
}

sub guard_write_to_file {
    my $data = shift;

    mock_guard('Comainu', {
        write_to_file => sub {
            my ($self, $tmp_file, $buff) = @_;
            $$data = $buff;
        }
    });
}



__PACKAGE__->runtests;
