#!/usr/bin/env perl
# -*- mode: perl; coding: utf-8 -*-

use strict;

BEGIN {
    # Must not use FindBin here. It should be reserved the real script.
    use File::Basename;
    use File::Spec;
    my $bin = File::Spec->rel2abs(File::Basename::dirname($0));
    push(@INC, "$bin/../lib");
}

use RunCom;

sub main {
    my $rc = RunCom->new();
    $rc->exec_com(@ARGV);
}

main();

#################### END OF FILE ####################
