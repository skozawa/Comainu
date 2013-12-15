package Comainu::Method::Kc2longeval;

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
        args_num => 4,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

############################################################
# 解析モデルの評価
############################################################
# 正解の情報が付与されたKCファイルと、長単位解析結果のKCファイルを比較し、
# diff結果と精度を出力する。
# 動作
# 第１引数をよび第２引数の種類によって解析対象を変える。
# ・どちらもファイルの場合
#   それぞれのファイルを使って処理し、解析結果KCファイル名の拡張子を".eval",
#   ".eval.long"を付けた名前で、第３引数のパスに保存する。
# ・どちらもディレクトリの場合
#   第一引数のディレクトリ内に有る"*.KC"ファイル全てを対象として処理を行う。
#   ".lout"ファイルは、第二引数で与えられたディレクトリ内のファイルで、".KC"ファイル
#   とペアとなる".lout"ファイルを順次適用する。無ければエラーとする。
#   処理結果は、".KC"ファイル名から拡張子を除いた文字列に".eval",
#   ".eval.long"を付けた名前で、第３引数のパスに保存する。
# ・上記２つの場合に該当しない組合せはエラーとする。
#
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: kc2longeval\n");
    printf("  Usage: %s kc2longeval <ref-kc> <kc-lout> <out-dir>\n", $0);
    printf("    This command make a evaluation for <kc-lout> with <ref-kc>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  perl ./script/comainu.pl kc2longeval sample/sample.KC out/sample.KC.lout out\n");
    printf("    -> out/sample.eval.long\n");
    printf("\n");
}

sub run {
    my ($self, $correct_kc, $result_kc_lout, $save_dir) = @_;

    $self->before_analyze(scalar @_, $save_dir);

    $self->evaluate_files($correct_kc, $result_kc_lout, $save_dir);

    return 0;
}

sub evaluate {
    my ($self, $correct_kc, $result_kc_lout, $save_dir) = @_;
    $self->compare($correct_kc, $result_kc_lout, $save_dir);
}

# 正解KCファイルと長単位解析結果KCファイルを受け取り、
# 処理して".eval.long"ファイルを出力する。
sub compare {
    my ($self, $kc_file, $lout_file, $save_dir) = @_;
    print STDERR "_compare\n";
    my $res = "";

    # 中間ファイル
    my $tmp1_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($kc_file, ".KC").".long";

    # すでに中間ファイルが出来ていれば処理しない
    if ( -s $tmp1_file ) {
        print STDERR "Use Cache \'$tmp1_file\'.\n";
    } else {
        unless ( -f $kc_file ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = read_from_file($kc_file);
        $buff = $self->comainu->trans_dataformat($buff, "input-kc", "kc");
        $buff = $self->comainu->short2long($buff);
        write_to_file($tmp1_file, $buff);
        undef $buff;
    }

    unless ( -f $lout_file ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    # 中間ファイル
    my $tmp2_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($lout_file, ".lout") . ".svmout_create.long";
    my $buff = read_from_file($lout_file);
    $buff = $self->comainu->short2long($buff);
    write_to_file($tmp2_file, $buff);
    undef $buff;

    my $output_file = $save_dir . "/" .
        basename($lout_file, ".lout").".eval.long";

    $res = $self->comainu->eval_long($tmp1_file, $tmp2_file);
    write_to_file($output_file, $res);
    print $res;

    return $res;
}


1;
