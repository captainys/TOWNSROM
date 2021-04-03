; nasmw -O3 -f bin sys.asm -o fmt_sys6.prg
; version 2003.03.04.1
;---------------------------------------------------------------------
;
; FM TOWNS 互換 ROM シリーズ
;
; FMT_SYS.ROM : メインパート
; 0FFFFC000h - 0FFFFFFFFh
;
; by Kasanova
;
;---------------------------------------------------------------------
; FMT_SYS.ROM の構造(本物の)
; 0FFFC0000h - 0FFFDFFFFh : 12ドットフォント
;                           機種によってはALL FFh、起動ロゴ(パックド
;                           ピクセル方式)がある機種もあり
; 0FFFE0000h - 0FFFE7FFFh : EXT-BOOT(32ビットプログラム)
; 0FFFE8000h - 0FFFEFFFFh : システムアイコン
; 0FFFF0000h - 0FFFF7FFFh : 何かのパターン?
; 0FFFF8000h - 0FFFFAFFFh ; 起動ロゴ(プレーン方式)
;                           機種によっては Extention BIOS
; 0FFFFB000h - 0FFFFBFFFh : ブート時に使うアイコン
; 0FFFFC000h - 0FFFFFFFFh ; 16ビットプログラム
;---------------------------------------------------------------------
; FMT_SYS.ROM の構造(この互換ROMの)
; 0FFFC0000h - 0FFFDFFFFh : 12ドットフォント
; 0FFFE0000h - 0FFFE7FFFh : EXT-BOOT(32ビットプログラム)、まだ使っていない
; 0FFFE8000h - 0FFFEFFFFh : システムアイコン
; 0FFFF0000h - 0FFFF7FFFh : ダミーデータ(0ffh)
; 0FFFF8000h - 0FFFFBBFFh ; 起動ロゴ(プレーン方式、4プレーン分)
; 0FFFFBC00h - 0FFFFBFFFh : ブート時に使うアイコン
; 0FFFFC000h - 0FFFFFFFFh ; 16ビット+32ビットプログラム
;---------------------------------------------------------------------

%define BOOTCODE_BASE 0ffffc000h
%define BOOT_SS       0f7a0h
%define BOOT_SP       057eh
%define LOCAL_SP      05feh

%define VRAM_PITCH 50h

%define LOGO_ADDRESS      0ffff8000h
%define LOGO_USEPLANES    4
%if(LOGO_USEPLANES==3)
%define LOGO_PAL_ADDRESS  0ffffaf00h
%else
%define LOGO_PAL_ADDRESS  0ffffbb80h
%endif

%define ICON_WAIT 81
%define ICON_FDD  64
%define ICON_CD   67
%define ICON_HDD  71

%define PMODE_PUTICON     0
%define PMODE_MEMORYCHECK 1
%define PMODE_DRAWLOGO    2
%define PMODE_SETPALETTE  3
%define PMODE_TRANSFERMEM 4


; By CaptainYS >>
KEYCOMB_CBIT	EQU		1
KEYCOMB_DBIT	EQU		2
KEYCOMB_FBIT	EQU		4
KEYCOMB_HBIT	EQU		8
KEYCOMB_IBIT	EQU		16
KEYCOMB_MBIT	EQU		32
; By CaptainYS <<


;---------------------------------------------------------------------

%macro JMPFAR 1
	db 0eah
	dw %1
	dw 0fc00h
%endmacro


%macro CALLFAR 1
	db 09ah
	dw %1
	dw 0fc00h
%endmacro


%macro SAVEREG_TO_CMOS 2
	mov	dx,%1
%ifidn %2,ax
%else
	mov	ax,%2
%endif
	out	dx,al
	mov	dx,%1+2
	mov	al,ah
	out	dx,al
%endmacro


%macro LOADREG_FROM_CMOS 2
	mov	dx,%1+2
	in	al,dx
	mov	ah,al
	mov	dx,%1
	in	al,dx
%ifidn %2,ax
%else
	mov	%2,ax
%endif
%endmacro

; by CaptainYS >>
%macro					PLACE 1
						TIMES	%1-($-$$) DB 0
%endmacro
; by CaptainYS <<


;---------------------------------------------------------------------

; あやしいヘッダ
	dd	0,0,0,0, 0,0,0,0
;

[BITS 16]

startall:
	cli
	cld
	mov	ax,dx
	mov	dx,3c26h
	out	dx,al
	mov	al,ah
	sub	dl,2
	out	dx,al

	; disable & reset DMAC
	mov	al,0fh
	out	0afh,al
	mov	al,3
	out	0a0h,al

	in	al,28h
	or	al,1
	out	28h,al

	; select ROM
	mov	dx,404h
	xor	al,al
	out	dx,al

	mov	cx,BOOT_SS
	mov	ss,cx
	mov	sp,BOOT_SP

	push	cs
	pop	ds

	; set local stack address
	SAVEREG_TO_CMOS 31a8h, LOCAL_SP

	mov	dx,3c22h
	xor	al,al
	out	dx,al ; non 386SX

	mov	dx,31b8h
	out	dx,al
	mov	dx,31b2h
	out	dx,al
	mov	dx,31cch
	out	dx,al

	call	set_gdt
	call	init_pic
	call	init_keyboard
	call	init_crtc

	; CMOS情報が正しいか？
	mov	ah,20h
	CALLFAR	cmos_bios
	jnc	.noinitcmos
	; CMOS初期化
	mov	ah,0
	CALLFAR cmos_bios
.noinitcmos:

	mov	al,PMODE_SETPALETTE
	call	call_pmode

	mov	al,PMODE_DRAWLOGO
	call	call_pmode

	mov	al,PMODE_MEMORYCHECK
	call	call_pmode

	call	print_readme

; by CaptainYS >>
	call	check_boot_key_combination

	;BOOTKEY_CD			EQU		1
	cmp		eax,0ffff0000h+KEYCOMB_CBIT+KEYCOMB_DBIT
	je		.device_loop_cd

	;BOOTKEY_F0			EQU		2
	cmp		eax,KEYCOMB_FBIT
	je		.device_loop_f0

	;BOOTKEY_F1			EQU		3
	cmp		eax,00010000h+KEYCOMB_FBIT
	je		.device_loop_f1

	;BOOTKEY_H0			EQU		4
	cmp		eax,KEYCOMB_HBIT
	je		.device_loop_h0

	;BOOTKEY_H1			EQU		5
	cmp		eax,00010000h+KEYCOMB_HBIT
	je		.device_loop_h1

	;BOOTKEY_H2			EQU		6
	cmp		eax,00020000h+KEYCOMB_HBIT
	je		.device_loop_h2

	;BOOTKEY_H3			EQU		7
	cmp		eax,00030000h+KEYCOMB_HBIT
	je		.device_loop_h3

	;BOOTKEY_ICM		EQU		8
	cmp		eax,0ffff0000h+KEYCOMB_IBIT+KEYCOMB_CBIT+KEYCOMB_MBIT
	je		.device_loop_icm


.no_boot_key:
	; Check the default boot device from CMOS and try before start loop.
	call	get_default_boot_device
	cmp		ah,1
	je		.default_drive_is_hd
	cmp		ah,2
	je		.default_drive_is_fd
	; If CD, jump to device loop
	; If not CD, jump to device loop
	jmp		.device_loop

.default_drive_is_hd:
	call	try_hd_boot
	jmp		.device_loop

.default_drive_is_fd:
	call	try_fd_boot
	; jmp		.device_loop



.device_loop:
.device_loop_cd:
	call	try_cd_boot
.device_loop_f0:
	mov		al,0
	call	try_fd_boot
.device_loop_f1:
	mov		al,1
	call	try_fd_boot
.device_loop_h0:
	mov		al,0
	call	try_hd_boot
.device_loop_h1:
	mov		al,1
	call	try_hd_boot
.device_loop_h2:
	mov		al,2
	call	try_hd_boot
.device_loop_h3:
	mov		al,3
	call	try_hd_boot
.device_loop_icm:
	call	try_icm_boot
	jmp		.device_loop
; by CaptainYS <<



; by CaptainYS >>
; al=Unit
try_fd_boot:
	push	ax

	mov	al,PMODE_PUTICON
	mov	cl,ICON_FDD
	mov	dx, (VRAM_PITCH*368)+(VRAM_PITCH-4)
	call	call_pmode

	pop		ax

	and		al,0fh
	or		al,20h		; BIOS Device Code

	push	ax
	mov		ah,03h		; Restore
	CALLFAR	disk_bios
	pop		ax
	jc		.cannot_boot

	mov		cx,0b000h
	mov		ds,cx
	mov		dword ds:[0],0
	mov		byte ds:[4],0CBh	; RETF

	push	ax
	mov		ah,05h		; Read
	xor		cx,cx		; Cylinder 0
	mov		dx,1		; Side 0 Sector 1
	mov		bx,1		; Number of Sectors
	xor		di,di		; buffer DS:DI=B000:0000
	CALLFAR	disk_bios
	pop		ax
	jc		.cannot_boot

	push	ax
	call	check_iplvalidity
	pop		ax
	jc		.cannot_boot

	; BL:Device Type   1:SCSI  2:FD  8:CD
	; BH:Unit Number
	mov		bh,al
	and		bh,0fh
	mov		bl,2
	mov	ax,0ffffh

	; call	far 0B000h:0004h
	DB		9AH
	DW		 0004H
	DW		0B000H

.cannot_boot:
	ret



; al=Unit
try_hd_boot:
	push	ax

	mov	al,PMODE_PUTICON
	mov	cl,ICON_HDD
	mov	dx, (VRAM_PITCH*368)+(VRAM_PITCH-4)
	call	call_pmode

	pop		ax

	and		al, 0fh
	or		al,0b0h		; BIOS Device Code

	mov		cx,0b000h
	mov		ds,cx
	mov		dword ds:[0],0
	mov		byte ds:[4],0CBh	; RETF

	push	ax
	mov		ah,05h		; Read
	xor		cx,cx		; Cylinder 0
	mov		dx,0		; Side 0 Sector 1
	mov		bx,4		; Number of Sectors
	xor		di,di		; buffer DS:DI=B000:0000
	CALLFAR	disk_bios
	pop		ax
	jc		.cannot_boot

	push	ax
	call	check_iplvalidity
	pop		ax
	jc		.cannot_boot

	; BL:Device Type   1:SCSI  2:FD  8:CD
	; BH:Unit Number
	mov		bh,al
	and		bh,0fh
	mov		bl,1
	mov	ax,0ffffh

	; call	far 0B000h:0004h
	DB		9AH
	DW		 0004H
	DW		0B000H

.cannot_boot:
	ret



try_icm_boot:
	ret


; [3180H] Non-Zero -> At least the user once opened default-boot-device dialog.
; [3182H] Boot Device Type  1:HD  2:FD  8:CD
; [3184H] Boot Device Unit  (Drive number, Hard disk SCSI ID)
get_default_boot_device:
	mov		dx,3180h
	in		al,dx
	or		al,al
	je		.no_default_boot_device

	mov		dx,3182h
	in		al,dx
	mov		ah,al
	mov		dx,3184h
	in		al,dx
	ret

.no_default_boot_device:
	xor		ax,ax
	ret
	
; by CaptainYS <<



; by CaptainYS
; Made it a procedure.  It was a one-shot code in the boot sequence.
try_cd_boot:
	; by CaptainYS >>
	mov	al,PMODE_PUTICON	; by CaptainYS  Was missing.
	mov	cl,ICON_CD
	mov	dx, (VRAM_PITCH*368)+(VRAM_PITCH-4)
	call	call_pmode
	; by CaptainYS <<

	; CDが読めるか？
	mov	ax,0ec0h	; by CaptainYS  mov ah,0eh -> mov ax 0ec0h to prepare for FD, HD, and ICM boot
	CALLFAR disk_bios
	jnc	.cdok

	; 手抜き(^^;
	mov	si,mes_wrongipl ; by CaptainYS: Changed from mes_cantboot -> mes_wrongipl
	mov	di,VRAM_PITCH*384
	call	textout
	ret

.cdok:
	; IPL読み込み
	push	ds
	mov	cx,0
	mov	dx,0
	mov	ax,0b000h
	mov	ds,ax
	mov	di,0
	mov	ax,05c0h ; read command + media no.
	mov	bx,1
	CALLFAR disk_bios
	pop	ds

	mov	cl,ICON_WAIT
	mov	al,PMODE_PUTICON
	mov	dx, (VRAM_PITCH*368)+(VRAM_PITCH-4)
	call	call_pmode

	mov	si,mes_reading
	mov	di,VRAM_PITCH*384
	call	textout

	call	check_iplvalidity
	jc	.wrongipl

	mov	ax,0ffffh
	mov	bx,0008h
	call	far [cs:si]

.wrongipl:
	; 起動に失敗すると戻ってくる
	; 成功した場合は２度と戻ってこない
	mov	si,mes_wrongipl
	mov	di,VRAM_PITCH*384
	call	textout

	ret



check_boot_key_combination:
	mov		ebx,0ffff0000h
	mov		cx,1000h

.keybuffer_loop:
	dec		cx
	je		.keybuffer_loop_break

	mov		dx,IO_KEYBOARD_STATUS
	in		al,dx
	and		al,1	; Data in the Buffer?
	je		.keybuffer_loop_break

	mov		dx,IO_KEYBOARD_DATA
	in		al,dx
	or		al,al
	js		.keybuffer_loop

	cmp		al,02h	; Key Code for '1'
	jb		.key_not_number
	cmp		al,0bh	; Key Code for '0'
	ja		.key_not_number
	je		.key_zero

.key_number:
	dec		al	;	'1'->1
	movzx	eax,al
	shl		eax,16
	and		ebx,0ffffh
	or		ebx,eax
	jmp		.keybuffer_loop

.key_zero:
	and		ebx,0ffffh
	jmp		.keybuffer_loop

.key_not_number:
	cmp		al,TOWNS_JISKEY_C
	jne		.key_not_c
	or		bx,KEYCOMB_CBIT
	jmp		.keybuffer_loop

.key_not_c:
	cmp		al,TOWNS_JISKEY_D
	jne		.key_not_d
	or		bx,KEYCOMB_DBIT
	jmp		.keybuffer_loop

.key_not_d:
	cmp		al,TOWNS_JISKEY_F
	jne		.key_not_f
	or		bx,KEYCOMB_FBIT
	jmp		.keybuffer_loop

.key_not_f:
	cmp		al,TOWNS_JISKEY_H
	jne		.key_not_h
	or		bx,KEYCOMB_HBIT
	jmp		.keybuffer_loop

.key_not_h:
	cmp		al,TOWNS_JISKEY_I
	jne		.key_not_m
	or		bx,KEYCOMB_IBIT
	jmp		.keybuffer_loop

.key_not_m:
	cmp		al,TOWNS_JISKEY_M
	jne		.keybuffer_loop
	or		bx,KEYCOMB_MBIT
	jmp		.keybuffer_loop


.keybuffer_loop_break:
	mov		eax,ebx
	ret



; CaptainYS: Since NASM doesn't seem to understand Shift-JIS, 
;            I've pasted shift-jis code directly.
mes_reading:
	; 	'システム読み込み中です　　　　',0
	db 083h,056h,083h,058h,083h,065h,083h,080h,093h,0C7h,082h,0DDh,08Dh,09Eh,082h,0DDh
	db 092h,086h,082h,0C5h,082h,0B7h,081h,040h,081h,040h,081h,040h,081h,040h,000h

mes_wrongipl:
	; db	'システムが違います　　　　　　',00
	db 083h,056h,083h,058h,083h,065h,083h,080h,082h,0AAh,088h,0E1h,082h,0A2h,082h,0DCh
	db 082h,0B7h,081h,040h,081h,040h,081h,040h,081h,040h,081h,040h,081h,040h,000h

mes_setsys:
	; db	'システムをセットしてください　',00
	db 083h,056h,083h,058h,083h,065h,083h,080h,082h,0F0h,083h,05Ah,083h,062h,083h,067h
	db 082h,0B5h,082h,0C4h,082h,0ADh,082h,0BEh,082h,0B3h,082h,0A2h,081h,040h,000h

mes_cantboot:
	; db	'ＣＤをセットしてリセットしてね',00
	db 082h,062h,082h,063h,082h,0F0h,083h,05Ah,083h,062h,083h,067h,082h,0B5h,082h,0C4h
	db 083h,08Ah,083h,05Ah,083h,062h,083h,067h,082h,0B5h,082h,0C4h,082h,0CBh,000h

; by CaptainYS>>
readme0:
	DB	"THIS PROGRAM IS RUNNING ON COMPATIBLE ROMS, WHICH ARE DIFFERENT FROM THE",0
readme1:
	DB	"ROM IMAGES EXTRACTED FROM FM TOWNS HARDWARE.  THEREFORE, SOME APPLICATIONS",0
readme2:
	DB	"MAY NOT RUN ACCURATELY OR NOT RUN AT ALL.",0
readme3:
	; このプログラムは、互換ROMで実行しています。実機FM TOWNSのROMとは異なるため、
	; 実行できないFM TOWNSアプリケーションがあります。
	DB		082h,0B1h,082h,0CCh,083h,076h,083h,08Dh,083h,04Fh,083h,089h,083h,080h,082h,0CDh
	DB		081h,041h,08Ch,0DDh,08Ah,0B7h,052h,04Fh,04Dh,082h,0C5h,08Eh,0C0h,08Dh,073h,082h
	DB		0B5h,082h,0C4h,082h,0A2h,082h,0DCh,082h,0B7h,081h,042h,08Eh,0C0h,08Bh,040h,046h
	DB		04Dh,020h,054h,04Fh,057h,04Eh,053h,082h,0CCh,052h,04Fh,04Dh,082h,0C6h,082h,0CDh
	DB		088h,0D9h,082h,0C8h,082h,0E9h,082h,0BDh,082h,0DFh,081h,041h
	DB		0
readme4:
	DB		08Eh,0C0h,08Dh,073h,082h,0C5h,082h,0ABh,082h,0C8h,082h,0A2h,046h,04Dh,020h,054h
	DB		04Fh,057h,04Eh,053h,083h,041h,083h,076h,083h,08Ah,083h,050h,081h,05Bh,083h,056h
	DB		083h,087h,083h,093h,082h,0AAh,082h,0A0h,082h,0E8h,082h,0DCh,082h,0B7h,081h,042h
	DB		0


print_readme:
	mov		si,readme0
	mov		di,VRAM_PITCH*16
	call	textout
	mov		si,readme1
	mov		di,2*VRAM_PITCH*16
	call	textout
	mov		si,readme2
	mov		di,3*VRAM_PITCH*16
	call	textout
	mov		si,readme3
	mov		di,4*VRAM_PITCH*16
	call	textout
	mov		si,readme4
	mov		di,5*VRAM_PITCH*16
	call	textout
	ret


; by CaptainYS<<

;---------------------------------------------------------------------
; IPLのバージョンをチェック

check_iplvalidity:
	push	es
	mov	si,0b000h
	mov	es,si

	mov	si,.ipl_type1
	cmp	dword [es:0],'IPL4'
	jz	.goodipl

	mov	si,.ipl_type2
	cmp	dword [es:3],'IPL4'
	jz	.goodipl

	stc
.goodipl:
	pop	es
	ret

.ipl_type1:
	dw	4,0b000h
.ipl_type2:
	dw	0,0b000h

;---------------------------------------------------------------------
; GDTをセット

set_gdt:
	lgdt	[cs:.lgdtr]
	ret

	align 8
		dw	0
.lgdtr:		dw	002fh ; GDT limit
		dd	0fc000h+.gdtentry

.gdtentry:	db	 00h, 00h,00h, 00h,00h,00h, 00h,00h
		db	0ffh,0ffh,00h, 00h,00h,9bh,0cfh,00h	; CaptainYS 0c0h->0cfh.  Bug fix.  Segment limit was stopping at 0FFFFFFFh.  SHould be FFFFFFFFh
		db	0ffh,0ffh,00h, 00h,00h,93h,0cfh,00h
		db	0ffh,0ffh,00h,0c0h,0fh,9bh,000h,00h
		db	0ffh,0ffh,00h,0c0h,0fh,93h,000h,00h
		db	0ffh,000h,00h,0c0h,0fh,9bh,0c0h,00h

;---------------------------------------------------------------------
; プロテクトモード・プロシジャを呼ぶ

call_pmode:
	push	ds
	push	es
	push	gs
	mov	bx,ss
	mov	gs,bx
	mov	bx,ax

	mov	eax,cr0
	or	al,1
	mov	cr0,eax
	jmp	short $+2

	db	0eah
	dw	.goto_pmode
	dw	28h
.goto_pmode:

	db	0eah
	dd	BOOTCODE_BASE+pmode_entry
	dw	8

return_from_pmode:
	mov	bx,gs
	mov	ss,bx

	pop	gs
	pop	es
	pop	ds
	ret

;---------------------------------------------------------------------
; PIC初期化
; ※ウェイトを入れていないので、実機では動作しない

init_pic:
	mov	al,19h
	out	0,al
	mov	al,40h
	out	2,al
	mov	al,80h
	out	2,al
	mov	al,1dh
	out	2,al
	mov	al,0feh
	out	2,al
	mov	al,19h
	out	10h,al
	mov	al,48h
	out	12h,al
	mov	al,87h
	out	12h,al
	mov	al,9
	out	12h,al
	mov	al,0ffh
	out	12h,al
	ret

;---------------------------------------------------------------------
; キーボード初期化

init_keyboard:
	mov	dx,602h
	mov	al,0a1h ; reset
	out	dx,al

; Commented out by CaptainYS >>
;	; バッファが空になるまで待つ
;.loop:
;	mov	dx,602h
;	in	al,dx
;	test	al,1
;	jz	.exit
;	sub	dx,2
;	in	al,dx
;	jmp	.loop
;.exit:
; Commented out by CaptainYS >>

	ret

;---------------------------------------------------------------------
; CRTC初期化、FMR互換の画面モードへ

init_crtc:
	mov	dx,0fda0h
	xor	al,al
	out	dx,al

	mov	si,crtcinitdata
	mov	cx,32
.loop:
	mov	al,32
	sub	al,cl
	mov	dx,440h
	out	dx,al
	mov	ax,[si]
	add	dx,2
	out	dx,ax
	add	si,2
	loop	.loop

	mov	dx,448h
	xor	al,al
	out	dx,al
	add	dx,2
	mov	al,15h
	out	dx,al

	mov	dx,448h
	mov	al,1
	out	dx,al
	add	dx,2
	mov	al,8
	out	dx,al

	mov	dx,0fda0h
	mov	al,8
	out	dx,al

	; 全プレーンを書き込み対象に設定
	mov	dx,0ff81h
	mov	al,0fh
	out	dx,al

	; 全プレーン表示
	mov	dx,0ff82h
	mov	al,67h
	out	dx,al

	; 描画対象プレーンを選択
	mov	dx,0ff83h
	xor	al,al
	out	dx,al

	ret


crtcinitdata:
	dw	0040h, 0320h, 0000h, 0000h, 035fh, 0000h, 0010h, 0000h
	dw	036fh, 009ch, 031ch, 009ch, 031ch, 0040h, 0360h, 0040h
	dw	0360h, 0000h, 009ch, 0000h, 0050h, 0000h, 009ch, 0000h
	dw	0050h, 004ah, 0001h, 0000h, 803fh, 0003h, 0000h, 0150h ; CaptainYS: Register 1C 003fh->803fh not to accidentally enable High-Res CRTC.

;---------------------------------------------------------------------
; 文字列表示
;
; si = 文字列
; di = 表示先VRAMアドレス
; CaptainYS added support for Kanji and ASCII mix.
textout:
	push	es
	push	bx
	mov	ax,0c000h
	mov	es,ax
	mov	bx,0ff94h
	mov	byte es:[IO_KVRAM_OR_ANKFONT],1	; ANK Font ROM CA000H-

.textoutloop:
	mov	cx,[si]
	or	cl,cl
	jz	.exit
	cmp	cl,081h
	jae	.kanji

;.ascii
	push	si
	movzx	si,cl
	shl		si,3
	add		si,0a000h
	mov		cx,8
.oneasciiloop:
	mov		al,es:[si]
	mov		es:[di],al
	mov		es:[di+VRAM_PITCH],al
	inc		si
	add		di,VRAM_PITCH*2
	loop	.oneasciiloop

	pop		si
	sub		di,VRAM_PITCH*16-1
	inc		si
	jmp		.textoutloop

.kanji:
	call	sjistojis
	mov	[es:bx],cl
	mov	[es:bx+1],ch
	mov	cx,16
.onekanjiloop:
	mov	al,[es:bx+2]
	mov	ah,[es:bx+3]
	mov	[es:di],ax
	add	di,VRAM_PITCH
	loop	.onekanjiloop

	sub	di,VRAM_PITCH*16-2
	add	si,2
	jmp	.textoutloop
.exit:
	pop	bx
	pop	es
	ret

; シフトJIS→JIS変換
sjistojis:
	cmp	cl,0e0h
	jc	.j1
	sub	cl,40h
.j1:
	sub	cl,81h
	shl	cl,1
	add	cl,21h
	mov	al,ch
	cmp	ch,9fh
	jc	.j2
	inc	cl
	sub	ch,5eh
.j2:
	sub	ch,20h
	cmp	al,7eh
	ja	.j3
	test	cl,1
	jz	.j3
	inc	ch
.j3:
	ret

;---------------------------------------------------------------------
; DISK-BIOS(と勝手に呼んでいる)
; ahに応じて次の機能を提供する(ah = 2-0x11)
	align 2
disk_command_table:
	dw	disk_command_02 ; 2 : 未実装
	dw	disk_command_03 ; 3 : メディア先頭へシーク？
	dw	disk_command_04 ; 4 : 未実装
	dw	disk_command_05 ; 5 : リード
	dw	disk_command_06 ; 6 : ライト
	dw	disk_command_xx ; 7 : 無効
	dw	disk_command_08 ; 8 : ドライブリセット(FDD & HDD)
	dw	disk_command_xx ; 9 : 無効
	dw	disk_command_xx ; a : 無効
	dw	disk_command_xx ; b : 無効
	dw	disk_command_xx ; c : 無効
	dw	disk_command_xx ; d : 無効
	dw	disk_command_0e ; e : ドライブチェック
	dw	disk_command_xx ; f : 無効
	dw	disk_command_xx ;10 : 無効
	dw	disk_command_11 ;11 : 未実装
;
; リターンコード: ah(0:正常終了)、エラーの有無はキャリーフラグにセット

disk_bios:
	; めんどくさい。フラグも変えないよう注意
	push	dx
	push	ax ; これがリターンコードになる

	; まず、ローカルスタックに切り替える
	; 現在の SS:SP を退避
	SAVEREG_TO_CMOS 319ch, ss
	SAVEREG_TO_CMOS 31a0h, sp
	LOADREG_FROM_CMOS 31a8h, sp
	mov	ax,BOOT_SS
	mov	ss,ax
	; ローカルスタックに切り替え完了

	; 呼出し元 SS:SP を push
	LOADREG_FROM_CMOS 319ch, ax ; ss
	push	ax
	LOADREG_FROM_CMOS 31a0h, ax ; sp
	push	ax

	push	es
	push	ds
	push	di
	push	si
	push	bp

	LOADREG_FROM_CMOS 31a8h, bp

	; DS:SI で呼び出し元スタックをいじれるようにする
	LOADREG_FROM_CMOS 319ch, ds
	LOADREG_FROM_CMOS 31a0h, si

	push	cx
	push	bx
	clc
	pushf

	cli
	cld
	mov	ax,ss
	mov	es,ax
	mov	di,sp
	push	bp

	; 一番最初に push したレジスタをロード
	mov	ax,[si]
	mov	dx,[si+2]

	; 本来なら範囲判定があるが省略

	; 呼ぶ
	mov	al,ah
	xor	ah,ah
	sub	ax,2
	add	ax,ax
	mov	bx,ax
	call	[cs:disk_command_table+bx]

	; 結果を格納
	or	ah,ah
	setnz	al
	mov	[si+1],ah
	or	[es:di],al ; CF
	
	pop	ax
	popf
	pop	bx
	pop	cx
	pop	bp
	pop	si
	pop	di
	pop	ds
	pop	es

	mov	dx,bx
	pop	bx
	mov	ax,bx
	pop	bx
	mov	ss,bx
	mov	sp,ax
	mov	bx,dx
	pop	ax
	pop	dx
	retf


disk_command_xx:
	jmp	$

disk_command_02:
	jmp	$

disk_command_03:
	; by CaptainYS >>
	mov		al,[si]
	and		al,0f0h
	cmp		al,020h
	je		.fd_command_03
	cmp		al,0b0h
	je		.hd_command_03
	; by CaptainYS <<
	call	cd_command_0e ; 一応これで代替
	ret

; by CaptainYS >>
.fd_command_03:
	call	fd_command_03
	ret
.hd_command_03:
	call	hd_command_03
	ret
; by CaptainYS <<



disk_command_04:
	jmp	$

disk_command_05:
	mov	al,[si]
	and	al,0f0h
	cmp	al,020h		; by CaptainYS
	je	.fd			; by CaptainYS
	cmp	al,0b0h		; by CaptainYS
	je	.hd			; by CaptainYS
	cmp	al,040h
	jz	.rom
	call	cd_command_05
	ret
.rom:
	call	osrom_command_05
	ret
.fd:						; by CaptainYS
	call	fd_command_05	; by CaptainYS
	ret						; by CaptainYS
.hd:						; by CaptainYS
	call	hd_command_05	; by CaptainYS
	ret


disk_command_06:
	mov	al,[si]
	and	al,0f0h
	cmp	al,040h
	jz	.rom
	jmp	$
	ret
.rom:
	call	osrom_command_06
	ret

disk_command_08:
	jmp	$

disk_command_0e:
	call	cd_command_0e
	ret

disk_command_11:
	jmp	$


;---------------------------------------------------------------------
; CMOS-BIOS(と勝手に呼んでいる)
; ahに応じて次の機能を提供する(ah = -3(0xfd)-0x20)
	align 2
	dw	cmos_command_fd ;fd : 未実装
	dw	cmos_command_xx ;fe : 無効
	dw	cmos_command_xx ;ff : 無効
cmos_command_table:
	dw	cmos_command_00 ; 0 : イニシャライズ
	dw	cmos_command_01 ; 1 : 未実装
	dw	cmos_command_02 ; 2 : 未実装
	dw	cmos_command_03 ; 3 : 未実装
	dw	cmos_command_04 ; 4 : 未実装
	dw	cmos_command_05 ; 5 : 未実装
	dw	cmos_command_06 ; 6 : 未実装
	dw	cmos_command_xx ; 7 : 無効
	dw	cmos_command_xx ; 8 : 無効
	dw	cmos_command_xx ; 9 : 無効
	dw	cmos_command_xx ; a : 無効
	dw	cmos_command_xx ; b : 無効
	dw	cmos_command_xx ; c : 無効
	dw	cmos_command_xx ; d : 無効
	dw	cmos_command_xx ; e : 無効
	dw	cmos_command_xx ; f : 無効
	dw	cmos_command_10 ;10 : ブロック書き込み
	dw	cmos_command_11 ;11 : ブロック読み出し
	dw	cmos_command_xx ;12 : 無効
	dw	cmos_command_xx ;13 : 無効
	dw	cmos_command_xx ;14 : 無効
	dw	cmos_command_xx ;15 : 無効
	dw	cmos_command_xx ;16 : 無効
	dw	cmos_command_xx ;17 : 無効
	dw	cmos_command_xx ;18 : 無効
	dw	cmos_command_xx ;19 : 無効
	dw	cmos_command_xx ;1a : 無効
	dw	cmos_command_xx ;1b : 無効
	dw	cmos_command_xx ;1c : 無効
	dw	cmos_command_xx ;1d : 無効
	dw	cmos_command_xx ;1e : 無効
	dw	cmos_command_xx ;1f : 無効
	dw	cmos_command_20 ;20 : ヘッダが正常かチェック
;
; リターンコード: ah(0:正常終了)、エラーの有無はキャリーフラグにセット

cmos_bios:
	; これまためんどくさい。フラグは変えてもいいみたい
	push	bp
	mov	bp,dx

	; まず、axを退避
	SAVEREG_TO_CMOS 319ch,ax

	; ローカルスタックに切り替える
	; 現在の SS:SP を退避
	SAVEREG_TO_CMOS 31a0h, ss
	SAVEREG_TO_CMOS 31a4h, sp
	LOADREG_FROM_CMOS 31a8h, sp
	mov	ax,BOOT_SS
	mov	ss,ax
	; ローカルスタックに切り替え完了

	; 呼出し元 SS:SP を push
	LOADREG_FROM_CMOS 31a0h, ax ; ss
	push	ax
	LOADREG_FROM_CMOS 31a4h, ax ; sp
	push	ax

	; 退避しておいたaxを復元
	LOADREG_FROM_CMOS 319ch,ax

	mov	dx,bp
	push	es ; [bp+12]
	push	ds ; [bp+10]
	push	di ; [bp+e]
	push	si ; [bp+c]
	push	bp ; [bp+a]
	push	dx ; [bp+8]
	push	cx ; [bp+6]
	push	bx ; [bp+4]
	push	ax ; [bp+2]
	clc
	pushf

	cli
	cld
	mov	bp,sp

	; 範囲チェックして、呼ぶ
	mov	al,[bp+3]
	mov	ah,1

	cmp	al,21h
	jnl	.error
	cmp	al,0fch
	jng	.error

	movsx	bx,al
	add	bx,bx
	call	[cs:cmos_command_table+bx]

	; 結果を格納
	or	ah,ah
	setnz	al
	jns	.noerror
.error:
	mov	[bp+6],cx
.noerror:
	mov	[bp+3],ah
	or	[bp],al ; CF

	popf
	pop	ax
	pop	bx
	pop	cx
	pop	dx
	pop	bp
	pop	si
	pop	di
	pop	ds
	pop	es

	mov	bp,dx

	SAVEREG_TO_CMOS 319ch,ax

	; 呼出し元SS:SPの復元
	pop	ax ; sp
	SAVEREG_TO_CMOS 31a0h,ax
	pop	ax ; ss
	mov	ss,ax
	LOADREG_FROM_CMOS 31a0h,ax
	mov	sp,ax

	LOADREG_FROM_CMOS 319ch,ax
	mov	dx,bp
	pop	bp
	retf


;---------------------------------------------------------------------
; 各デバイス特有の処理を記述したコードをインクルード

%include "townsio.asm"	; by CaptainYS
%include "sys_cd.asm"
%include "sys_fd.asm"
%include "sys_hd.asm"
%include "sys_osr.asm"

%include "sys_cmos.asm"

%include "sys_print.asm" ; by CaptainYS
%include "scsiio.asm" ; by CaptainYS
%include "scsiutil.asm" ; by CaptainYS
; Note: sys_p32.asm changes the bitness from 16 to 32, therefore must be included after 16-bit code.

%include "sys_p32.asm"

;---------------------------------------------------------------------
; ウェイト(うんづではあまり意味が無いので省略)

waitloop:
	retf

;---------------------------------------------------------------------

invalid1:
	jmp	invalid1

invalid2:
	jmp	invalid2

invalid3:
	jmp	invalid3

invalid4:
	jmp	invalid4

invalid5:
	jmp	invalid5


;---------------------------------------------------------------------

	; CaptainYS >>
	PLACE	03FB0h	; FC000+03FB0=FFFB0
	; CaptainYS <<


	JMPFAR invalid1 ; 診断エラー?
	JMPFAR invalid2 ; 診断エラー?
	JMPFAR invalid3 ; ?
	JMPFAR invalid4 ; 文字列表示(未実装)
	JMPFAR disk_bios
	JMPFAR cmos_bios
	JMPFAR print_string ; by CaptainYS
	JMPFAR waitloop

	; CaptainYS >>
	PLACE	03FF0h	; FC000+03FF0=FFFF0
	; CaptainYS <<

	JMPFAR startall ; ここからすべてが始まる

; CaptainYS>>
	db 051h		; This byte will be transferred to IO.SYS's DS:0000, and then returned as Machine Id to DS:[DI] by INT AFH AH=05H.  MX->51h
	db 0,0
	dd 0,0
; CaptainYS<<
