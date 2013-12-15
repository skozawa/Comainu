package Comainu::Method::Kc2bnstmodel;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Config;

use Comainu::Util qw(read_from_file write_to_file);

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 3,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

# 文節境界解析モデルの学習
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: kc2bnstmodel\n");
    printf("  Usage: %s kc2bnstmodel <train-kc> <bnst-model-dir>\n", $0);
    printf("    This command trains model from <train-kc> into <bnst-model-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kc2bnstmodel sample/sample.KC train\n");
    printf("    -> train/sample.KC.model\n");
    printf("\n");
}

sub run {
    my ($self, $train_kc, $model_dir) = @_;

    $model_dir = dirname($train_kc) if $train_kc && !$model_dir;
    $self->before_analyze(scalar @_, $model_dir);

    $self->_train_bnstmodel($train_kc, $model_dir);

    return 0;
}

sub _train_bnstmodel {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN BNST MODEL\n";

    my $basename = basename($train_kc);
    my $svmin = $model_dir . "/" . $basename . ".svmin";
    my $svmin_buff = read_from_file($train_kc);
    $svmin_buff = $self->comainu->trans_dataformat($svmin_buff, "input-kc", "kc");
    $svmin_buff = $self->comainu->kc2bnstsvmdata($svmin_buff, 1);
    $svmin_buff = $self->_add_bnst_label($svmin_buff);
    $svmin_buff =~ s/^EOS.*?\n//mg;
    $svmin_buff .= "\n";
    write_to_file($svmin, $svmin_buff);
    undef $svmin_buff;

    my $makefile = $self->comainu->create_yamcha_makefile($model_dir, $basename);
    my $perl = $self->comainu->{perl};
    my $com = sprintf("make -f \"%s\" PERL=\"%s\" CORPUS=\"%s\" MODEL=\"%s\" train",
                      $makefile, $perl, $svmin, $model_dir . "/" . $basename);

    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return 0;
}


# 文節境界ラベルを付与
sub _add_bnst_label {
    my ($self, $data) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];
    $data .= "*B\n";
    foreach my $line ( (split(/\r?\n/, $data), undef, undef) ) {
        push(@$buff_list, $line);
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS|^\*B/ ) {
            my $mark = $buff_list->[$prev] =~ /^\*B/ ? "B" : "I";
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift @$buff_list;
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line . "\n";
        }
    }
    undef $data;

    while ( my $new_line = shift(@$buff_list) ) {
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line . "\n";
        }
    }
    undef $buff_list;

    return $res;
}


1;
