---

## FMT_DICについて

FM TOWNSは漢字変換、OAK用の辞書データをROMに持っています。ですが、この部分のデータは、漢字を入力しない限り必要ないので、すべて0FFhで埋めたデータで代用できます。なお、00hで埋めたデータだとひらがなをタイプした途端にフリーズしてしまうようです。



## About FMT_DIC

FM TOWNS has a ROM that stores dictionary data for Japanese Kanji input.  This ROM is not needed unless you type Japanese, so it is possible to replace this ROM file with all 0FFh.  By the way, if it is filled with 00h, the system freezes as soon as you type (intentionally or accidentally) Hiragana.
