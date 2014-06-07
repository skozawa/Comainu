# Comainu for historical
Comainu is middle-unit-word and long-unit-word analyzer.

## Download and Install (Linux)
1. Download source or git clone
  - [Download source file](http://sourceforge.jp/projects/comainu-emj/) and Extract
  ```
  tar -xzf Comainu-historical-0.70-src.tgz
  ```
  - git clone
  ```
  git clone https://github.com/skozawa/Comainu.git Comainu-0.70
  git checkout origin/historical
  ```

2. [Download model file](http://sourceforge.jp/projects/comainu-emj/)

  *The unarchieved model size is about 1.2 GB.
  ```
  tar -xzf Comainu-historical-0.70-model.tgz
  ```

3. Install

  Run either one of the following two ways to configure
  - Configuration including related tools install
    - CRF++, TinySVM, Yamcha, MeCab, unidic-mecab, unidic2, and perl will be installed
    - *This script takes about one hour
    - This script require gcc, wget, tar, patch, unzip and sed commands
  ```
  ./script/setup.sh
  ```
  - only configuration
  ```
  ./configure
  ```

## Requirements
- UNIX:
  - OS: Linux
  - Perl: 5.10.1 or later
  - YamCha: 0.33 or later
    - TinySVM 0.09 or later OR SVM-Light 6.02 or later 
  - CRF++: 0.58 or later

- Require for morphological analysis
  - MeCab: mecab-0.98 or later
  - [UniDic-MeCab-EMJ](http://www2.ninjal.ac.jp/lrc/index.php?UniDic%2F%C3%E6%B8%C5%CF%C2%CA%B8UniDic#hb89ebc9)

## Usage

### Analyze plain text
Comainu analyzes long-unit-word, middle-unit-word and bunsetsu boudnary. (short-unit-word is analyzed by MeCab and UniDic-MeCab)
- plain2longout 
```
$ echo "いづれの御時にか、女御、更衣あまたさぶらひたまひける中に、いとやむごとなき際にはあらぬが、すぐれて時めきたまふありけり。" | ./script/comainu.pl plain2longout
B       いづれ  イズレ  イズレ  何れ    代名詞                  代名詞  *       *       イズレ  何れ    いづれ
        の      ノ      ノ      の      助詞-格助詞                     助詞-格助詞     *       *       ノ      の      の
        御      オオン  オオン  御      接頭辞                  名詞-普通名詞-一般      *       *       オオントキ      御時    御時
        時      トキ    トキ    時      名詞-普通名詞-副詞可能                  *       *       *       *       *       *
        に      ニ      ニ      に      助詞-格助詞                     助詞-格助詞     *       *       ニ      に      に
        か      カ      カ      か      助詞-係助詞                     助詞-係助詞     *       *       カ      か      か
        、                      、      補助記号-読点                   補助記号-読点   *       *       、      、      、
        女御    ニョーゴ        ニョウゴ        女御    名詞-普通名詞-一般                      名詞-普通名詞-一般      *       *       ニョウゴ        女御    女御
        、                      、      補助記号-読点                   補助記号-読点   *       *       、      、      、
        更衣    コーイ  コウイ  更衣    名詞-普通名詞-サ変可能                  名詞-普通名詞-一般      *       *       コウイ  更衣    更衣
        あまた  アマタ  アマタ  数多    名詞-普通名詞-一般                      名詞-普通名詞-一般      *       *       アマタ  数多    あまた
        さぶらひ        サブライ        サブラウ        侍う    動詞-一般       文語四段-ハ行   連用形-一般     動詞-一般       文語四段-ハ行   連用形-一般     サブラウタマウ  侍う給う-尊敬   さぶらひたまひ
        たまひ  タマイ  タマウ  給う-尊敬       動詞-非自立可能 文語四段-ハ行   連用形-一般     *       *       *       *       *       *
        ける    ケル    ケリ    けり    助動詞  文語助動詞-ケリ 連体形-一般     助動詞  文語助動詞-ケリ 連体形-一般     ケリ    けり    ける
        中      ナカ    ナカ    中      名詞-普通名詞-副詞可能                  名詞-普通名詞-一般      *       *       ナカ    中      中
        に      ニ      ニ      に      助詞-格助詞                     助詞-格助詞     *       *       ニ      に      に
        、                      、      補助記号-読点                   補助記号-読点   *       *       、      、      、
        いと    イト    イト    いと    副詞                    副詞    *       *       イト    いと    いと
        やむごとなき    ヤンゴトナキ    ヤンゴトナイ    やんごとない    形容詞-一般     文語形容詞-ク   連体形-一般     形容詞-一般     文語形容詞-ク   連体形-一般     ヤンゴトナイ    やんごとない    やむごとなき
        際      キワ    キワ    際      名詞-普通名詞-一般                      名詞-普通名詞-一般      *       *       キワ    際      際
        に      ニ      ニ      に      助詞-格助詞                     助詞-格助詞     *       *       ニ      に      に
        は      ワ      ハ      は      助詞-係助詞                     助詞-係助詞     *       *       ハ      は      は
        あら    アラ    アル    有る    動詞-非自立可能 文語ラ行変格    未然形-一般     動詞-一般       文語ラ行変格    未然形-一般     アル    有る    あら
        ぬ      ヌ      ズ      ず      助動詞  文語助動詞-ズ   連体形-一般     助動詞  文語助動詞-ズ   連体形-一般     ズ      ず      ぬ
        が      ガ      ガ      が      助詞-格助詞                     助詞-格助詞     *       *       ガ      が      が
        、                      、      補助記号-読点                   補助記号-読点   *       *       、      、      、
        すぐれ  スグレ  スグレル        優れる  動詞-一般       文語下二段-ラ行 連用形-一般     動詞-一般       文語下二段-ラ行 連用形-一般     スグレル        優れる  すぐれ
        て      テ      テ      て      助詞-接続助詞                   助詞-接続助詞   *       *       テ      て      て
        時      トキ    トキ    時      名詞-普通名詞-副詞可能                  動詞-一般       文語四段-ハ行   連体形-一般     トキメクタマウ  時めく給う-尊敬 時めきたまふ
        めき    メキ    メク    めく    接尾辞-動詞的   文語四段-カ行   連用形-一般     *       *       *       *       *       *
        たまふ  タマウ  タマウ  給う-尊敬       動詞-非自立可能 文語四段-ハ行   連体形-一般     *       *       *       *       *       *
        あり    アリ    アル    有る    動詞-非自立可能 文語ラ行変格    連用形-一般     動詞-一般       文語ラ行変格    連用形-一般     アル    有る    あり
        けり    ケリ    ケリ    けり    助動詞  文語助動詞-ケリ 終止形-一般     助動詞  文語助動詞-ケリ 終止形-一般     ケリ    けり    けり
        。                      。      補助記号-句点                   補助記号-句点   *       *       。      。      。
EOS

Finish
```

## Input/Output format
Under construction
