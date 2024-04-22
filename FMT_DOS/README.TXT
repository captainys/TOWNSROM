[音声データについて]
[About voice data]
FM TOWNSの通称OS ROM領域には、音声データがいくつか収録されています。互換ROMには、BCCさん (https://bcc.hatenablog.com/)が、「VOICEVOX 四国めたん」を使用して作成してくださったデータをその領域に書き込みました。「VOICEVOX 四国めたん」は商用・非商用使用可とのライセンス条件を元に使用させていただきました。この互換ROMが津軽と四国をつなぐ架け橋になることを...(さすがに無理がある)

FM TOWNS's so-called OS ROM includes some voice data.  This compatible ROM includes voice data created by BCC (https://bcc.hatenablog.com/) using "VOICEVOX Shikoku Methane" (May be spelled as Metan).  "VOICEVOX Shikoku Methane" is free to use for commercial and non-commercial purposes.





[アセンブルの仕方]
DOSエミュレータ上のMASMを使う場合:
DOSBoxなどのエミュレータにMASMがインストールされた状態で、YSDOSディレクトリで make makefile コマンド。

Windows上のNASMを使う場合:
NASMソースにコンバートする必要があって、コンバータはC++で書いたのでC++コンパイラが必要です。一応、nasm.pyで自動的に変換してアセンブルするようにしましたが、Visual C++を前提に書いてあるので、Developer Power Shellあるいは、Developer Command Promptから nasm.py を実行してください。.pyスクリプトなのでPythonもインストールする必要があります。



[Instruction for Assembly]
Using MASM on DOS Emulator:
If you have a DOS emulator and have MASM ready, go down to YSDOS directory, and type make makefile.

Using NASM on Windows:
YSDOS.SYS can also be assembled with NASM, but to do so, the source files needs to be converted to the NASM format, which is done by a C++ program.  I have written a Python script that automate this process, but in the script uses Visual C++.  So, you need to have Visual Studio installed.  Also you need a Python interpreter.

In Developer Command Prompt or Developer Power Shell, cd to YSDOS sub-directory, and type .\nasm.py



[FMT_DOS.ROMの作り方]
まず、COMMAND.COMが必要です。今、互換COMMAND.COMも開発中というか開発に向けて準備中ですが、まだ実機あるいはDOS 3.1から抜き出したCOMMAND.COMがいります。これを、makerom/files ディレクトリにコピーしてください。

次に、C++コンパイラが必要です。makeromサブディレクトリに移動して、make.cppをコンパイルして、そのままmake.exeを実行するとFMT_DOS.ROMができます。



[Generating FMT_DOS.ROM]
Although I am working on compatible COMMAND.COM, at this moment you still need to get a COMMAND.COM from MS-DOS 3.1.  Find one, and copy to makerom/files subdirectory.

Then, compile make.cpp, and run make.exe.  You'll get FMT_DOS.ROM.
