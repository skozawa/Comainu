
                    Comainu 0.70

0. Requirements
  Common:
    GCC:          3.4.4 or later (optional: to built, Cygwin/MinGW on MS-Windows)
    Perl:         5.10.0 or later (recomended Active Perl on MS-Windows)
    Java:         1.6.0 or later (optional: for mid analysis)
    YamCha:       0.33 or lator
    UniDic2:      2.1.0 or later (optional)
    MeCab:        0.98 or lator  (optional)
    UniDic-MeCab: 2.1.1 or lator (optional)
    TinySVM:      0.09 or lator  (optional: to make model)
    CRF++         0.54 or lator  (optional)
    MSTParser:    0.50 or lator  (bundled)

  UNIX/Linux:
    UNIX utility: sed, make, gzip, diff, uniq, sort, basename, dirname

  MS-Windows:
    POSIX system: Cygwin or Msys/MinGW


1. How to build
  Type the next command to build.
  You need not 'make install' because it should be installed in place.

    $ ./configure

  You have to give "configure" some options to customize.
  Type "./configure --help" to see the detail.

    For UNIX/Linux:
      ex.)
      $ ./configure --yamcha-dir "/usr/local/bin" \
                    --mecab-dir "/usr/local/bin" \
                    --mecab-dic-dir "/usr/local/lib/mecab/dic" \
                    --unidic-db "/usr/local/unidic2/share/unidic.db" \
                    --svm-tool-dir "/usr/local/bin" \
                    --crf-dir "/usr/local/bin" \
                    --perl "/usr/bin/perl" \
                    --java "/usr/bin/java"

    For MSYS/MinGW or Cygwin (MS-Windows):
      ex.)
      $ ./configure --yamcha-dir "c:/yamcha-0.33/bin" \
                    --mecab-dir "c:/Program Files/MeCab/bin" \
                    --mecab-dic-dir 'c:/Program Files/MeCab/dic" \
                    --unidic-db "c:/Program Files/unidic2/share/unidic.db" \
                    --svm-tool-dir "c:/TinySVM-0.09/bin" \
                    --crf-dir "c:/CRF++-0.54" \
                    --perl "c:/Perl/bin/perl" \
                    --java "c:/usr/bin/java"

    * You have to specify the place of binaries for --yamcha-dir,
      --mecab-dir and --svm-tool-dir.
    * You have to specify the perl program for --perl.

2. Usage
  The top level script of Comainu is generalized by COMAINU-METHOD and
  some arguments.
  Many options are set default by "./configure".
  You can also set them again from command line options or environment
  variables.

  You can see the help message by "--help" and "--help-method" options.
  You can know the list of COMAINU-METHOD by "--list-method" option.

ex.)
$ ./script/comainu.pl --help
------------------------------------------------------------
./script/comainu.pl --help

Usage : ./script/comainu.pl [options] <COMAINU-METHOD>  [<arg> ...]
  This script is front end of COMAINU.

option:
    --help                              show this message and exit
    --debug             LEVEL           specify the debug level
                                          (curr: '0')
    --version                           show version string
    --help-method                       show the help of COMAINU-METHOD
    --list-method                       show the list of COMAINU-METHOD
    --force                             ignore cheking path of sub tools
    --boundary          BOUNDARY        specify the type of boundary
                                          BOUNDARY:=sentence|word
                                          (curr: 'sentence')
    --luwmrph           LUWMRPH         whether to output morphology of long-unit-word
                                          LUWMRPH:=with|without
                                          (curr: 'with')
    --luwmodel          LUWMODEL        specify the type of the model for boundary of long-unit-word
                                          LUWMODEL:=SVM|CRF
                                          (curr: 'CRF')
    --perl                     PERL                    specify PERL
    --java                     JAVA                    specify JAVA
    --comainu-home             COMAINU_HOME            specify COMAINU_HOME
    --ofilter                  OFILTER                 specify OFILTER
    --yamcha-dir               YAMCHA_DIR              specify YAMCHA_DIR
    --mecab-dir                MECAB_DIR               specify MECAB_DIR
    --mecab-dic-dir            MECAB_DIC_DIR           specify MECAB_DIC_DIR
    --unidic-db                UNIDIC_DB               specify UNIDIC_DB
    --svm-tool-dir             SVM_TOOL_DIR            specify SVM_TOOL_DIR
    --crf-dir                  CRF_DIR                 specify CRF_DIR
    --mstparser-dir            MSTPARSER_DIR           specify MSTPARSER_DIR
    --comainu-bi-model-dir     COMAINU_BI_SVM_MODEL    specify COMAINU_BI_SVM_MODEL
    --comainu-output           COMAINU_OUTPUT          specify COMAINU_OUTPUT
    --comainu-temp             COMAINU_TEMP            specify COMAINU_TEMP

Preset Environments :
  PERL=/usr/bin/perl
  JAVA=
  COMAINU_HOME=/usr/local/Comainu-0.52
  OFILTER=
  YAMCHA_DIR=/usr/local/bin
  MECAB_DIR=/usr/local/bin
  MECAB_DIC_DIR=/usr/local/lib/mecab/dic
  UNIDIC_DB=/usr/local/unidic2/share/unidic.db
  SVM_TOOL_DIR=/usr/local/bin
  CRF_DIR=/usr/local/bin
  MSTPARSER_DIR=mstparser
  COMAINU_BI_SVM_MODEL=train/BI_model
  COMAINU_OUTPUT=out
  COMAINU_TEMP=tmp/temp

------------------------------------------------------------

ex.)
$ ./script/comainu.pl --help-method
------------------------------------------------------------

COMAINU-METHOD: bccwj2bnstout
  Usage: ./script/comainu.pl bccwj2bnstout <test-kc> <bnst-model-file> <out-dir>
    This command analyzes <test-kc> with <bnst-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl bccwj2bnstout sample/sample.bccwj.txt train/bnst.model out
    -> out/sample.bccwj.txt.bout

COMAINU-METHOD: bccwj2longbnstout
  Usage: ./script/comainu.pl bccwj2longbnstout <test-bccwj> <long-model-file> <bnst-model-file> <out-dir>
    This command analyzes <test-bccwj> with <long-model-file> and <bnst-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl bccwj2longbnstout sample/sample.bccwj.txt train/CRF/train.KC.model train/bnst.model out
    -> out/sample.bccwj.txt.lbout

COMAINU-METHOD: bccwj2longout
  Usage: ./script/comainu.pl bccwj2longout <test-bccwj> <long-model-file> <out-dir>
    This command analyzes <test-bccwj> with <long-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl bccwj2longout sample/sample.bccwj.txt train/CRF/sample.KC.model out
    -> out/sample.bccwj.txt.lout
  $ perl ./script/comainu.pl bccwj2longout --luwmodel=SVM sample/sample.bccwj.txt train/SVM/sample.KC.model out
    -> out/sample.bccwj.txt.lout

COMAINU-METHOD: bccwj2midbnstout
  Usage: ./script/comainu.pl bccwj2midbnstout <test-kc> <long-model-file> <mid-model-file> <bnst-model-file> <out-dir>
    This command analyzes <test-kc> with <long-model-file>, <mid-model-file> and <bnst-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl bccwj2midbnstout sample/sample.bccwj.txt trian/SVM/train.KC.model train/MST/train.KC.model train/bnst.model out
    -> out/sample.bccwj.txt.mbout

COMAINU-METHOD: bccwj2midout
  Usage: ./script/comainu.pl bccwj2midout <test-kc> <long-model-file> <mid-model-file> <out-dir>
    This command analyzes <test-kc> with <long-model-file> and <mid-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl bccwj2midout sample/sample.bccwj.txt trian/SVM/train.KC.model train/MST/train.KC.model out
    -> out/sample.bccwj.txt.mout

COMAINU-METHOD: bccwjlong2midout
  Usage: ./script/comainu.pl bccwjlong2midout <test-kc> <mid-model-file> <out-dir>
    This command analyzes <test-kc> with <mid-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl bccwjlong2midout sample/sample.bccwj.txt train/MST/train.KC.model out
    -> out/sample.bccwj.txt.mout

COMAINU-METHOD: kc2bnsteval
  Usage: ./script/comainu.pl kc2bnsteval <ref-kc> <kc-lout> <out-dir>
    This command make a evaluation for <kc-lout> with <ref-kc>.
    The result is put into <out-dir>.

  ex.)
  perl ./script/comainu.pl kc2bnsteval sample/sample.KC out/sample.KC.bout out
    -> out/sample.eval.bnst

COMAINU-METHOD: kc2bnstmodel
  Usage: ./script/comainu.pl kc2bnstmodel <train-kc> <bnst-model-dir>
    This command trains model from <train-kc> into <bnst-model-dir>.

  ex.)
  $ perl ./script/comainu.pl kc2bnstmodel sample/sample.KC train
    -> train/sample.KC.model

COMAINU-METHOD: kc2bnstout
  Usage: ./script/comainu.pl kc2bnstout <test-kc> <bnst-model-file> <out-dir>
    This command analyzes <test-kc> with <bnst-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl kc2bnstout sample/sample.KC train/bnst.model out
    -> out/sample.KC.bout

COMAINU-METHOD: kc2longeval
  Usage: ./script/comainu.pl kc2longeval <ref-kc> <kc-lout> <out-dir>
    This command make a evaluation for <kc-lout> with <ref-kc>.
    The result is put into <out-dir>.

  ex.)
  perl ./script/comainu.pl kc2longeval sample/sample.KC out/sample.KC.lout out
    -> out/sample.eval.long

COMAINU-METHOD: kc2longmodel
  Usage: ./script/comainu.pl kc2longmodel <train-kc> <long-model-dir>
    This command trains model from <train-kc> into <long-model-dir>.

  ex.)
  $ perl ./script/comainu.pl kc2longmodel sample/sample.KC train
    -> train/sample.KC.model

COMAINU-METHOD: kc2longout
  Usage: ./script/comainu.pl kc2longout <test-kc> <long-model-file> <out-dir>
    This command analyzes <test-kc> with <long-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl kc2longout sample/sample.KC train/CRF/train.KC.model out
    -> out/sample.lout
  $ perl ./script/comainu.pl kc2longout --luwmodel=SVM sample/sample.KC sample/SVM/train.KC.model out
    -> out/sample.KC.lout

COMAINU-METHOD: kclong2mideval
  Usage: ./script/comainu.pl kclong2mideval <ref-kc> <kc-mout> <out-dir>
    This command make a evaluation for <kc-mout> with <ref-kc>.
    The result is put into <out-dir>.

  ex.)
  perl ./script/comainu.pl kclong2mideval sample/sample.KC out/sample.KC.mout out
    -> out/sample.eval.mid

COMAINU-METHOD: kclong2midmodel
  Usage: ./script/comainu.pl kclong2midmodel <train-kc> <mid-model-dir>
    This command trains model from <train-kc> into <mid-model-dir>.

  ex.)
  $ perl ./script/comainu.pl kclong2midmodel sample/sample.KC train
    -> train/sample.KC.model

COMAINU-METHOD: kclong2midout
  Usage: ./script/comainu.pl kclong2midout <test-kc> <mid-model-file> <out-dir>
    This command analyzes <test-kc> with <mid-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl kclong2midout sample/sample.KC train/MST/train.KC.model out
    -> out/sample.KC.mout

COMAINU-METHOD: plain2bnstout
  Usage: ./script/comainu.pl plain2bnstout <test-text> <bnst-model-file> <out-dir>
    This command analyzes <test-text> with MeCab and <bnst-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl plain2bnstout sample/plain/sample.txt train/bnst.model out
    -> out/sample.txt.bout

COMAINU-METHOD: plain2longbnstout
  Usage: ./script/comainu.pl plain2longbnstout <test-text> <long-model-file> <bnst-model-file> <out-dir>
    This command analyzes <test-text> with Mecab and <long-model-file> and <bnst-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl plain2longbnstout sample/plain/sample.txt train/CRF/train.KC.model train/bnst.model out
    -> out/sample.txt.lbout

COMAINU-METHOD: plain2longout
  Usage: ./script/comainu.pl plain2longout <test-text> <long-model-file> <out-dir>
    This command analyzes <test-text> with MeCab and <long-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl plain2longout sample/plain/sample.txt train/CRF/train.KC.model out
    -> out/sample.txt.lout

COMAINU-METHOD: plain2midbnstout
  Usage: ./script/comainu.pl plain2midbnstout <test-text> <long-model-file> <mid-model-file> <bnst-model-file> <out-dir>
    This command analyzes <test-text> with Mecab and <long-model-file>, <mid-model-file> and <bnst-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl plain2midbnstout sample/plain/sample.txt train/CRF/train.KC.model train/MST/train.KC.model train/bnst.model out
    -> out/sample.txt.mbout

COMAINU-METHOD: plain2midout
  Usage: ./script/comainu.pl plain2midout <test-text> <long-model-file> <mid-model-file> <out-dir>
    This command analyzes <test-text> with Mecab and <long-model-file> and <mid-model-file>.
    The result is put into <out-dir>.

  ex.)
  $ perl ./script/comainu.pl plain2midout sample/plain/sample.txt train/CRF/train.KC.model train/MST/train.KC.model out
    -> out/sample.txt.mout

------------------------------------------------------------

3. Distribution

  You can make the packages for distribution with the next command.

    $ make dist

  It will make the packages under "pkg/dist" directory.

    Comainu-X_XX-src.tgz             ... tar ball of the source code
    Comainu-X_XX-model.tgz           ... tar ball of the model
    Comainu-X_XX-win32.exe           ... Windows Installer for the program
    Comainu-X_XX-model-win32.exe     ... Windows Installer for the model

  If you are on UNIX, it will make *.tgz files only.
  You need "Inno Setup 5" and Cygwin/MinGW to build *.exe files.


Copyright (C) 2010-2011 The UniDic Consortium (UCHIMOTO Kiyotaka, KOZAWA Shunsuke, DEN Yasuharu). All rights reserved.
