#!/bin/sh

if [ ! -d tools ]; then
    mkdir tools
fi

PERL=$(which perl)
JAVA=$(which java)

PREFIX=$(pwd)/tools

# CRF++
if [ ! -x tools/bin/crf_test ]; then
    echo "*** GET CRF++ ***"
    wget https://crfpp.googlecode.com/files/CRF%2B%2B-0.58.tar.gz
    echo "*** INSTALL CRF++ ***"
    tar -xzf CRF++-0.58.tar.gz
    cd CRF++-0.58
    ./configure --prefix=${PREFIX}
    make
    make install
    cd ..
    rm -rf CRF++-0.58
    rm -f CRF++-0.58.tar.gz
    echo "*** INSTALL DONE CRF++ ***"
fi

# TinySVM
if [ ! -x tools/bin/svm_classify ]; then
    echo "*** GET TinySVM ***"
    wget http://chasen.org/~taku/software/TinySVM/src/TinySVM-0.09.tar.gz
    echo "*** INSTALL TinySVM ***"
    tar -xzf TinySVM-0.09.tar.gz
    cd TinySVM-0.09
    ./configure --prefix=${PREFIX}
    make
    make install
    cd ..
    rm -rf TinySVM-0.09
    rm -f TinySVM-0.09.tar.gz
    echo "*** INSTALL DONE TinySVM ***"
fi

# yamcha
if [ ! -x tools/bin/yamcha ]; then
    echo "*** GET yamcha ***"
    wget http://chasen.org/~taku/software/yamcha/src/yamcha-0.33.tar.gz
    echo "*** INSTALL yamcha ***"
    tar -xzf yamcha-0.33.tar.gz
    cd yamcha-0.33
    ./configure --prefix=${PREFIX}
    make
    make install
    cd ..
    if [ ! -x tools/bin/yamcha ]; then
        echo "*** APPLY Yamcha Patch for INSTALL Error ***"
        wget http://unicus.jp/pub/yamcha.patch
        patch -p0 < yamcha.patch
        cd yamcha-0.33
        ./configure --prefix=${PREFIX}
        make
        make install
        cd ..
        rm yamcha.patch
    fi
    rm -rf yamcha-0.33
    rm -f yamcha-0.33.tar.gz
    echo "*** INSTALL DONE yamcha ***"
fi

# MeCab
if [ ! -x tools/bin/mecab ]; then
    echo "*** GET MeCab ***"
    wget https://mecab.googlecode.com/files/mecab-0.996.tar.gz
    echo "*** INSTALL MeCab ***"
    tar -xzf mecab-0.996.tar.gz
    cd mecab-0.996
    ./configure --prefix=${PREFIX}
    make
    make install
    cd ..
    rm -rf mecab-0.996
    rm -f mecab-0.996.tar.gz
    echo "*** INSTALL DONE MeCab ***"
fi

# MeCab-UniDic
if [ ! -d tools/lib/mecab/dic ]; then
    echo "*** GET MeCab-UniDic ***"
    wget "http://sourceforge.jp/frs/redir.php?m=jaist&f=%2Funidic%2F58338%2Funidic-mecab-2.1.2_src.zip"
    echo "*** INSTALL MeCab-UniDic ***"
    unzip unidic-mecab-2.1.2_src.zip
    cd unidic-mecab-2.1.2_src
    MECAB_CONFIG=${PREFIX}/bin/mecab-config ./configure --prefix=${PREFIX}
    make
    make install
    cd ..
    rm -rf unidic-mecab-2.1.2_src
    rm -f unidic-mecab-2.1.2_src.zip
    echo "*** INSTALL DONE MeCab-Unidic ***"
fi


./configure --perl=${PERL} --java=${JAVA} --crf-dir=${PREFIX}/bin \
    --svm-tool-dir=${PREFIX}/bin --yamcha-dir=${PREFIX}/bin \
    --mecab-dir=${PREFIX}/bin --mecab-dic-dir=${PREFIX}/lib/mecab/dic
