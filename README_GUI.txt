
	Comainu version 0.72

０．動作環境
MS-Windows:
  OS: MS-Windows NT5.0以上(Windows XPで動作確認)

UNIX:
  OS: Linux
  Perl: 5.10.1 以上
  Perl/Tk: 804.028 以上 (optional)

共通:
  YamCha: 0.33 以上
    MS-Windowsでの想定インストール先
      C:\Program Files\yamcha-0.33

形態素解析を利用する場合は以下も必要。

  MeCab:
    mecab-0.98 以上

  UniDic-MeCab:
    unidic-mecab-2.1.2 以上

  Unidic2:
    unidic-2.1.0 以上（同梱）

  CRF++
    CRF++-0.58 以上

中単位解析をする場合は以下も必要。

  Java runtime
    Java 1.6.0 以上

  MSTParser
    MSTParser 0.5.0 以上（同梱）

１．インストール方法
MS-Windows:
  Comainu-X_XX-win32.exe
  Comainu-X_XX-model-win32.exe
  をそれぞれダブルクリックしてインストールプログラムを起動し、
  指示に従ってプログラムとモデルのインストールを行う。

UNIX:
  Comainu-X_XX-src.tgzを展開する。

    $ tar zxf Comainu-X_XX-src.tgz

  Comainu-X_XX-model.tgzを展開する。

    $ tar zxf Comainu-X_XX-model.tgz

  実行環境を設定する。

    $ ./configure

２．起動方法
Windows:
  スタートメニュー
    ->すべてのプログラム
      ->Comainu X.XX
        ->Comainu X.XX

  または、コマンドプロンプトからインストール先フォルダで次を実行。

    bin\runcom.exe script\wincomainu.pl

UNIX:
  $ perl ./script/wincomainu.pl


３．使用方法
３．１．メインウィンドウ
  ファイルメニュー：
    (F)ファイル
      (N)新しいウィンドウ        Ctrl+N
        新しいウィンドウを開きます。

      (O)開く                    Ctrl+O
        入力ファイルを開いて入力テキストに設定します。

      (S)名前を付けて保存 ...    Ctrl+S
        出力テキストを指定した出力ファイルに保存します。

      (C)閉じる                  Ctrl+W
        ウィンドウを閉じます。

      (X)終了                    Ctrl+Q
        終了します。

    (E)編集
      (U)元に戻す                Ctrl+Z
        テキストエリアの変更を元に戻します。

      (R)やり直す                Ctrl+Y
        テキストエリアの変更を元に戻します。

      (X)切り取り                Ctrl+X
        テキストエリアの選択範囲を切り取ります。

      (C)コピー                  Ctrl+C
        テキストエリアの選択範囲をコピーします。

      (V)貼り付け                Ctrl+V
        テキストエリアにコピーを貼り付けます。

      (A)すべて選択              Ctrl+A
        テキストエリアの内容をすべて選択します。

    (T)ツール
      (I)入力
        入力種別を選択します。

      (O)出力
        出力種別を選択します。

      (M)モデル
        モデル種別を選択します。

      (T)形態素解析
        形態素解析種別を選択します。

      (K)境界
        境界を選択します。（文または単語）

      (A)解析                    Alt+A
        入力テキストを解析し、出力テキストに結果を表示します。

      (B)バッチ解析              Alt+B
        バッチ解析ダイアログを開きます。

      (C)入力クリア              Alt+C
        入力テキスト、出力テキストをクリアします。

      (D)キャッシュクリア        Alt+D
        キャッシュをクリアします。

      (O)設定　                  Alt+O
        設定ダイアログを開きます。

    (H)ヘルプ
      (H)ヘルプ                  F1
        ヘルプを表示します。

      (A)WinComainuについて
        WinComainuの情報を表示します。


  ツールバー：
    [入力]コンボボックス
        入力種別を選択します。

    [出力]コンボボックス
        出力種別を選択します。

    [モデル]コンボボックス
        モデル種別を選択します。

    [形態素解析]コンボボックス
        形態素解析種別を選択します。

    [境界]コンボボックス
        文境界または単語境界を選択します。

    [解析]ボタン
        入力テキストを解析し、出力テキストに結果を表示します。

    [バッチ解析]ボタン
        バッチ解析ダイアログを開きます。

    [入力クリア]ボタン
        入力テキスト、出力テキストをクリアします。

    [キャッシュクリア]ボタン
        キャッシュをクリアします。

  入力テキストペイン：
    入力ファイルと入力テキストを表示します。

    [開く]ボタン
        入力ファイルを開いて入力テキストに設定します。

    [折り返し]チェックボタン
        入力テキストエリアを折り返します。

    [変更不可]チェックボタン
        入力テキストエリアを変更不可にします。

  出力テキストペイン：
    出力ファイルと出力テキストを表示します。

    [保存]ボタン
        出力テキストを指定したファイルに保存します。

    [折り返し]チェックボタン
        出力テキストエリアを折り返します。

    [変更不可]チェックボタン
        出力テキストエリアを変更不可にします。


３．２．設定ダイアログ
  各種設定を変更します。
  設定内容はインストール先の"wincomainu.conf"に保存されます。
  （Windowsの場合は"%APPDATA%\wincomainu.conf"）

  [入出力]タブ：
    入出力ファイル／ディレクトリの設定

  [Comainu]タブ：
    Comainuと関連ツールに関する設定

  [その他]タブ：
    その他設定


４．モデル作成、評価
  コマンドラインから実行することでモデル作成、評価ができます。
  MS-Windows上で実行する場合は、MSYS/MinGWまたはCygwin環境が必要です。
  モデル作成にはTinySVM、評価にはdiffコマンドが必要です。
  詳細はREADME_CUI.txtを参照ください。

    長単位モデル作成
    COMAINU-METHOD: kc2longmodel
      Usage: ./script/comainu.pl kc2longmodel <train-kc> <long-model-dir>
      This command trains model from <train-kc> into <long-model-dir>.
    
      ex.)
      $ perl ./script/comainu.pl kc2longmodel sample/sample.KC train
        -> train/sample.KC.model
    
    長単位評価
    COMAINU-METHOD: kc2longeval
      Usage: ./script/comainu.pl kc2longeval <ref-kc> <kc-lout> <out-dir>
        This command make a evaluation for <kc-lout> with <ref-kc>.
        The result is put into <out-dir>.
    
      ex.)
      perl ./script/comainu.pl kc2longeval sample/sample.KC out/sample.KC.lout out
        -> out/sample.eval.long
    
    中単位モデル作成
    COMAINU-METHOD: kclong2midmodel
      Usage: ./script/comainu.pl kclong2midmodel <train-kc> <mid-model-dir>
        This command trains model from <train-kc> into <mid-model-dir>.
    
      ex.)
      $ perl ./script/comainu.pl kclong2midmodel sample/sample.KC train
        -> train/sample.KC.model
    
    中単位評価
    COMAINU-METHOD: kclong2mideval
      Usage: ./script/comainu.pl kclong2mideval <ref-kc> <kc-mout> <out-dir>
        This command make a evaluation for <kc-mout> with <ref-kc>.
        The result is put into <out-dir>.
    
      ex.)
      perl ./script/comainu.pl kclong2mideval sample/sample.KC out/sample.KC.mout out
        -> out/sample.eval.mid


Copyright (C) 2010-2014 The UniDic Consortium (UCHIMOTO Kiyotaka, KOZAWA Shunsuke, DEN Yasuharu). All rights reserved.
