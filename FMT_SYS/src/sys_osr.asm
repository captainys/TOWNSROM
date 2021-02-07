; version 2003.03.04.1
;---------------------------------------------------------------------
;
; FM TOWNS 互換 ROM シリーズ
;
; FMT_SYS.ROM : RAM/ROMドライブアクセス
;
; by Kasanova
;
;---------------------------------------------------------------------
; ※単独ではアセンブルしません

;---------------------------------------------------------------------
;■備考■
; ・メディア番号 0x40 はRAMあるいはROMに振られたメディア番号である
; ・アクセス先の物理アドレスは、メディア番号の下位4ビットによって決まる
; ・将来的には386SX系のメモリマップも考慮すること
;
;   0: 00000000h- 7fffffffh
;   1: 無効
;   2: c2000000h- c207ffffh (書き込み禁止)
;   3: 無効
;   4: 無効
;   5: 無効
;   6: 無効
;   7: 00000000h- ffffffffh (BYTEアクセス)
;   8: 00000000h- ffffffffh (DWORDアクセス)
;   9: c2000000h- c207ffffh (書き込み禁止)
;   a: c0000000h- c007ffffh ICメモリ存在チェックあり
;   b: fffc0000h- ffffffffh (書き込み禁止)
;   c: 80000000h- 8007ffffh
;   d: 80100000h- 8017ffffh
;   e: c2140000h- c2141fffh
;   f: 無効
;
;---------------------------------------------------------------------

;---------------------------------------------------------------------
; 読み込み＆書き込み

osrom_command_05:
osrom_command_06:
	mov	al,[si]
	and	al,0fh

	cmp	al,8 ; とりあえず、これだけ対応
	jz	.ok
	jmp $
.ok:
	; レジスタの上位16ビットを変更してはいけない
	pushad

	xor	edx,edx
	movzx	esi,si
	mov	dx,ds
	shl	edx,4
	add	esi,edx

	xor	edx,edx
	movzx	edi,di
	mov	dx,es
	shl	edx,4
	add	edi,edx

	; もう少しスマートな方法を考えましょう
	mov	ax,PMODE_TRANSFERMEM
	sub	sp,6
	mov	bp,sp
	sgdt	[bp]
	push	bp
	call	set_gdt
	call	call_pmode
	pop	bp
	lgdt	[bp]
	add	sp,6

	popad
	ret


