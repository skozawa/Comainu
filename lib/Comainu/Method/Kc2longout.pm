package Comainu::Method::Kc2longout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename fileparse);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use AddFeature;
use BIProcessor;

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 4,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

sub usage {
    my ($self) = @_;
    printf("COMAINU-METHOD: kc2longout\n");
    printf("  Usage: %s kc2longout <test-kc> <long-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <long-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kc2longout sample/sample.KC train/CRF/train.KC.model out\n");
    printf("    -> out/sample.lout\n");
    printf("  \$ perl ./script/comainu.pl kc2longout --luwmodel=SVM sample/sample.KC train/SVM/train.KC.model out\n");
    printf("    -> out/sample.KC.lout\n");
    printf("\n");
}

sub run {
    my ($self, $test_kc, $luwmodel, $save_dir) = @_;

    unless ( $self->args_num == scalar @_ ) {
        $self->usage;
        return 1;
    }
    $self->comainu->check_luwmodel($luwmodel);
    mkdir $save_dir unless -d $save_dir;

    if ( -f $test_kc ) {
        $self->kc2longout($test_kc, $luwmodel, $save_dir);
    } elsif ( -d $test_kc ) {
        opendir(my $dh, $test_kc);
        while ( my $test_kc_file = readdir($dh) ) {
            if ( $test_kc_file =~ /.KC$/ ) {
                $self->kc2longout($test_kc_file, $luwmodel, $save_dir);
            }
        }
        closedir($dh);
    }

    return 0;
}

sub kc2longout {
    my ($self, $test_kc, $luwmodel, $save_dir) = @_;

    my $tmp_test_kc = $self->{comainu}->{"comainu-temp"} . "/" . basename($test_kc);
    $self->comainu->format_inputdata($test_kc, $tmp_test_kc, 'input-kc', 'kc');

    $self->_create_features($tmp_test_kc, $luwmodel);

    $self->_chunk_luw($tmp_test_kc, $luwmodel);
    $self->_merge_chunk_result($tmp_test_kc, $save_dir);
    $self->_post_process($tmp_test_kc, $luwmodel, $save_dir);

    unlink $tmp_test_kc if !$self->comainu->{debug} &&
        -f $tmp_test_kc && $self->comainu->{bnst_process} ne 'with_luw';
}


# 解析用KC２ファイルへ素性追加
sub _create_features {
    my ($self, $tmp_test_kc, $luwmodel) = @_;
    print STDERR "# CREATE FEATURE DATA\n";

    # 出力ファイル名の生成
    my $output_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($tmp_test_kc, ".KC") . ".KC2";
    # すでに同じ名前の中間ファイルがあれば削除
    unlink($output_file) if -s $output_file;

    my $buff = read_from_file($tmp_test_kc);
    if ( $self->comainu->{boundary} ne "sentence" &&
             $self->comainu->{boundary} ne "word" ) {
        $buff =~ s/^EOS.*?\n//mg;
    }
    $buff = $self->comainu->delete_column_long($buff);
    $buff =~ s/^\*B.*?\n//mg if $self->comainu->{boundary} eq "sentence";

    # SVMの場合、partial chunking
    $buff = $self->comainu->pp_partial($buff) if $self->comainu->{luwmodel} eq "SVM";

    # 素性の追加
    my $AF = AddFeature->new;
    my $basename = basename($luwmodel, ".model");
    my ($filename, $path) = fileparse($luwmodel);
    $buff = $AF->add_feature($buff, $basename, $path);

    write_to_file($output_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $output_file unless -s $output_file;

    return 0;
}

# 解析用KC２ファイルをチャンキングモデル(yamcha, crf++)で解析
sub _chunk_luw {
    my ($self, $tmp_test_kc, $luwmodel) = @_;
    print STDERR "# CHUNK LUW\n";

    my $tool_cmd;
    my $opt = "";
    if ( $self->comainu->{luwmodel} eq 'SVM' ) {
        # sentence/word boundary
        $opt = "-C" if $self->comainu->{boundary} eq "sentence"
            || $self->comainu->{boundary} eq "word";
        $tool_cmd = $self->comainu->{"yamcha-dir"} . "/yamcha";
    } elsif ( $self->comainu->{luwmodel} eq 'CRF' ) {
        $tool_cmd = $self->comainu->{"crf-dir"} . "/crf_test";
    }
    $tool_cmd .= ".exe" if $Config{osname} eq "MSWin32";

    if(! -x $tool_cmd) {
        printf(STDERR "WARNING: %s Not Found or executable.\n", $tool_cmd);
        exit 0;
    }

    my $input_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($tmp_test_kc, ".KC") . ".KC2";
    my $output_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($tmp_test_kc) . ".svmout";
    # すでに同じ名前の中間ファイルがあれば削除
    unlink($output_file) if -s $output_file;
    $self->comainu->check_file($input_file);

    my $buff = read_from_file($input_file);
    $buff =~ s/^EOS.*?//mg if $self->comainu->{luwmodel} eq'CRF';
    # yamchaやCRF++のために、明示的に最終行に改行を付与
    $buff .= "\n";
    write_to_file($input_file, $buff);

    my $com = "";
    if ( $self->comainu->{luwmodel} eq "SVM" ) {
        $com = "\"" . $tool_cmd . "\" " . $opt . " -m \"" . $luwmodel . "\"";
    } elsif ( $self->comainu->{luwmodel} eq "CRF" ) {
        $com = "\"$tool_cmd\" -m \"$luwmodel\"";
    }
    printf(STDERR "# COM: %s\n", $com) if $self->comainu->{debug};

    $buff = $self->comainu->proc_stdin2stdout($com, $buff);
    $buff =~ s/\x0d\x0a/\x0a/sg;
    $buff =~ s/^\r?\n//mg;
    $buff = $self->comainu->move_future_front($buff);
    $buff = $self->comainu->truncate_last_column($buff);
    write_to_file($output_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $output_file unless -s $output_file;

    return 0;
}

# チャンクの結果をマージして出力ディレクトリへ結果を保存
sub _merge_chunk_result {
    my ($self, $tmp_test_kc, $save_dir) = @_;
    print STDERR "# MERGE CHUNK RESULT\n";

    my $basename = basename($tmp_test_kc);
    my $svmout_file = $self->comainu->{"comainu-temp"} . "/" . $basename . ".svmout";
    my $lout_file = $save_dir . "/" . $basename . ".lout";

    $self->comainu->check_file($svmout_file);

    my $buff = $self->comainu->merge_kc_with_svmout($tmp_test_kc, $svmout_file);
    write_to_file($lout_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $lout_file unless -s $lout_file;

    unlink $svmout_file if !$self->comainu->{debug} && -f $svmout_file &&
        $self->comainu->{bnst_process} ne 'with_luw';

    return 0;
}

# 後処理:BIのみのチャンクを再処理
sub _post_process {
    my ($self, $tmp_test_kc, $luwmodel, $save_dir) = @_;
    my $ret = 0;
    print STDERR "# POST PROCESS\n";

    my $cmd = $self->comainu->{"yamcha-dir"}."/yamcha";
    $cmd .= ".exe" if $Config{osname} eq "MSWin32";
    $cmd = sprintf("\"%s\" -C", $cmd);

    my $train_name = basename($luwmodel, ".model");
    my $test_name = basename($tmp_test_kc);
    my $lout_file = $save_dir . "/" . $test_name . ".lout";
    my $lout_data = read_from_file($lout_file);
    my $comp_file = $self->comainu->{"comainu-home"} . '/suw2luw/Comp.txt';

    my $BIP = BIProcessor->new(
        debug      => $self->comainu->{debug},
        model_type => 0,
    );
    my $buff = $BIP->execute_test($cmd, $lout_data, {
        train_name => $train_name,
        test_name  => $test_name,
        temp_dir   => $self->comainu->{"comainu-temp"},
        model_dir  => $self->comainu->{"comainu-svm-bip-model"},
        comp_file  => $comp_file,
    });
    undef $lout_data;

    $buff = $self->comainu->create_long_lemma($buff, $comp_file);

    write_to_file($lout_file, $buff);
    undef $buff;

    return $ret;
}


1;
