
# Free FM TOWNS Project

## 注意
FMT_DOSはまだまともに動きません。やっとTowns OSやいくつかのゲームが動くレベルになったばかりです。未対応の機能にヒットするといきなりフリーズします。もう少し自信をもって使えるバージョンになるまでもう少しお待ちください。

このROMイメージの使用によって発生した損害など、作者は責任を負いませんので、この点ご了承の上ご利用ください。


## Disclaimer
FMT_DOS is still under development.  All it can do is start some of the FM TOWNS games, and it freezes as soon as an app tries to use an unimplemented function.  Please wait a little more before this compatible DOS can be used with confidence.

The files here are provided as is.  The developer will not take responsibilities on your loss or damage caused by the files.



## Free FM TOWNS Projectについて
このプロジェクトは、完全自己完結型FM TOWNSエミュレータの実現を目指しています。

富士通が1989年世に送り出したパソコンFM TOWNSは世界で初めてCD-ROMを標準搭載したことで、FM TOWNS用CD-ROMソフトが多数発売されました。そして、CD-ROMメディアは正しく保管すれば相当な長期間維持することができます。他のレトロPCと比べて今でもまったく問題なく実行可能なソフトのメディアが多数存在して、そしてそれを合法的に中古ソフトショップ、オークションなどを利用して購入することができます。

しかし、その実行環境は急速に失われつつあります。FM TOWNS本体、とくに内蔵CD-ROMドライブの故障が多く発生します。FM TOWNSは他社に先駆けてCD-ROMドライブを搭載してしまったもんだから、内蔵CD-ROMドライブはまったく標準規格とは違った仕様となっています。そもそも標準規格なんて存在しないときでした。

そこで、「UNZ」、「津軽」といったエミュレータの利用が考えられますが、著作権法を厳密に解釈すると、FM TOWNS本体を所有していない場合、エミュレータ実行に必要なROMイメージを利用することは著作権法違反となります。

現行の著作権法は、著作者は守りますが著作物を守りません。著作者が門を閉ざしてしまったら、二度と誰も合法的に著作物を利用することができません。著作者は、ひとたび世に送り出したソフトウェアを取り上げる権利まで持つべきなのでしょうか？著作者は著作物を殺す権利も持つべきなのでしょうか？僕はそうは思いません。著作権法は著作物も守るべきであると考えています。古いソフトをすべて無料にしろというのではありません。古いソフトウェアも合理的な金額でユーザが引き続き利用できて、開発者もそれによって利益を得ることができるルールを決めるべきだと思っています。

FM TOWNSエミュレータの実行には、最低二種類のROMイメージが必要になります。ひとつはFMT_SYSと呼ばれる、起動にかかわるプログラムが入った領域です。このROMイメージに関しては、UNZ開発者のKasanovaさんが互換ROMを開発されて、ソースコードを含めて公開されています。Kasanovaさんの公開されていたバージョンではCD-ROMドライブからの起動しかできませんが、勝手ながら僕が引き継いでフロッピーディスク、ハードディスク起動にも対応しました。

もうひとつはFMT_DOSと呼ばれる、MSDOS.SYS, COMMAND.COM, MSCDEX.EXEが入った領域です。これが問題でした。とくに、Version 3.1相当のMSDOS.SYSが必要で、MicrosoftはMS-DOS V2.0まではMITライセンスで無料としてくれたのですが、3.1はいまだ無料公開されていません。また、COMMAND.COMもVersion 3.1用バージョンが必要です。

このうち、MSDOS.SYSとほぼ互換のYSDOS.SYS, COMMAND.COM互換のYAMAND.COMの開発に成功しつつあります。まだ、多くの機能が未対応で、そういう機能にあたるといきなり止まってしまいますが、それでも、FM TOWNSを彩ったいくつかのゲーム、Towns OS GUIの起動までできるようになったので公開しました。

現状でわかっている問題点・制限は:

1. オリジナルのMSDOS.SYSでは、Drive Not Ready, Disk Write Protected, ディレクトリ破損, 未フォーマットディスクなどのエラーで INT 24H を出して、しかもユーザに中止、失敗、無視、というどれを選べばいいのかわからない選択肢をコンソールに出すという悪い癖があったが、YSDOS.SYSではINT 24Hは出さずに単にDOSのエラーを返す(必ず「失敗」を選んだのと同じ)。INT 24Hが出ることを期待しているアプリケーションは多分エラーが発生したときの動作が変になる。
2. Ctrl+Cの処理にまったく自信が無いので多分コンソールモードで押すと変になる。 (Ctrl+Cはサポートしないことにしようかと思ってる。)
3. コマンドモードで多くの内部コマンドが使用不可
4. FMT_DIC/FMT_DIC.ROMを使うとかな漢字変換でフリーズしないものの、日本語はひらがなとカタカナのみ入力可能。
5. Dungeon Masterゲーム開始時、Q:\JDATA\DUNGEON.DAT が開けなくてクラッシュ。原因は、CDDAを止めないままFOPENしようとしているため。本来は先にCDDAを止めてからアクセスするべきだが、MSCDEX.EXEだとたまたまディレクトリがキャッシュに残っていてFOPENに成功するらしい。SHSUCDXだと開くことができない。どちらかというとSHSUCDXの動作が正しい。CDDA演奏が止まってからボタンをクリックするか、あるいは、強制的にCDDAを止めてからダンジョンに入るとこの問題を回避できる。

などがあります。くれぐれも、普段使いのハードディスクイメージやフロッピーディスクイメージをこの互換ROMで利用するときは、バックアップを取った上でご使用ください。


山川機長 http://www.ysflight.com

---

##About Free FM TOWNS Project

The goal of this project is to make fully self-contained FM TOWNS emulator.

Fujitsu released a hobby personal computer FM TOWNS in 1989, which was the first computer that had an internal CD-ROM drive as a standard equipment of the minimum configuration.  All FM TOWNSes had a CD-ROM drive, which gave a significant incentive for software developers to release software titles in a CD-ROM.  CD-ROM can last long if you keep it in dry cool location.  We can still buy working media of FM TOWNS apps from a retro-game shop or from an auction legally.

However, the running environment is quickly diminishing.  FM TOWNS hardware very often has an issue with the internal CD-ROM drive.  Since Fujitsu did it too early (Fujitsu did always things too much ahead) the internal CD-ROM drive was proprietary.  In fact, there was no such thing called CD-ROM drive standard then.  Once the internal drive is broken, it is nearly impossible to find a replacement.

So you can think of using an emulator like "UNZ" and "Tsugaru".  However, if you strictly interpret the copyright law, it is illegal to use ROM images extracted from FM TOWNS unless you own a FM TOWNS computer.

The current copyright law protects the software developer, but not the software.  Once the developer closes the door, nobody can use the software legally.  Should the developer be given a right to take software away from the users?  Should a developer be allowed to kill a software that was once released to the world?  I don't think so.  The copyright law should protect the developers as well as the software.  I'm not saying make all old programs free.  I am saying there should be a rule that the user can continue using old software for reasonable price, and the developer can benefit by keeping the software available.

You need minimum two ROM images, FMT_SYS and FMT_DOS.  Others can somehow be auto-generated.  The developer of UNZ emulator, Kasanova, has also developed a compatible and free version of FMT_SYS.  He has generously opened the source code.  His version is only good for booting from CD-ROM drive, but I took over and made it bootable from Floppy and Hard disk drives.

The other ROM image, FMT_DOS, was a problem.  It includes MSDOS.SYS, COMMAND.COM, and MSCDEX.EXE.  MSCDEX.EXE can be replaced with SHSUCDX (https://github.com/adoxa/shsucd).  I really appreciate the developer of SHSUCDX for their effort to develop a compatible version of MSCDEX.  However, I still needed MSDOS.SYS and COMMAND.COM equivalent to MS-DOS Ver 3.1.  Microsoft opened MS-DOS V2.0 source code, but stopped short of V3.1.

So, I started writing YSDOS.SYS, a compatible version of DOS, and YAMAND.COM, a compatible version of COMMAND.COM.  I finally made it bootable into FM Towns OS.  So, I opened it.

Currently-known limitations are:

1. The original MSDOS.SYS had a bad habit of shooting an INT 24H on critical errors (critical from Microsoft point of view) including Drive Not Ready, Disk Write Protected, Bad Directory, Broken FAT, etc., and asking user to select Abort/Fail/Ignore, which in most case I had no idea about the difference between Ignore and Fail.  In fact, some graphical applications just went into infinite loop since the console input was disabled.  It was one of many horrible bad habit of MSDOS.SYS.  YSDOS.SYS do not shoot INT 24H.  It just returns a DOS error code.  If an application was expecting INT 24H, then the application may act strange.
2. I'm not confident at all in Ctrl-C handling.  It may go berserk if you press Ctrl+C in the command mode.  (I may disable it all together.)
3. Many of the commands are not available in command mode.
4. With FMT_DIC/FMT_DIC.ROM, OAK (IME in the today's term.  We used to call it FEP, or Front End Processor) at least does not freeze.  However, you can only type Hiragana and Katakana in the Japanese mode.
5. Dungeon Master freezes when you try to enter the dungeon.  The program tries to open Q:\JDATA\DUNGEON.DATA without stopping CDDA.  SHSUCDX correctly returns an error.  However, MSCDEX.EXE happens to have directory in the cache, and returns no error.  The program then stops CDDA and reads from the file.  This most likely is a bug that has been hiding for almost 30 years.  You can avoid this problem by force stop CDDA from the command or menu, and then click the button.  Or, wait until the CDDA music is over and then click the button.

If you want to use this ROM images with your floppy-disk or hard-disk images, MAKE SURE TO TAKE A BACK UP COPY before using.

CaptainYS http://www.ysflight.com

---

## FMT_SYSについて

FMT_SYS互換ROMは、FM TOWNSエミュレータUNZ開発者のKasanovaさんが開発されたものをベースにしています。Kasanovaさんのご厚意により、改変したものの再配布は可能とのことでしたので、山川機長(PEB01130@nifty.com)がバグフィックス、拡張を行っています。

なお、あくまでも互換ROMなので、実機と同じ動作を保証するものではありません。おそらく動かないものもたくさんあると思います。

再配布条件に、改変点および誰が改変したのかを明示することとのことでしたので、ソースコード修正箇所にはそのようにコメントを入れています。

コメントを入れることが難しい場合(バイナリ、あるいはビットマップの場合など)は、このテキストに修正点を書くことにします。

なお、修正バージョンに関する問い合わせなどは山川機長(PEB01130@nifty.com)までお願いします。修正バージョンに関して、Kasanovaさんに問い合わせることは差し控えてください。


### コメントにない修正点
- nasmがShift-JISを認識できなくて、一部のインストラクションが前の行のコメントの続きと思って無視してしまうようなので、すべてのソースをUTF-8エンコーディングにした。

- ロゴを津軽用とUNZ用に分けて、FMT_SYS.ROMも2バージョン作るようにした。

- 抜けていたアイコンのビットマップを追加。ただし僕には絵心が無い。


## About FMT_SYS

FMT_SYS compatible ROM was originally developed by Kasanova, who wrote the developer of FM TOWNS emulator UNZ, which still runs much faster than my emulator Tsugaru.  Kasanova generously allows altered version to be released in his licensing terms.  Therefore, I (CaptainYS) am releasing the version with bug-fixes and expansion.

It is a compatible ROM that replicates minimum functionalities of the system ROM.  It does not replicate all functions, therefore it will not support all of the FM TOWNS apps.

Since one of the conditions for re-distribution is to clarify what has been modified and who modified, I add comments in the source accordingly.

If the modification is where I cannot insert a comment (such as modification on binary, or on a bitmap) I write what has been changed in this text.

If you have questions or comments on this modified version, please contact me (PEB01130@nifty.com).  Please do not contact Kasanova for any issues regarding the modified compatible FM TOWNS System ROM.

### Changes Not Described in Inline Comments
- nasm apparently cannot deal with Shift-JIS encoding, and thinks some instructions are part of the comment in the previous line.  I've saved all .ASM files in UTF-8 encoding.

- Added a logo for Tsugaru.  

- Added some missing icon patterns.

---

## FMT_DOSについて

現状、FMT_DOS.ROMを作成するには、このレポジトリに含まれるファイルの他に、MS-DOS Version 3.1相当のCOMMAND.COMが必要です。COMMAND.COMはどうやらMS-DOSのバージョンチェックをするようで、Version 3.3のCOMMAND.COMだと多分だめです。一番確実なのはFM TOWNS本体のCドライブから抜き出したものです。

このため、利用可能状態のFMT_ROM.SYSはまだこのレポジトリには含まれていません。が、互換COMMAND.COMも開発中なので出来次第、そのまま使えるFMT_ROM.SYSも公開できるようになると思います。

FMT_DOS.ROMの作り方については、FMT_ROMサブディレクトリ内のREADME.TXTを参照してください。

## About FMT_DOS

At this time, you need a COMMAND.COM from MS-DOS Version 3.1.  The most reliable choice is the one extracted from FM TOWNS ROM drive.  COMMAND.COM for Version 3.1 and newer apparently checks the DOS version, so probably you cannot use the one taken from MS-DOS Version 3.3.

So, at this time, ready-to-use version of FMT_DOS.ROM is not included in this repository.  I am working on compatible COMMAND.COM.  I'll upload ready-to-use FMT_DOS.ROM as soon as I have one.

Please see README.TXT in FMT_ROM sub-directory for how to generate a compatible FMT_DOS.ROM.



---

## FMT_DICについて

FM TOWNSは漢字変換、OAK用の辞書データをROMに持っています。ですが、この部分のデータは、漢字を入力しない限り必要ないので、すべて0FFhで埋めたデータで代用できます。なお、00hで埋めたデータだとひらがなをタイプした途端にフリーズしてしまうようです。



## About FMT_DIC

FM TOWNS has a ROM that stores dictionary data for Japanese Kanji input.  This ROM is not needed unless you type Japanese, so it is possible to replace this ROM file with all 0FFh.  By the way, if it is filled with 00h, the system freezes as soon as you type (intentionally or accidentally) Hiragana.
