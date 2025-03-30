# Comainu
Comainu is middle-unit-word and long-unit-word analyzer.

## Download and Install (Linux)
1. Download source or git clone
  - [Download source file](https://drive.google.com/drive/u/2/folders/19XT6NhY4jvT0Eyu7lzH-V4u9vbmB1vDQ) and Extract
  ```
  tar -xzf Comainu-0.80-src.tgz
  ```
  - git clone
  ```
  git clone https://github.com/skozawa/Comainu.git Comainu-0.80
  ```

2. [Download model file](https://drive.google.com/drive/u/2/folders/19XT6NhY4jvT0Eyu7lzH-V4u9vbmB1vDQ)

  *The unarchieved model size is about 1.2 GB.
  ```
  tar -xzf Comainu-0.80-model.tgz
  ```

3. Install

  Run either one of the following two ways to configure
  - Configuration including related tools install
    - CRF++, TinySVM, Yamcha, MeCab, unidic-mecab, sqlite3, unidic2, and perl will be installed
    - Note: This script takes about one hour
    - This script require gcc, wget, curl, tar, bzip2, patch, unzip and sed commands
  ```
  ./script/setup.sh
  ```
  - only configuration
    - Already installed required tools (CRF++, Yamcha, MeCab, etc.)
  ```
  ./configure
  ```

## Requirements
- UNIX:
  - OS: Linux
  - Perl: 5.10.1 or later
  - [YamCha](http://chasen.org/~taku/software/yamcha/): 0.33 or later
    - [TinySVM](http://chasen.org/~taku/software/TinySVM/) 0.09 or later OR [SVM-Light](http://svmlight.joachims.org/) 6.02 or later
  - [CRF++](http://taku910.github.io/crfpp/): 0.58 or later

- Require for morphological analysis
  - [MeCab](http://taku910.github.io/mecab/): mecab-0.98 or later
  - [UniDic-MeCab](https://clrd.ninjal.ac.jp/unidic/back_number.html): unidic-mecab-2.1.1 or later
  - Unidic2: unidic-2.1.0 or later
    - [SQLite](https://www.sqlite.org/cli.html): 3.8 or later
    - perl-DBI, perl-DBD-SQLite

- Require for middle-word analysis
  - Java runtime: Java 1.6.0 or later
  - [MSTParser](http://www.seas.upenn.edu/~strctlrn/MSTParser/MSTParser.html): MSTParser 0.5.0 or later (bundled)

## Usage

### Analyze plain text
Comainu analyzes long-unit-word, middle-unit-word and bunsetsu boudnary. (short-unit-word is analyzed by MeCab and UniDic-MeCab)
- plain2longout 
```
$ echo "固有名詞に関する論文を執筆した" | ./script/comainu.pl plain2longout
B	固有	コユー	コユウ	固有	名詞-普通名詞-形状詞可能			漢	名詞-普通名詞-一般	**	コユウメイシ	固有名詞	固有名詞
	名詞	メーシ	メイシ	名詞	名詞-普通名詞-一般			漢	*	*	*	*	**
	に	ニ	ニ	に	助詞-格助詞			和	助詞-格助詞	*	*	ニカンスル	に関する	に関する
	関する	カンスル	カンスル	関する	動詞-一般	サ行変格	連体形-一般	混	*	**	*	*	*
	論文	ロンブン	ロンブン	論文	名詞-普通名詞-一般			漢	名詞-普通名詞-一般	*	*	ロンブン	論文	論文
	を	オ	ヲ	を	助詞-格助詞			和	助詞-格助詞	*	*	ヲ	を	を
	執筆	シッピツ	シッピツ	執筆	名詞-普通名詞-サ変可能			漢	動詞-一般	サ行変格	連用形-一般	シッピツスル	執筆する	執筆し
	し	シ	スル	為る	動詞-非自立可能	サ行変格	連用形-一般	和	*	*	*	**	*
	た	タ	タ	た	助動詞	助動詞-タ	終止形-一般	和	助動詞	助動詞-タ	終止形-一般	タ	た	た
EOS
```
- plain2midout
```
$ echo "固有名詞に関する論文を執筆した" | ./script/comainu.pl plain2midout
B	固有	コユー	コユウ	固有	名詞-普通名詞-形状詞可能			漢	*	*	コユウメイシ	固有名詞	*	1	0	固有名詞
	名詞	メーシ	メイシ	名詞	名詞-普通名詞-一般			漢	*	*	*	*	**	0
	に	ニ	ニ	に	助詞-格助詞			和	*	*	ニカンスル	に関する	*	3	1	に関する
	関する	カンスル	カンスル	関する	動詞-一般	サ行変格	連体形-一般	混	*	**	*	*	*	1
	論文	ロンブン	ロンブン	論文	名詞-普通名詞-一般			漢	*	*	ロンブン	論文	*	*	2	論文
	を	オ	ヲ	を	助詞-格助詞			和	*	*	ヲ	を	*	*3	を
	執筆	シッピツ	シッピツ	執筆	名詞-普通名詞-サ変可能			漢	サ行変格	連用形-一般	シッピツスル	執筆する	*	7	4	執筆し
	し	シ	スル	為る	動詞-非自立可能	サ行変格	連用形-一般	和	*	*	*	**	*	4
	た	タ	タ	た	助動詞	助動詞-タ	終止形-一般	和	助動詞-タ	終止形-一般	タ	た	*	*	5	た
EOS
```
- plain2bnstout
```
$ echo "固有名詞に関する論文を執筆した" | ./script/comainu.pl plain2bnstout
*B
B	固有	コユー	コユウ	固有	名詞-普通名詞-形状詞可能			漢
	名詞	メーシ	メイシ	名詞	名詞-普通名詞-一般			漢
	に	ニ	ニ	に	助詞-格助詞			和
	関する	カンスル	カンスル	関する	動詞-一般	サ行変格	連体形-一般	混
*B
	論文	ロンブン	ロンブン	論文	名詞-普通名詞-一般			漢
	を	オ	ヲ	を	助詞-格助詞			和
*B
	執筆	シッピツ	シッピツ	執筆	名詞-普通名詞-サ変可能			漢
	し	シ	スル	為る	動詞-非自立可能	サ行変格	連用形-一般	和
	た	タ	タ	た	助動詞	助動詞-タ	終止形-一般	和
EOS
```
- plain2longbnstout
```
$ ./script/comainu.pl plain2longbnstout --input sample/plain/sample.txt --output-dir out
```
- plain2midbnstout
```
$ ./script/comainu.pl plain2midbnstout --input sample/plain/sample.txt --output-dir out
```

### Analyze BCCWJ text
- bccwj2longout
```
$ ./script/comainu.pl bccwj2longout --input sample/sample.bccwj.txt
OC01_00001_c    10	30	B	詰め	ツメル	詰める		動詞-一般	下一段-マ行	連用形-一般		ツメ	ツメル	ツメ	ツメル	ツメ	ツメル	詰める	詰め	詰める	和			詰め	10	B	B	詰め将棋	ツメショウギ	詰め将棋	名詞-普通名詞-一般	*	*
OC01_00001_c	30	50		将棋	ショウギ	将棋		名詞-普通名詞-一般				ショーギ	ショーギ	ショウギ	ショウギ	ショウギ	ショウギ	将棋	将棋	将棋	漢			将棋	20		Ia	*	*	*	*	*	*
OC01_00001_c	50	60		の	ノ	の		助詞-格助詞				ノ	ノ	ノ	ノ	ノ	ノ	の	の	の	和			の	30		Ba	の	ノ	の	助詞-格助詞	*	*
OC01_00001_c	60	70		本	ホン	本		名詞-普通名詞-一般				ホン	ホン	ホン	ホン	ホン	ホン	本	本	本	漢			本	40	B	Ba	本	ホン	本	名詞-普通名詞-一般	*	*
OC01_00001_c	70	80		を	ヲ	を		助詞-格助詞				オ	オ	ヲ	ヲ	ヲ	ヲ	を	を	を	和			を	50		Ba	を	ヲ	を	助詞-格助詞	*	*
OC01_00001_c	80	100		買っ	カウ	買う		動詞-一般	五段-ワア行-一般	連用形-促音便		カッ	カウ	カッ	カウ	カッカウ	買う	買っ	買う	和			買っ	60	B	B	買っ	カウ	買う	動詞-一般	五段-ワア行-一般	連用形-促音便
OC01_00001_c	100	110		て	テ	て		助詞-接続助詞				テ	テ	テ	テ	テ	テ	て	て	て	和			て	70		Ba	て	テ	て	助詞-接続助詞	*	*
...
```
- bccwj2midout
```
$ ./script/comainu.pl bccwj2midout --input sample/sample.bccwj.txt --output-dir out
```
- bccwj2bnstout
```
$ ./script/comainu.pl bccwj2bnstout --input sample/sample.bccwj.txt --output-dir out
```
- bccwj2longbnstout
```
$ ./script/comainu.pl bccwj2longbnstout --input sample/sample.bccwj.txt --output-dir out
```
- bccwj2midbnstout
```
$ ./script/comainu.pl bccwj2midbnstout --input sample/sample.bccwj.txt --output-dir out
```
- bccwjlong2midout
```
$ ./script/comainu.pl bccwjlong2midout --input sample/sample.bccwj.txt --output-dir out
```

### Analyze KC text
- kc2longout
```
$ ./script/comainu.pl kc2longout --input sample/sample.KC
B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋
Ia 将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
Ba の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
Ba 本 ホン 本 名詞-普通名詞-一般 * * ホン ホン 本 本 * * 漢 名詞-普通名詞-一般 * * ホン 本 本
Ba を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 助詞-格助詞 * * ヲ を を
B 買っ カウ 買う 動詞-一般 五段-ワア行-一般 連用形-促音便 カッ カウ 買う 買っ * * 和 動詞-一般 五段-ワア行-一般 連用形-促音便 カウ 買う 買っ
Ba て テ て 助詞-接続助詞 * * テ テ て て * * 和 助詞-接続助詞 * * テ て て
B き クル 来る 動詞-非自立可能 カ行変格 連用形-一般 キ クル 来る 来 * * 和 動詞-一般 カ行変格 連用形-一般 クル 来る き
Ba まし マス ます 助動詞 助動詞-マス 連用形-一般 マシ マス ます まし * * 和 助動詞 助動詞-マス 連用形-一般 マス ます まし
Ba た タ た 助動詞 助動詞-タ 終止形-一般 タ タ た た * * 和 助動詞 助動詞-タ 終止形-一般 タ た た
Ba 。 * 。 補助記号-句点 * *   。 。 * * 記号 補助記号-句点 * *  。 。
EOS
...
```
- kc2bnstout
```
$ ./script/comainu.pl kc2bnstout --input sample/sample.KC --output-dir out
```
- kclong2midout
```
$ ./script/comainu.pl kclong2midout --input sample/sample_mid.KC --output-dir out
```

### Train model
- kc2longmodel
```
$ ./script/comainu.pl kc2longmodel sample/sample.KC sample_train 
```
- kclong2midmodel
```
$ ./script/comainu.pl kclong2midmodel sample/sample_mid.KC sample_train
```
- kc2bnstmodel
```
$ ./script/comainu.pl kc2bnstmodel sample/sample.KC sample_train
```

### Evaluate model
- kc2longeval
```
$ ./script/comainu.pl kc2longeval sample/sample.KC out/sample.KC.lout out
```
- kclong2mideval
```
$ ./script/comainu.pl kclong2mideval sample/sample_mid.KC out/sample_mid.KC.mout out
```
- kc2bnsteval
```
$ ./script/comainu.pl kc2bnsteval sample/sample.KC out/sample.KC.bout out
```

## Input/Output format
Under construction


## For Developer
### Test
- Add test module
```
$ ./local/opt/perl-${PERL_VERSION}/bin/cpanm install Test::Mock::Guard Test::Class
```
- Test
```
$ ./local/opt/perl-${PERL_VERSION}/bin/prove t/
```
- Run samples
```
sh t/sample-exec.sh
```

### Packaging
- upgrade versions
- configure or setup
- make destribution for Linux (on Linux)
```
$ make dist-src
$ make dist-model
```
- make destribution for Windows (on Windows)
```
$ make dist
```
