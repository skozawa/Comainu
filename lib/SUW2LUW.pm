# -*- mode: perl; coding: utf-8; -*-

package SUW2LUW;

use strict;
use utf8;
use Encode;
use Config;

my $DEFAULT_VALUES =
{
    "debug" => 0,
    "infl-file" => "Infl.txt",
    "deriv-file" => "Deriv.txt",
    "comp-file" => "Comp.txt",
};

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    return $self;
}

# from unix/perls/suw2luw/suw2luw.pl
# -----------------------------------------------------------------------------
# SUW2LUW
# -----------------------------------------------------------------------------
sub suw2luw {
    my $self = shift;
    my ($data, $InflFile, $DerivFile, $CompFile) = @_;
    # $data = Encode::decode("utf-8", $data);
    if (!defined($InflFile)) {
        $InflFile = $self->{"infl-file"};
    }
    if (!defined($DerivFile)) {
        $DerivFile = $self->{"deriv-file"};
    }
    if (!defined($CompFile)) {
        $CompFile = $self->{"comp-file"};
    }
    # my $InflFile = 'Infl.txt';
    # my $DerivFile = 'Deriv.txt';
    # my $CompFile = 'Comp.txt';
    my %infl;
    my %baseInfl;
    my %deriv;
    my %comp;
    $self->read_infl(\%infl, \%baseInfl, $InflFile);
    $self->read_deriv(\%deriv, $DerivFile);
    $self->read_comp(\%comp, $CompFile);
    my $res = $self->suw2luw_internal($data, \%infl, \%baseInfl, \%deriv, \%comp);
    if ($Config{"osname"} eq "MSWin32") {
        $res =~ s/\x0a/\x0d\x0a/sg;
    }
    # $res = Encode::encode("utf-8", $res);
    return $res;
}

# ----------------------------------------------------------------------
sub read_infl {
    my $self = shift;
    my ($ref_infl,$ref_baseInfl,$inflFile) = @_;

    open(FILE, $inflFile)
        || die "Error: can't open file `$inflFile'\n";
    binmode(FILE, ":encoding(utf-8)");

    while (<FILE>) {
        # chomp;
        s/\r?\n$//;

        my ($cType,$cTypeO,$cForm,
            $lForm,$lemma,
            $base) = split(/\t/);

        if (defined $ref_infl->{$cType,$cTypeO,$cForm}) {
            print STDERR Encode::encode("utf-8", "Warning: infl multiply defined for <$cType,$cForm>\n");
        } else {
            $ref_infl->{$cType,$cTypeO,$cForm} = join($;, $lForm,$lemma);
        }

        next
            unless $base;

        if (defined $ref_baseInfl->{$cType}->{$cTypeO}) {
            print STDERR Encode::encode("utf-8", "Warning: baseInfl multiply defined for <$cType,$cTypeO>\n");
        } else {
            $ref_baseInfl->{$cType}->{$cTypeO} = join($;, $lForm,$lemma);
        }
    }

    close(FILE);
}

# ----------------------------------------------------------------------
sub read_deriv {
    my $self = shift;
    my ($ref_deriv,$derivFile) = @_;

    open(FILE, $derivFile)
        || die "Error: can't open file `$derivFile'\n";
    binmode(FILE, ":encoding(utf-8)");

    while (<FILE>) {
        # chomp;
        s/\r?\n$//;

        my ($cType,
            $lForm,$lemma,
            $lFormDeriv,$lemmaDeriv) = split(/\t/);

        if (defined $ref_deriv->{$cType}->{$lForm,$lemma}) {
            print STDERR Encode::encode("utf-8", "Warning: deriv multiply defined for <$cType,$lForm,$lemma>\n");
        } else {
            $ref_deriv->{$cType}->{$lForm,$lemma} = join($;, $lFormDeriv,$lemmaDeriv);
        }
    }

    close(FILE);
}

# ----------------------------------------------------------------------
sub read_comp {
    my $self = shift;
    my ($ref_comp,$compFile) = @_;

    open(FILE, $compFile)
        || die "Error: can't open file `$compFile'\n";
    binmode(FILE, ":encoding(utf-8)");

    while (<FILE>) {
        # chomp;
        s/\r?\n$//;

        my ($pos,
            $lForm,$lemma,
            $lFormComp,$lemmaComp) = split(/\t/);

        if (defined $ref_comp->{$pos,$lForm,$lemma}) {
            print STDERR Encode::encode("utf-8", "Warning: comp multiply defined for <$pos,$lForm,$lemma>\n");
        } else {
            $ref_comp->{$pos,$lForm,$lemma} = join($;, $lFormComp,$lemmaComp);
        }
    }

    close(FILE);
}

# ----------------------------------------------------------------------
sub suw2luw_internal {
    my $self = shift;
    my ($data, $ref_infl,$ref_baseInfl,$ref_deriv,$ref_comp) = @_;
    my @Line;
    my $res = "";

    foreach $_ (split(/\r?\n/, $data)) {
        s/\r$//;

        # my ($lLabel,
        # $orth,$dummy,$lForm,$lemma,$pron,
        # $pos,$cType,$cForm,$subLemma,
        # @others) = split(/\s/);
        my ($lLabel,
            $orth,$dummy,$lForm,$lemma,$pron,
            $pos,$cType,$cForm,$subLemma,
            @others) = split(/[ \t]/);

        if ($lLabel eq 'B' || $lLabel eq 'Ba') {
            $res .= $self->sprint_morph(\@Line,
                                        $ref_infl, $ref_baseInfl, $ref_deriv, $ref_comp)
                if @Line;

            @Line = ();
        }

        push(@Line, $_);
    }
    $res .= $self->sprint_morph(\@Line,
                                $ref_infl, $ref_baseInfl, $ref_deriv, $ref_comp)
        if @Line;
    return $res;
}

# ----------------------------------------------------------------------
sub sprint_morph {
    my $self = shift;
    my ($ref_line,
        $ref_infl,$ref_baseInfl,$ref_deriv,$ref_comp) = @_;
    my ($orthL,$pronL,$lFormL,$lemmaL)
        = $self->lemma($ref_line,
                       $ref_infl, $ref_baseInfl, $ref_deriv, $ref_comp);
    my $n = 1;
    my $res = "";

    foreach my $line (@$ref_line) {
        # my ($lLabel,
        # $orth,$dummy,$lForm,$lemma,$pron,
        # $pos,$cType,$cForm,$subLemma,$misc1,$misc2,
        # $posL,$cTypeL,$cFormL,$misc3,$misc4,$misc5) = split(/\s/, $line);
        my ($lLabel,
            $orth,$dummy,$lForm,$lemma,$pron,
            $pos,$cType,$cForm,$subLemma,$misc1,$misc2,
            $posL,$cTypeL,$cFormL,$misc3,$misc4,$misc5) = split(/[ \t]/, $line);

        if ($lFormL ne "・" && $lFormL =~ /・/) {
            $lFormL =~ s/・//g;
        }
        $res .= "$lLabel ";
        $res .= "$orth $orth $lForm $lemma $pron ";
        $res .= "$pos $cType $cForm $subLemma ";
        $res .= "$misc1 $misc2 ";
        $res .= "$posL $cTypeL $cFormL ";
        $res .= "$misc3 $misc4 $misc5 ";
        if ($n == 1) {
            $res .= "$lFormL $lemmaL $orthL\n";
            # $res .= "$lFormL $lemmaL\n";
        } else {
            $res .= "* * *\n";
            # $res .= "* *\n";
        }

        $n ++;
    }
    return $res;
}

# ----------------------------------------------------------------------
sub lemma {
    my $self = shift;
    my ($ref_line,
        $ref_infl,$ref_baseInfl,$ref_deriv,$ref_comp) = @_;
    my @orth;
    my @pron;
    my @lForm;
    my @lemma;
    my $POSL;

    for (my $i = 0; $i < @$ref_line; $i ++) {
        # my ($lLabel,
        #    $orth,$dummy,$lForm,$lemma,$pron,
        #    $pos,$cType,$cForm,$subLemma,$misc1,$misc2,
        #    $posL,$cTypeL,$cFormL,$misc3,$misc4,$misc5) = split(/\s/, $ref_line->[$i]);
        my ($lLabel,
            $orth,$dummy,$lForm,$lemma,$pron,
            $pos,$cType,$cForm,$subLemma,$misc1,$misc2,
            $posL,$cTypeL,$cFormL,$misc3,$misc4,$misc5) = split(/[ \t]/, $ref_line->[$i]);

        # temporary
        #	$lForm = $lemma
        #	    if $lForm eq '';

        if ($i != $#$ref_line) {
            # temporary
            #	    $lForm = 'ニホン'
            #		if $lForm eq 'ニッポン';

            if ($cType ne '' && $cType ne '*') {
                my ($tmp_lForm,$tmp_lemma) =
                    $self->infl($lForm, $lemma,
                                $cType, $cForm,
                                $ref_infl, $ref_baseInfl, $ref_deriv);
                if (defined($tmp_lForm) and defined($tmp_lemma)) {
                    ($lForm, $lemma) = ($tmp_lForm, $tmp_lemma);
                }
            }
            $lForm = $self->fForm($lForm, $pron);
        }
        if ($i != 0) {
            $lForm = $self->iForm($lForm, $pron);
        }

        push(@lForm, $lForm);
        push(@lemma, $lemma);
        push(@orth, $orth);
        push(@pron, $pron);
        $POSL = $posL
            if $i == 0;
    }

    my ($lFormL,$lemmaL) = $self->comp(join('', @lForm), join('', @lemma),
                                       $POSL,
                                       $ref_comp);

    return (join('',@orth),join('',@pron),$lFormL,$lemmaL);
}

# ----------------------------------------------------------------------
sub infl {
    my $self = shift;
    my ($lForm,$lemma,
        $cType,$cForm,
        $ref_infl,$ref_baseInfl,$ref_deriv) = @_;
    my $cTypeO;
    my $lFormStem;
    my $lemmaStem;

    foreach my $key (keys %{$ref_baseInfl->{$cType}}) {
        #	print ">>> $cType, $key <<<\n";
        my ($baseLForm,$baseLemma) = split($;, $ref_baseInfl->{$cType}->{$key});
        #	print "!!! $baseLForm, $baseLemma !!!\n";

        ($lFormStem) = ($lForm =~ /(.*)$baseLForm$/);
        ($lemmaStem) = ($lemma =~ /(.*)$baseLemma$/);

        if (defined $lFormStem && defined $lemmaStem) {
            #	    print "%%% $lFormStem, $lemmaStem %%%\n";

            $cTypeO = $key;

            last;
        }
    }

    unless (defined $lFormStem && defined $lemmaStem) {
        my ($lFormDeriv,$lemmaDeriv) = $self->deriv($lForm, $lemma,
                                                    $cType,
                                                    $ref_deriv);

        # die "Error [$.]: suffix for baseInfl unmatched <$lForm,$lemma,$cType>\n"
        #     unless defined $lemmaDeriv;
        unless(defined $lemmaDeriv) {
            warn "Error [$.]: suffix for baseInfl unmatched <$lForm,$lemma,$cType>\n";
            return (undef, undef);
        }

        return $self->infl($lFormDeriv, $lemmaDeriv,
                           $cType, $cForm,
                           $ref_infl, $ref_baseInfl, $ref_deriv);
    }

    #    print "### $lFormStem, $lemmaStem, $cType, $cTypeO ###\n";

    my $infl = $ref_infl->{$cType,$cTypeO,$cForm};

    # die "Error: infl undefined for <$cType,$cTypeO,$cForm>\n"
    #	unless defined $infl;
    unless(defined $infl) {
        warn "Error: infl undefined for <$cType,$cTypeO,$cForm>\n";
        return (undef, undef);
    }

    my ($lFormSuffix,$lemmaSuffix) = split($;, $infl);

    return ($lFormStem.$lFormSuffix, $lemmaStem.$lemmaSuffix);
}

# ----------------------------------------------------------------------
sub deriv {
    my $self = shift;
    my ($lForm,$lemma,
        $cType,
        $ref_deriv) = @_;

    foreach my $key (keys %{$ref_deriv->{$cType}}) {
        my ($baseLForm,$baseLemma) = split($;, $key);
        my ($lFormStem) = ($lForm =~ /(.*)$baseLForm$/);
        my ($lemmaStem) = ($lemma =~ /(.*)$baseLemma$/);

        if (defined $lFormStem && defined $lemmaStem) {
            my ($lFormSuffix,$lemmaSuffix) = split($;, $ref_deriv->{$cType}->{$key});

            return ($lFormStem.$lFormSuffix, $lemmaStem.$lemmaSuffix);
        }
    }
}

# ----------------------------------------------------------------------
sub comp {
    my $self = shift;
    my ($lForm,$lemma,
        $pos,
        $ref_comp) = @_;
    my $comp = $ref_comp->{$pos,$lForm,$lemma};

    if (defined $comp) {
        return split($;, $comp);
    } else {
        return ($lForm,$lemma);
    }
}

# ----------------------------------------------------------------------
sub iForm {
    my $self = shift;
    my ($lForm,$pron) = @_;

    return $lForm
        if length($lForm) != length($pron);
    return $lForm
        if $pron !~ /^(ガ|ギ|グ|ゲ|ゴ|ザ|ジ|ズ|ゼ|ゾ|ダ|ヂ|ヅ|デ|ド|バ|ビ|ブ|ベ|ボ)/;

    (my $pronDeriv = $lForm) =~ s/^(カ|キ|ク|ケ|コ|サ|シ|ス|セ|ソ|タ|チ|ツ|テ|ト|ハ|ヒ|フ|ヘ|ホ)/$self->u2v1($1)/e;

    $lForm =~ s/^(カ|キ|ク|ケ|コ|サ|シ|ス|セ|ソ|タ|チ|ツ|テ|ト|ハ|ヒ|フ|ヘ|ホ)/$self->u2v2($1)/e
        if substr($pronDeriv, 0, 3) eq substr($pron, 0, 3);

    return $lForm;
}

sub u2v1 {
    my $self = shift;
    my ($char) = @_;

    return 'ガ' if $char eq 'カ';
    return 'ギ' if $char eq 'キ';
    return 'グ' if $char eq 'ク';
    return 'ゲ' if $char eq 'ケ';
    return 'ゴ' if $char eq 'コ';
    return 'ザ' if $char eq 'サ';
    return 'ジ' if $char eq 'シ';
    return 'ズ' if $char eq 'ス';
    return 'ゼ' if $char eq 'セ';
    return 'ゾ' if $char eq 'ソ';
    return 'ダ' if $char eq 'タ';
    return 'ジ' if $char eq 'チ';
    return 'ズ' if $char eq 'ツ';
    return 'デ' if $char eq 'テ';
    return 'ド' if $char eq 'ト';
    return 'バ' if $char eq 'ハ';
    return 'ビ' if $char eq 'ヒ';
    return 'ブ' if $char eq 'フ';
    return 'ベ' if $char eq 'ヘ';
    return 'ボ' if $char eq 'ホ';
}

sub u2v2 {
    my $self = shift;
    my ($char) = @_;

    return 'ガ' if $char eq 'カ';
    return 'ギ' if $char eq 'キ';
    return 'グ' if $char eq 'ク';
    return 'ゲ' if $char eq 'ケ';
    return 'ゴ' if $char eq 'コ';
    return 'ザ' if $char eq 'サ';
    return 'ジ' if $char eq 'シ';
    return 'ズ' if $char eq 'ス';
    return 'ゼ' if $char eq 'セ';
    return 'ゾ' if $char eq 'ソ';
    return 'ダ' if $char eq 'タ';
    return 'ヂ' if $char eq 'チ';
    return 'ヅ' if $char eq 'ツ';
    return 'デ' if $char eq 'テ';
    return 'ド' if $char eq 'ト';
    return 'バ' if $char eq 'ハ';
    return 'ビ' if $char eq 'ヒ';
    return 'ブ' if $char eq 'フ';
    return 'ベ' if $char eq 'ヘ';
    return 'ボ' if $char eq 'ホ';
}

# ----------------------------------------------------------------------
sub fForm {
    my $self = shift;
    my ($lForm,$pron) = @_;

    return $lForm
        if length($lForm) != length($pron);
    return $lForm
        if $pron !~ /ッ$/;

    (my $lFormDeriv = $lForm) =~ s/(キ|ク|チ|ツ)$/ッ/;

    return $lFormDeriv
        if substr($lFormDeriv, length($lFormDeriv)-3) eq substr($pron, length($pron)-3);
    return $lForm;
}

# ----------------------------------------------------------------------

1;
#################### END OF FILE ####################
