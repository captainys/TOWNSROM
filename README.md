
# Free FM TOWNS Project


## Free FM TOWNS Projectについて
このプロジェクトは、完全自己完結型FM TOWNSエミュレータの実現を目指しています。

富士通が1989年世に送り出したパソコンFM TOWNSは世界で初めてCD-ROMを標準搭載したことで、CD-ROMソフトが多数発売されました。そして、CD-ROMメディアは正しく保管すれば相当な長期間維持することができます。他のレトロPCと比べて今でもまったく問題なく実行可能なソフトのメディアが多数存在して、そしてそれを合法的に中古ソフトショップ、オークションなどを利用して購入することができます。

しかし、その実行環境は急速に失われつつあります。FM TOWNS本体、とくに内蔵CD-ROMドライブの故障が多く発生します。FM TOWNSは他社に先駆けてCD-ROMドライブを搭載してしまったもんだから、内蔵CD-ROMドライブはまったく標準規格とは違った仕様となっています。そもそも標準規格なんて存在しないときでした。

そこで、「UNZ」、「津軽」といったエミュレータの利用が考えられますが、著作権法を厳密に解釈すると、FM TOWNS本体を所有していない場合、エミュレータ実行に必要なROMイメージを利用することは著作権法違反となります。

現行の著作権法は、著作者は守りますが著作物を守りません。著作者が門を閉ざしてしまったら、二度と誰も合法的に著作物を利用することができません。著作者は、ひとたび世に送り出したソフトウェアを取り上げる権利まで持つべきなのでしょうか？著作者は著作物を殺す権利も持つべきなのでしょうか？僕はそうは思いません。著作権法は著作物も守るべきであると考えています。古いソフトをすべて無料にしろというのではありません。古いソフトウェアも合理的な金額でユーザが引き続き利用できて、開発者もそれによって利益を得ることができるルールを決めるべきだと思っています。

FM TOWNSエミュレータの実行には、最低二種類のROMイメージが必要になります。ひとつはFMT_SYSと呼ばれる、起動にかかわるプログラムが入った領域です。このROMイメージに関しては、UNZ開発者のKasanovaさんが互換ROMを開発されて、ソースコードを含めて公開されています。現状のバージョンではCD-ROMドライブからの起動しかできませんが、僕が引き継いでフロッピーディスク、ハードディスク起動にも対応しようと思っています。

もうひとつはFMT_DOSと呼ばれる、MSDOS.SYS, COMMAND.COM, MSCDEX.EXEが入った領域です。これが問題でした。とくに、Version 3.1相当のMSDOS.SYSが必要で、MicrosoftはMS-DOS V2.0まではMITライセンスで無料としてくれたのですが、3.1はいまだ無料公開されていません。また、COMMAND.COMもVersion 3.1用バージョンが必要です。

このうち、MSDOS.SYSとほぼ互換のYSDOS.SYSの開発に成功しつつあります。まだ、多くの機能が未対応で、そういう機能にあたるといきなり止まってしまいますが、それでも、FM TOWNSを彩ったいくつかのゲーム、Towns OS GUIの起動までできるようになったので公開しました。

まだ利用にはFM TOWNS本体から抽出したCOMMAND.COM (多分MS DOS V3.1のCOMMAND.COMならどこから持ってきてもいい)が必要ですが、あと一歩で、FM TOWNS本体を所有していない人でも合法的にFM TOWNSエミュレータを起動できるところまでこぎつけたので、とりあえずソースコードを公開することにしました。

引き続き、YSDOS.SYSの再現性の向上と互換COMMAND.COMの開発を続けます。

山川機長 http://www.ysflight.com

---

##About Free FM TOWNS Project

The goal of this project is to make fully self-contained FM TOWNS emulator.

Fujitsu released a hobby personal computer FM TOWNS in 1989, which was the first computer that had an internal CD-ROM drive as a standard equipment of the minimum configuration.  All FM TOWNSes had a CD-ROM drive, which gave a significant incentive for software developers to release software titles in a CD-ROM.  CD-ROM can last long if you keep it in dry cool location.  We can still buy working media of FM TOWNS apps from a retro-game shop or from an auction legally.

However, the running environment is quickly diminishing.  FM TOWNS hardware very often has an issue with the internal CD-ROM drive.  Since Fujitsu did it too early (Fujitsu did always things too much ahead) the internal CD-ROM drive was proprietary.  In fact, there was no such thing called CD-ROM drive standard then.  Once the internal drive is broken, it is nearly impossible to find a replacement.

So you can think of using an emulator like "UNZ" and "Tsugaru".  However, if you strictly interpret the copyright law, it is illegal to use ROM images extracted from FM TOWNS unless you own a FM TOWNS computer.

The current copyright law protects the software developer, but not the software.  Once the developer closes the door, nobody can use the software legally.  Should the developer be given a right to take software away from the users?  Should a developer be allowed to kill a software that was once released to the world?  I don't think so.  The copyright law should protect the developers as well as the software.  I'm not saying make all old programs free.  I am saying there should be a rule that the user can continue using old software for reasonable price, and the developer can benefit by keeping the software available.

You need minimum two ROM images, FMT_SYS and FMT_DOS.  Others can somehow be auto-generated.  The developer of UNZ emulator, Kasanova, has also developed a compatible and free version of FMT_SYS.  He has generously opened the source code.  His version is only good for booting from CD-ROM drive, but I intend to take over and make it bootable from Floppy and Hard disk drives.

The other ROM image, FMT_DOS, was a problem.  It includes MSDOS.SYS, COMMAND.COM, and MSCDEX.EXE.  MSCDEX.EXE can be replaced with SHSUCDX (https://github.com/adoxa/shsucd).  I really appreciate the developer of SHSUCDX for their effort to develop a compatible version of MSCDEX.  However, I still needed MSDOS.SYS and COMMAND.COM equivalent to MS-DOS Ver 3.1.  Microsoft opened MS-DOS V2.0 source code, but stopped short of V3.1.

So, I started writing YSDOS.SYS, a compatible version of DOS, and finally made it bootable into FM Towns OS.  So, I opened it.

You still need a COMMAND.COM for MS-DOS V3.1, but at this point, YSDOS.SYS can start a basic FM TOWNS applications.

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


## About FMT_SYS

FMT_SYS compatible ROM was originally developed by Kasanova, who wrote the developer of FM TOWNS emulator UNZ, which still runs much faster than my emulator Tsugaru.  Kasanova generously allows altered version to be released in his licensing terms.  Therefore, I (CaptainYS) am releasing the version with bug-fixes and expansion.

It is a compatible ROM that replicates minimum functionalities of the system ROM.  It does not replicate all functions, therefore it will not support all of the FM TOWNS apps.

Since one of the conditions for re-distribution is to clarify what has been modified and who modified, I add comments in the source accordingly.

If the modification is where I cannot insert a comment (such as modification on binary, or on a bitmap) I write what has been changed in this text.

If you have questions or comments on this modified version, please contact me (PEB01130@nifty.com).  Please do not contact Kasanova for any issues regarding the modified compatible FM TOWNS System ROM.

### Changes Not Described in Inline Comments
- nasm apparently cannot deal with Shift-JIS encoding, and thinks some instructions are part of the comment in the previous line.  I've saved all .ASM files in UTF-8 encoding.

- Added a logo for Tsugaru.  

---

## FMT_DOSについて

現状、FMT_DOS.ROMを作成するには、このレポジトリに含まれるファイルの他に、MS-DOS Version 3.1相当のCOMMAND.COMが必要です。COMMAND.COMはどうやらMS-DOSのバージョンチェックをするようで、Version 3.3のCOMMAND.COMだと多分だめです。一番確実なのはFM TOWNS本体のCドライブから抜き出したものです。

このため、利用可能状態のFMT_ROM.SYSはまだこのレポジトリには含まれていません。が、互換COMMAND.COMも開発中なので出来次第、そのまま使えるFMT_ROM.SYSも公開できるようになると思います。

FMT_DOS.ROMの作り方については、FMT_ROMサブディレクトリ内のREADME.TXTを参照してください。

## About FMT_DOS

At this time, you need a COMMAND.COM from MS-DOS Version 3.1.  The most reliable choice is the one extracted from FM TOWNS ROM drive.  COMMAND.COM for Version 3.1 and newer apparently checks the DOS version, so probably you cannot use the one taken from MS-DOS Version 3.3.

So, at this time, ready-to-use version of FMT_DOS.ROM is not included in this repository.  I am working on compatible COMMAND.COM.  I'll upload ready-to-use FMT_DOS.ROM as soon as I have one.

Please see README.TXT in FMT_ROM sub-directory for how to generate a compatible FMT_DOS.ROM.
