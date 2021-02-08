
# Free FM TOWNS Project



## FMT_SYSについて

FMT_SYS互換ROMは、FM TOWNSエミュレータUNZ開発者のKasanovaさんが開発されたものをベースにしています。Kasanovaさんのご厚意により、改変したものの再配布は可能とのことでしたので、山川機長(PEB01130@nifty.com)がバグフィックス、拡張を行っています。

なお、あくまでも互換ROMなので、実機と同じ動作を保証するものではありません。おそらく動かないものもたくさんあると思います。

再配布条件に、改変点および誰が改変したのかを明示することとのことでしたので、ソースコード修正箇所にはそのようにコメントを入れています。

コメントを入れることが難しい場合(バイナリ、あるいはビットマップの場合など)は、このテキストに修正点を書くことにします。

なお、修正バージョンに関する問い合わせなどは山川機長(PEB01130@nifty.com)までお願いします。修正バージョンに関して、Kasanovaさんに問い合わせることは差し控えてください。


### コメントにない修正点
- nasmがShift-JISを認識できなくて、一部のインストラクションが前の行のコメントの続きと思って無視してしまうようなので、すべてのソースをUTF-8エンコーディングにした。


## About FMT_SYS

FMT_SYS compatible ROM was originally developed by Kasanova, who wrote the developer of FM TOWNS emulator UNZ, which still runs much faster than my emulator Tsugaru.  Kasanova generously allows altered version to be released in his licensing terms.  Therefore, I (CaptainYS) am releasing the version with bug-fixes and expansion.

It is a compatible ROM that replicates minimum functionalities of the system ROM.  It does not replicate all functions, therefore it will not support all of the FM TOWNS apps.

Since one of the conditions for re-distribution is to clarify what has been modified and who modified, I add comments in the source accordingly.

If the modification is where I cannot insert a comment (such as modification on binary, or on a bitmap) I write what has been changed in this text.

If you have questions or comments on this modified version, please contact me (PEB01130@nifty.com).  Please do not contact Kasanova for any issues regarding the modified compatible FM TOWNS System ROM.

### Changes Not Described in Inline Comments
- nasm apparently cannot deal with Shift-JIS encoding, and thinks some instructions are part of the comment in the previous line.  I've saved all .ASM files in UTF-8 encoding.
