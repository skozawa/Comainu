
                    Comainu 0.72

0. Requirements
  Common:
    GCC:          3.4.4 or later (optional: to built, Cygwin/MinGW on MS-Windows)
    Perl:         5.10.1 or later (recomended Active Perl on MS-Windows)
    Java:         1.6.0 or later (optional: for mid analysis)
    YamCha:       0.33 or lator
    UniDic2:      2.1.0 or later (optional)
    MeCab:        0.98 or lator  (optional)
    UniDic-MeCab: 2.1.2 or lator (optional)
    TinySVM:      0.09 or lator  (optional: to make model)
    CRF++         0.58 or lator  (optional)
    MSTParser:    0.50 or lator  (bundled)

  UNIX/Linux:
    UNIX utility: sed, make, gzip, diff, uniq, sort, basename, dirname

  MS-Windows:
    POSIX system: Cygwin or Msys/MinGW


1. How to build
  Type the next command to build.
  You need not 'make install' because it should be installed in place.
  You use script/setup.sh if you need to install required tools.

    $ ./script/setup.sh

  Otherwise

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
                    --crf-dir "c:/CRF++-0.58" \
                    --perl "c:/Perl/bin/perl" \
                    --java "c:/usr/bin/java"

    * You have to specify the place of binaries for --yamcha-dir,
      --mecab-dir, --mecab-dic-dir, unidic-db, --svm-tool-dir and --crf-dir.
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

  option
    --help                           show this message and exit
    --debug          LEVEL           specify the debug level (default: 0)
    --version                        show version string
    --help-method                    show the help of COMAINU-METHOD
    --list-method                    show the list of COMAINU-METHOD
    --force                          ignore cheking path of sub tools
    --perl                    PERL                    specify PERL
    --java                    JAVA                    specify JAVA
    --comainu-home            COMAINU_HOME            specify COMAINU_HOME
    --yamcha-dir              YAMCHA_DIR              specify YAMCHA_DIR
    --mecab-dir               MECAB_DIR               specify MECAB_DIR
    --mecab-dic-dir           MECAB_DIC_DIR           specify MECAB_DIC_DIR
    --unidic-db               UNIDIC_DB               specify UNIDIC_DB
    --svm-tool-dir            SVM_TOOL_DIR            specify SVM_TOOL_DIR
    --crf-dir                 CRF_DIR                 specify CRF_DIR
    --mstparser-dir           MSTPARSER_DIR           specify MSTPARSER_DIR
    --comainu-bi-model-dir    COMAINU_BI_MODEL_DIR    specify COMAINU_BI_MODEL_DIR
    --comainu-temp            COMAINU_TEMP            specify COMAINU_TEMP

Preset Environments :
  PERL=/usr/bin/perl
  JAVA=/usr/bin/java
  COMAINU_HOME=/usr/local/Comainu-0.72
  YAMCHA_DIR=/usr/local/bin
  MECAB_DIR=/usr/local/bin
  MECAB_DIC_DIR=/usr/local/lib/mecab/dic
  UNIDIC_DB=/usr/local/unidic2/share/unidic.db
  SVM_TOOL_DIR=/usr/local/bin
  CRF_DIR=/usr/local/bin
  MSTPARSER_DIR=mstparser
  COMAINU_BI_MODEL_DIR=
  COMAINU_OUTPUT=out
  COMAINU_TEMP=tmp/temp

------------------------------------------------------------

ex.)
$ ./script/comainu.pl --help-method
------------------------------------------------------------

COMAINU-METHOD: bccwj2bnstout [options]
  Usage: ./script/comainu.pl bccwj2bnstout
    This command analyzes the bunsetsu boundary with <bnstmodel>.

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)

  ex.)
  $ perl ./script/comainu.pl bccwj2bnstout
  $ perl ./script/comainu.pl bccwj2bnstout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.bout
  $ perl ./script/comainu.pl bccwj2bnstout --bnstmodel=sample_train/sample.KC.model

COMAINU-METHOD: bccwj2longbnstout
  Usage: ./script/comainu.pl bccwj2longbnstout [options]
    This command analyzes bunsetsu boudnary and long-unit-word of <input>(file or STDIN) with <bnstmodel> and <luwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --boundary                specify the type of boundary (default: sentence)
                              (sentence or word)
    --luwmrph                 whether to output morphology of long-unit-word (default: with)
                              (with or without)
    --comainu-bi-model-dir    speficy the model directory for the category models

  ex.)
  $ perl ./script/comainu.pl bccwj2longbnstout
  $ perl ./script/comainu.pl bccwj2longbnstout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.lbout
  $ perl ./script/comainu.pl bccwj2longbnstout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

COMAINU-METHOD: bccwj2longout
  Usage: ./script/comainu.pl bccwj2longout [options]
    This command analyzes long-unit-word of <input>(file or STDIN) with <luwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --boundary                specify the type of boundary (default: sentence)
                              (sentence or word)
    --luwmrph                 whether to output morphology of long-unit-word (default: with)
                              (with or without)
    --comainu-bi-model-dir    speficy the model directory for the category models

  ex.)
  $ perl ./script/comainu.pl bccwj2longout
  $ perl ./script/comainu.pl bccwj2longout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.lout
  $ perl ./script/comainu.pl bccwj2longout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

COMAINU-METHOD: bccwj2midbnstout
  Usage: ./script/comainu.pl bccwj2midbnstout [options]
    This command analyzes bunsetsu boudnary, long-unit-word and middle-unit-word of <input>(file or STDIN) with <bnstmodel>, <luwmodel> and <muwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --boundary                specify the type of boundary (default: sentence)
                              (sentence or word)
    --comainu-bi-model-dir    speficy the model directory for the category models
    --muwmodel                specify the middle-unit-word model (default: trian/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl bccwj2midbnstout
  $ perl ./script/comainu.pl bccwj2midbnstout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.mbout
  $ perl ./script/comainu.pl bccwj2midbnstout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

COMAINU-METHOD: bccwj2midout
  Usage: ./script/comainu.pl bccwj2midout [options]
    This command analyzes long-unit-word and middle-unit-word of <input>(file or STDIN) with <luwmodel> and <muwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --boundary                specify the type of boundary (default: sentence)
                              (sentence or word)
    --comainu-bi-model-dir    speficy the model directory for the category models
    --muwmodel                specify the middle-unit-word model (default: trian/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl bccwj2midout
  $ perl ./script/comainu.pl bccwj2midout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.mout
  $ perl ./script/comainu.pl bccwj2midout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

COMAINU-METHOD: bccwjlong2midout
  Usage: ./script/comainu.pl bccwjlong2midout [options]
    This command analyzes middle-unit-word of <input>(file or STDIN) with <muwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --muwmodel                specify the middle-unit-word model (default: trian/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl bccwjlong2midout
  $ perl ./script/comainu.pl bccwjlong2midout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.mout
  $ perl ./script/comainu.pl bccwjlong2midout --muwmodel=sample_train/sample_mid.KC.model

COMAINU-METHOD: kc2bnsteval
  Usage: ./script/comainu.pl kc2bnsteval <ref-kc> <kc-bout> <out-dir>
    This command makes a evaluation for <kc-bout> with <ref-kc>.
    The result is put into <out-dir>

  option
    --help                    show this message and exit

  ex.)
  $ perl ./script/comainu.pl kc2bnsteval sample/sample.KC out/sample.KC.bout out
    -> out/sample.eval.bnst

COMAINU-METHOD: kc2bnstmodel
  Usage: ./script/comainu.pl kc2bnstmodel <train-kc> <bnst-model-dir>
    This command trains the model for analyzing bunsetsu boundary with <train-kc>.
    The model is put into <bnst-model-dir>

  option
    --help                    show this message and exit

  ex.)
  $ perl ./script/comainu.pl kc2bnstmodel sample/sample.KC sample_train
    -> sample_train/sample.KC.model

COMAINU-METHOD: kc2bnstout [options]
  Usage: ./script/comainu.pl kc2bnstout
    This command analyzes the bunsetsu boundary with <bnstmodel>.

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)

  ex.)
  $ perl ./script/comainu.pl kc2bnstout
  $ perl ./script/comainu.pl kc2longout --input=sample/sample.KC --output-dir=out
    -> out/sample.KC.bout
  $ perl ./script/comainu.pl kc2longout --bnstmodel=sample_train/sample.KC.model

COMAINU-METHOD: kc2longeval
  Usage: ./script/comainu.pl kc2longeval <ref-kc> <kc-lout> <out-dir>
    This command makes a evaluation for <kc-lout> with <ref-kc>.
    The result is put into <out-dir>

  option
    --help                    show this message and exit

  ex.)
  $ perl ./script/comainu.pl kc2longeval sample/sample.KC out/sample.KC.lout out
    -> out/sample.eval.long

COMAINU-METHOD: kc2longmodel
  Usage: ./script/comainu.pl kc2longmodel <train-kc> <long-model-dir>
    This command trains the model for analyzing long-unit-word with <train-kc>.
    The model is put into <long-model-dir>

  option
    --help                    show this message and exit
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)

  ex.)
  $ perl ./script/comainu.pl kc2longmodel sample/sample.KC sample_train
    -> sample_train/sample.KC.model

COMAINU-METHOD: kc2longout
  Usage: ./script/comainu.pl kc2longout [options]
    This command analyzes long-unit-word of <input>(file or STDIN) with <luwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --boundary                specify the type of boundary (default: sentence)
                              (sentence or word)
    --luwmrph                 whether to output morphology of long-unit-word (default: with)
                              (with or without)
    --comainu-bi-model-dir    speficy the model directory for the category models

  ex.)
  $ perl ./script/comainu.pl kc2longout
  $ perl ./script/comainu.pl kc2longout --input=sample/sample.KC --output-dir=out
    -> out/sample.KC.lout
  $ perl ./script/comainu.pl kc2longout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

COMAINU-METHOD: kclong2mideval
  Usage: ./script/comainu.pl kclong2mideval <ref-kc> <kc-mout> <out-dir>
    This command makes a evaluation for <kc-mout> with <ref-kc>.
    The result is put into <out-dir>

  option
    --help                    show this message and exit

  ex.)
  $ perl ./script/comainu.pl kclong2mideval sample/sample_mid.KC out/sample_mid.KC.mout out
    -> out/sample.eval.mid

COMAINU-METHOD: kclong2midmodel
  Usage: ./script/comainu.pl kclong2midmodel <train-kc> <mid-model-dir>
    This command trains the model for analyzing middle-unit-word with <train-kc>.
    The model is put into <mid-model-dir>

  option
    --help                    show this message and exit

  ex.)
  $ perl ./script/comainu.pl kclong2midmodel sample/sample_mid.KC sample_train
    -> sample_train/sample_mid.KC.model

COMAINU-METHOD: kclong2midout
  Usage: ./script/comainu.pl kclong2midout [options]
    This command analyzes middle-unit-word of <input>(file or STDIN) with <muwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --muwmodel                specify the middle-unit-word model (default: train/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl kclong2midout
  $ perl ./script/comainu.pl kclong2midout --input=sample/sample_mid.KC --output-dir=out
    -> out/sample_mid.KC.mout

COMAINU-METHOD: plain2bnstout [options]
  Usage: ./script/comainu.pl plain2bnstout
    This command analyzes the bunsetsu boundary with <bnstmodel>.

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)

  ex.)
  $ perl ./script/comainu.pl plain2bnstout
  $ perl ./script/comainu.pl plain2bnstout --input=sample/plain/sample.txt --output-dir=out
    -> out/sample.txt.bout
  $ perl ./script/comainu.pl palin2bnstout --bnstmodel=sample_train/sample.KC.model

COMAINU-METHOD: plain2longbnstout
  Usage: ./script/comainu.pl plain2longbnstout [options]
    This command analyzes bunsetsu boudnary and long-unit-word of <input>(file or STDIN) with <bnstmodel> and <luwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --comainu-bi-model-dir    speficy the model directory for the category models

  ex.)
  $ perl ./script/comainu.pl plain2longbnstout
  $ perl ./script/comainu.pl plain2longbnstout --input=sample/plain/sample.txt --output-dir=out
    -> out/sample.txt.lbout
  $ perl ./script/comainu.pl plain2longbnstout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

COMAINU-METHOD: plain2longout
  Usage: ./script/comainu.pl plain2longout [options]
    This command analyzes long-unit-word of <input>(file or STDIN) with <luwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --comainu-bi-model-dir    speficy the model directory for the category models

  ex.)
  $ perl ./script/comainu.pl plain2longout
  $ perl ./script/comainu.pl plain2longout --input=sample/plain/sample.txt --output-dir=out
    -> out/sample.txt.lout
  $ perl ./script/comainu.pl plain2longout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

COMAINU-METHOD: plain2midbnstout
  Usage: ./script/comainu.pl plain2midbnstout [options]
    This command analyzes bunsetsu boudnary, long-unit-word and middle-unit-word of <input>(file or STDIN) with <bnstmodel>, <luwmodel> and <muwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --comainu-bi-model-dir    speficy the model directory for the category models
    --muwmodel                specify the middle-unit-word model (default: trian/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl plain2midbnstout
  $ perl ./script/comainu.pl plain2midbnstout --input=sample/plain/sample.txt --output-dir=out
    -> out/sample.txt.mbout
  $ perl ./script/comainu.pl plain2midbnstout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

COMAINU-METHOD: plain2midout
  Usage: ./script/comainu.pl plain2midout [options]
    This command analyzes long-unit-word and middle-unit-word of <input>(file or STDIN) with <luwmodel> and <muwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --comainu-bi-model-dir    speficy the model directory for the category models
    --muwmodel                specify the middle-unit-word model (default: trian/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl plain2midout
  $ perl ./script/comainu.pl plain2midout --input=sample/plain/sample.txt --output-dir=out
    -> out/sample.txt.mout
  $ perl ./script/comainu.pl plain2midout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

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


Copyright (C) 2010-2014 The UniDic Consortium (UCHIMOTO Kiyotaka, KOZAWA Shunsuke, DEN Yasuharu). All rights reserved.
