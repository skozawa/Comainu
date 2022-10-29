#!/bin/sh

if [ ! -d local ]; then
    mkdir local
fi

# The tools are not installed if you use the following variables
# NO_PERL=1, NO_CRF=1, NO_SVM_TOOL=1, NO_YAMCHA=1
# NO_MECAB=1, NO_MECAB_DIC=1, NO_UNIDIC_DB=1

## Default Path
PERL=$(which perl)
JAVA=/usr/bin/java
CRF=/usr/local/bin
YAMCHA=/usr/local/bin
MECAB=/usr/local/bin
MECAB_DIC=/usr/local/lib/mecab/dic
UNIDIC_DB=/usr/local/unidic2/share/unidic.db

PREFIX=$(pwd)/local

## CRF++
if [ -z $NO_CRF ]; then
    CRF=${PREFIX}/bin
    if [ ! -x ${PREFIX}/bin/crf_test ]; then
        echo "*** GET CRF++ ***"
        wget "https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7QVR6VXJ5dWExSTQ" -O CRF++.tar.gz
        echo "*** INSTALL CRF++ ***"
        tar -xzf CRF++.tar.gz
        cd CRF++-0.58
        ./configure --prefix=${PREFIX}
        make
        make install
        cd ..
        rm -rf CRF++-0.58
        rm -f CRF++.tar.gz
        echo "*** INSTALL DONE CRF++ ***"
    fi
fi

## TinySVM
if [ -z $NO_SVM_TOOL ]; then
    SVM_TOOL=${PREFIX}/bin
    if [ ! -x ${PREFIX}/bin/svm_classify ]; then
        echo "*** GET TinySVM ***"
        wget "http://chasen.org/~taku/software/TinySVM/src/TinySVM-0.09.tar.gz" -O TinySVM.tar.gz
        echo "*** INSTALL TinySVM ***"
        tar -xzf TinySVM.tar.gz
        cd TinySVM-0.09
        ./configure --prefix=${PREFIX}
        make
        make install
        cd ..
        rm -rf TinySVM-0.09
        rm -f TinySVM.tar.gz
        echo "*** INSTALL DONE TinySVM ***"
    fi
fi

# Yamcha
if [ -z $NO_YAMCHA ]; then
    YAMCHA=${PREFIX}/bin
    if [ ! -x ${PREFIX}/bin/yamcha ]; then
        echo "*** GET yamcha ***"
        wget "http://chasen.org/~taku/software/yamcha/src/yamcha-0.33.tar.gz" -O yamcha.tar.gz
        echo "*** INSTALL yamcha ***"
        tar -xzf yamcha.tar.gz
        cd yamcha-0.33
        ./configure --prefix=${PREFIX} --with-svm-learn=${PREFIX}
        make
        make install
        cd ..
        if [ ! -x ${PREFIX}/bin/yamcha ]; then
            echo "*** APPLY Yamcha Patch(1) for INSTALL Error ***"
            wget "https://gist.githubusercontent.com/skozawa/89024693963fd0adfa6d/raw/00ffa28de5ef11b902b4f35cbf3f3217bc62de3e/yamcha.patch"
            patch -p0 < yamcha.patch
            cd yamcha-0.33
            ./configure --prefix=${PREFIX} --with-svm-learn=${PREFIX}
            make
            make install
            cd ..
            rm yamcha.patch
        fi
        if [ ! -x ${PREFIX}/bin/yamcha ]; then
            echo "*** APPLY Yamcha Patch(2) for INSTALL Error ***"
            cd yamcha-0.33
            wget "https://sources.debian.org/data/main/y/yamcha/0.33-2/debian/patches/1011_fix_gcc7_compilation.patch"
            patch -p1 < 1011_fix_gcc7_compilation.patch
            ./configure --prefix=${PREFIX} --with-svm-learn=${PREFIX}
            make
            make install
            cd ..
            rm 1011_fix_gcc7_compilation.patch
        fi
        rm -rf yamcha-0.33
        rm -f yamcha.tar.gz
        echo "*** INSTALL DONE yamcha ***"
    fi
fi

# MeCab
if [ -z $NO_MECAB ]; then
    MECAB=${PREFIX}/bin
    if [ ! -x ${PREFIX}/bin/mecab ]; then
        echo "*** GET MeCab ***"
        wget "https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7cENtOXlicTFaRUE" -O mecab.tar.gz
        echo "*** INSTALL MeCab ***"
        tar -xzf mecab.tar.gz
        cd mecab-0.996
        ./configure --prefix=${PREFIX}
        make
        make install
        cd ..
        rm -rf mecab-0.996
        rm -f mecab.tar.gz
        echo "*** INSTALL DONE MeCab ***"
    fi
fi

# MeCab-UniDic
if [ -z $NO_MECAB_DIC ]; then
    MECAB_DIC=${PREFIX}/lib/mecab/dic
    if [ ! -d ${PREFIX}/lib/mecab/dic ]; then
        echo "*** GET MeCab-UniDic ***"
        wget "http://osdn.jp/frs/redir.php?m=jaist&f=%2Funidic%2F58338%2Funidic-mecab-2.1.2_src.zip" -O unidic-mecab.zip
        echo "*** INSTALL MeCab-UniDic ***"
        unzip unidic-mecab.zip
        cd unidic-mecab-2.1.2_src
        MECAB_CONFIG=${PREFIX}/bin/mecab-config ./configure --prefix=${PREFIX}
        make
        make install
        cd ..
        rm -rf unidic-mecab-2.1.2_src
        rm -f unidic-mecab.zip
        echo "*** INSTALL DONE MeCab-Unidic ***"
    fi
fi

# UNIDIC_DB
if [ -z $NO_UNIDIC_DB ]; then
    UNIDIC_DB=${PREFIX}/unidic2/unidic.db
    if [ ! -f ${PREFIX}/unidic2/unidic.db ]; then
        echo "*** GET UNIDIC_DB ***"
        cd ${PREFIX}
        wget "http://osdn.jp/frs/redir.php?m=iij&f=%2Fcomainu%2F63044%2FComainu-unidic2-0.10.tgz" -O unidic2.tar.gz
        echo "*** DECOMPRESS UNIDIC_DB ***"
        tar -xzf unidic2.tar.gz
        rm -f unidic2.tar.gz
        cd ..
        echo "*** INSTALL DONE UNIDIC_DB ***"
    fi
fi

# PERL
if [ -z $NO_PERL ]; then
    PERL_VERSION=5.34.1
    PERL=${PREFIX}/opt/perl-${PERL_VERSION}/bin/perl
    if [ ! -f ${PERL} ]; then
        echo "*** INSTALL PERL ***"
        curl https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - --noman ${PERL_VERSION} ${PREFIX}/opt/perl-${PERL_VERSION}/
        echo "*** INSTALL CPANM ***"
        curl -L http://cpanmin.us | ${PREFIX}/opt/perl-${PERL_VERSION}/bin/perl - App::cpanminus
        echo "*** INSTALL PERL MODULE ***"
        ${PREFIX}/opt/perl-${PERL_VERSION}/bin/cpanm install DBI DBD::SQLite
        # ${PREFIX}/opt/perl-${PERL_VERSION}/bin/cpanm install Tkx Tkx::Scrolled
    fi
fi

./configure --svm-tool-dir ${SVM_TOOL} --yamcha-dir ${YAMCHA} --crf-dir ${CRF} \
    --mecab-dir ${MECAB} --mecab-dic-dir ${MECAB_DIC} --unidic-db ${UNIDIC_DB} \
    --java ${JAVA} --perl ${PERL}
