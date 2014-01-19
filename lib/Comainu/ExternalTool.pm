package Comainu::ExternalTool;

use strict;
use warnings;
use utf8;

use Comainu::Util qw(read_from_file write_to_file);

my $DEFAULT_VALUES = {
    "debug"        => 0,
    "comainu-home" => "./",
    "yamcha-dir"   => "/usr/local/bin",
    "svm-tool-dir" => "/usr/local/bin",
    "method"       => '',
};

sub new {
    my ($class, %args) = @_;
    bless { %$DEFAULT_VALUES, %args }, $class;
}

# CRF++用のテンプレート作成
sub create_crf_template {
    my ($self, $template_file, $feature_num) = @_;

    my $buff = "";
    my $index = 1;

    for my $i (0, 2 .. $feature_num) {
        for my $j (-2..2) { $buff .= "U".$index++.":%x[$j,$i]\n"; }
        for my $k (-2..1) { $buff .= "U".$index++.":%x[$k,$i]/%x[".($k+1).",$i]\n"; }
        for my $l (-2..0) { $buff .= "U".$index++.":%x[$l,$i]/%x[".($l+1).",$i]/%x[".($l+2).",$i]\n"; }
    }
    $buff .= "\n";

    my @features = qw(2_3_1 2_4_1 2_5_1 2_3_3 2_4_3 2_5_3);
    foreach my $feature ( @features ) {
        my ($arg1, $arg2, $type) = split(/\_/, $feature);
        if ( $type == 0 ) {
            for my $l ( -2 .. 2 ) {
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[$l,$arg2]\n";
            }
            $buff .= "\n";
        } elsif ( $type == 1 ) {
            for my $l ( -2 .. 1 ) {
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[".($l+1).",$arg2]\n";
                $buff .= "U".$index++.":%x[$l,$arg2]/%x[".($l+1).",$arg1]\n";
            }
            $buff .= "\n";
        } elsif ( $type == 2 ) {
            for my $l ( -2 .. 1 ) {
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[".($l+1).",$arg2]\n";
                $buff .= "U".$index++.":%x[$l,$arg2]/%x[".($l+1).",$arg1]\n";
            }
            for my $l ( -2 .. 0 ) {
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[".($l+2).",$arg2]\n";
                $buff .= "U".$index++.":%x[$l,$arg2]/%x[".($l+2).",$arg1]\n";
            }
            $buff .= "\n";
        } elsif ( $type == 3 ) {
            for my $l ( -2 .. 1 ) {
                if ( $arg1 > 3 ) {
                    $buff .= "U".$index++.":%x[$l,$arg1]/%x[$l,$arg2]/%x[".($l+1).",$arg1]\n";
                    $buff .= "U".$index++.":%x[$l,$arg1]/%x[".($l+1).",$arg1]/%x[".($l+1).",$arg2]\n";
                }
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[$l,$arg2]/%x[".($l+1).",$arg2]\n";
                $buff .= "U".$index++.":%x[$l,$arg2]/%x[".($l+1).",$arg1]/%x[".($l+1).",$arg2]\n";
            }
            $buff .= "\n";
        }
    }

    $buff .= "\nB\n";

    write_to_file($template_file, $buff);
    undef $buff;
}

## テンプレート(後処理用)の作成
sub create_crf_BI_template {
    my ($self, $template_file, $feature_num, $num) = @_;

    my $buff = "";
    my $index = 0;
    foreach my $i ( 0 .. $feature_num ) {
        $buff .= "U".$index++.":%x[0,".$i."]\n";
    }
    $buff .= "\n";
    foreach my $i ( 0 .. $feature_num/3 ) {
        $buff .= "U".$index++.":%x[0,".$i."]/%x[0,".($i+$feature_num/3)."]\n";
        $buff .= "U".$index++.":%x[0,".($i+$feature_num/3)."]/%x[0,".($i+$feature_num/3*2)."]\n";
    }
    for my $i ( 1 .. $num ) {
        $buff .= "U".$index++.":%x[0,".($feature_num+$i)."]\n";
    }
    $buff .= "\n";
    write_to_file($template_file, $buff);
    undef $buff;
}

# yamchaのMakefileを作成
sub create_yamcha_makefile {
    my ($self, $model_dir, $basename) = @_;

    my $yamcha = $self->{"yamcha-dir"} . "/yamcha";
    my $yamcha_tool_dir = $self->get_yamcha_tool_dir;
    my $svm_tool_dir = $self->{"svm-tool-dir"};
    my $svm_learn = $svm_tool_dir . "/svm_learn";

    my $conf_file = $self->{"comainu-home"} . "/etc/yamcha_training.conf";

    printf(STDERR "# use yamcha_training_conf_file=\"%s\"\n", $conf_file);
    my $conf = $self->load_yamcha_training_conf($conf_file);
    my $makefile_template = $yamcha_tool_dir . "/Makefile";
    my $check = $self->check_yamcha_training_makefile_template($makefile_template);

    if ( $check == 0 ) {
        $makefile_template = $self->{"comainu-home"} . "/etc/yamcha_training.mk";
    }
    printf(STDERR "# use yamcha_training_makefile_template=\"%s\"\n",
           $makefile_template);
    my $makefile = $model_dir . "/" . $basename . ".Makefile";

    my $buff = read_from_file($makefile_template);

    if ( $check == 0 ) {
        $buff =~ s/^(TOOLDIR.*)$/\# $1\nTOOLDIR    = $yamcha_tool_dir/mg;
        printf(STDERR "# changed TOOLDIR : %s\n", $yamcha_tool_dir);
        $buff =~ s/^(YAMCHA.*)$/\# $1\nYAMCHA    = $yamcha/mg;
        printf(STDERR "# changed YAMCHA : %s\n", $yamcha);
    }

    if ( $svm_tool_dir ne "" ) {
        $buff =~ s/^(SVM_LEARN.*)$/\# $1\nSVM_LEARN = $svm_learn/mg;
        printf(STDERR "# changed SVM_LEARN : %s\n", $svm_learn);
    }
    if ( $conf->{SVM_PARAM} ne "" ) {
        $buff =~ s/^(SVM_PARAM.*)$/\# $1\nSVM_PARAM  = $conf->{"SVM_PARAM"}/mg;
        printf(STDERR "# changed SVM_PARAM : %s\n", $conf->{"SVM_PARAM"});
    }
    if ( $conf->{FEATURE} ne "" ) {
        $buff =~ s/^(FEATURE.*)$/\# $1\nFEATURE    = $conf->{"FEATURE"}/mg;
        printf(STDERR "# changed FEATURE : %s\n", $conf->{"FEATURE"});
    }
    if ( $conf->{DIRECTION} ne "" ) {
        $buff =~ s/^(DIRECTION.*)$/\# $1\nDIRECTION  = $conf->{"DIRECTION"}/mg;
        printf(STDERR "# changed DIRECTION : %s\n", $conf->{"DIRECTION"});
    }
    if ( $self->{method} ne 'kc2bnstmodel' && $conf->{"MULTI_CLASS"} ne "" ) {
        $buff =~ s/^(MULTI_CLASS.*)$/\# $1\nMULTI_CLASS = $conf->{"MULTI_CLASS"}/mg;
        printf(STDERR "# changed MULTI_CLASS : %s\n", $conf->{"MULTI_CLASS"});
    }

    {
        # patch for zip
        # remove '#' at end of line by svm_light
        my $patch_for_zip_str = "### patch for zip ###\n\t\$(PERL) -pe 's/#\\r?\$\$//;' \$(MODEL).svmmodel > \$(MODEL).svmmodel.patched\n\tmv -f \$(MODEL).svmmodel.patched \$(MODEL).svmmodel\n#####################\n";
        $buff =~ s/(zip:\n)/$1$patch_for_zip_str/;
        printf(STDERR "# patched zip target\n");
    }

    {
        # patch for compile
        # fixed the problem that it uses /bin/gzip in mkmodel.
        my $patch_for_compile_str = "### patch for compile ###\n\t\$(GZIP) -dc \$(MODEL).txtmodel.gz | \$(PERL) \$(TOOLDIR)/mkmodel -t \$(TOOLDIR) - \$(MODEL).model\n#########################\n";
        $buff =~ s/(compile:\n)([^\n]+\n)/$1\#$2$patch_for_compile_str/;
        printf(STDERR "# patched compile target\n");
    }

    write_to_file($makefile, $buff);
    undef $buff;

    return $makefile;
}

sub get_yamcha_tool_dir {
    my ($self) = @_;
    my $yamcha_tool_dir = $self->{"yamcha-dir"} . "/libexec/yamcha";
    unless ( -d $yamcha_tool_dir ) {
        $yamcha_tool_dir = $self->{"yamcha-dir"} . "/../libexec/yamcha";
    }
    unless ( -d $yamcha_tool_dir ) {
        printf(STDERR "# Error: not found YAMCHA TOOL_DIR (libexec/yamcha) '%s'\n",
               $yamcha_tool_dir);
        $yamcha_tool_dir = undef;
    }
    return $yamcha_tool_dir;
}

sub load_yamcha_training_conf {
    my ($self, $file) = @_;
    my $conf = {};
    open(my $fh, $file) or die "Cannot open '$file'";
    while ( my $line = <$fh> ) {
        $line =~ s/\r?\n$//;
        next if $line =~ /^\#|^\s*$/;

        if ( $line =~ /^(.*?)=(.*)/ ) {
            my ($key, $value) = ($1, $2);
            $value =~ s/^\s*\"(.*)\"\s*$/$1/;
            $value =~ s/^\s*\'(.*)\'\s*$/$1/;
            $conf->{$key} = $value;
        }
    }
    close($fh);
    return $conf;
}

sub check_yamcha_training_makefile_template {
    my ($self, $yamcha_training_makefile_template) = @_;

    unless ( -f $yamcha_training_makefile_template ) {
        printf(STDERR "# Warning: Not found yamcha_training_makefile_template \"%s\"\n", $yamcha_training_makefile_template);
        return 0;
    }

    my $buff = read_from_file($yamcha_training_makefile_template);
    if ( $buff !~ /^train:/ms ) {
        printf(STDERR "# Warning: Not found \"train:\" target in yamcha_training_makefile_template \"%s\"\n", $yamcha_training_makefile_template);
        return 0;
    }
    undef $buff;
    return 1;
}


1;
