; version 2003.03.04.1
;---------------------------------------------------------------------
;
; FM TOWNS 互換 ROM シリーズ
;
; FMT_SYS.ROM : CDアクセス
;
; by Kasanova
;
;---------------------------------------------------------------------
; ※単独ではアセンブルしません


%define CD_CMOS_PARA  3b60h
%define CD_CMOS_DATA  3b70h
%define CD_CMOS_DATA0 3b70h
%define CD_CMOS_DATA1 3b72h
%define CD_CMOS_DATA2 3b74h
%define CD_CMOS_DATA3 3b78h

;---------------------------------------------------------------------
; 読み込み
; cl+dx : 読み込み開始セクタ番号(16進)
; bx    : 読み込むセクタ数
; ds:di : 転送先アドレス
; [リターンコード]
;  ah : 0(正常終了)、bx : 読み残したセクタ数

cd_command_05:
	call	cd_test_ready
	jc	.error1          ; アクセスできる状態でない
	cmp	word [es:di+2],0 ; bx
	jz	.error2          ; 読み込むセクタ数が不適切
	
	; 読み込み開始セクタをセット
	mov	bx,CD_CMOS_PARA
	movzx	dx,byte [es:di+4] ; cl
	mov	ax,[si+2]         ; dx
	call	cd_set_sectorno

	; 読み込み終了セクタを計算し、セット
	movzx	dx,byte [es:di+4] ; cl
	mov	ax,[si+2]         ; dx
	mov	bx,[es:di+2]      ; bx
	dec	bx
	add	ax,bx
	adc	dx,0
	mov	bx,CD_CMOS_PARA+6
	call	cd_set_sectorno

	; DMA初期化
	call	cd_init_dma
	mov	ax,[es:di+0ah] ; di
	mov	dx,[es:di+0ch] ; es
	push	dx
	shl	dx,4
	add	ax,dx
	pop	dx
	shr	dx,12
	call	cd_dma_setaddress
	mov	ax,7ffh
	call	cd_dma_setlength
	in	al,0afh
	and	al,7
	out	0afh,al

	; 読み込み開始
	mov	al,022h
	call	cd_sendcommand
	call	cd_recieve4byte

	mov	dx,CD_CMOS_DATA0
	in	al,dx
	or	al,al
	jnz	.error3 ; コマンド実行エラー

.readloop:
	call	cd_recieve4byte
	mov	dx,CD_CMOS_DATA0
	in	al,dx
	cmp	al,22h
	jz	.transfer
	cmp	al,6
	jz	.exit
	jmp	.error3 ; エラーか、異常なリターンコード

.transfer:
	call	cd_dma_transfer
	call	cd_dma_getaddress
	call	cd_dma_setaddress
	dec	word [es:di+2] ; bx 読み残しセクタを減らす
	jmp	.readloop

.exit:
	in	al,0afh
	or	al,8
	out	0afh,al
	xor	ah,ah
	call	cd_store_result
	ret

.error3:
	in	al,0afh
	or	al,8
	out	0afh,al
.error2:
	mov	ah,80h
	mov	cx,2
.error1:
	call	cd_store_result
	ret


;---------------------------------------------------------------------

; ドライブの状態をチェック
cd_command_0e:
	call	cd_test_ready
	call	cd_store_result
	ret


;---------------------------------------------------------------------
; 下請け

; コマンド実行結果を格納
cd_store_result:
	mov	[si+1],ah
	or	ah,ah
	jns	.noerrorcode
	mov	[es:di+4],cx
.noerrorcode:
	ret

;----------

; CDが読み込み可能かをチェック
cd_test_ready:
	call	cd_recieve
	call	cd_clear_parabuffer
	mov	al,0a0h
	call	cd_sendcommand
	call	cd_recieve4byte

	mov	dx,CD_CMOS_DATA1
	in	al,dx
	and	al,0fh

	mov	ah,80h
	cmp	al,9 ; ノットレディ
	jnz	.j1
	mov	cx,1
	stc
	ret
.j1:
	xor	ah,ah
	clc
	ret

;----------

; パラメータ格納バッファをクリア
cd_clear_parabuffer:
	push	cx
	push	dx
	mov	dx,CD_CMOS_PARA
	xor	al,al
	mov	cx,8
.loop:
	out	dx,al
	add	dx,2
	loop	.loop
	pop	dx
	pop	cx
	ret

;----------

; CDCコマンド発行
cd_sendcommand:
	push	bx
	push	cx
	push	dx
	mov	ah,al
	mov	dx,4c0h
.waitready:
	in	al,dx
	test	al,1
	jz	.waitready

	mov	bx,CD_CMOS_PARA
	mov	cx,8
.commandloop:
	mov	dx,bx
	in	al,dx
	mov	dx,4c4h
	out	dx,al
	add	bx,2
	loop	.commandloop

	mov	al,ah
	mov	dx,4c2h
	out	dx,al
	pop	dx
	pop	cx
	pop	bx
	ret

;----------

; CDCからの4バイトのステータスを取得
cd_recieve4byte:
	push	ax
	push	dx
	mov	dx,4c0h
.loop:
	in	al,dx
	test	al,2
	jz	.loop

	or	al,al

	mov	dx,4c2h
	in	al,dx
	mov	dx,CD_CMOS_DATA0
	out	dx,al
	mov	dx,4c2h
	in	al,dx
	mov	dx,CD_CMOS_DATA1
	out	dx,al
	mov	dx,4c2h
	in	al,dx
	mov	dx,CD_CMOS_DATA2
	out	dx,al
	mov	dx,4c2h
	in	al,dx
	mov	dx,CD_CMOS_DATA3
	out	dx,al

	jns	.exit

	mov	dx,4c0h ; clear irq
	mov	al,80h
	out	dx,al

.exit:
	pop	dx
	pop	ax
	ret

;----------

; 食べ残しをクリア
cd_recieve:
	push	dx
	mov	dx,4c0h
	in	al,dx
	test	al,2
	jz	.exit

.loop:
	call	cd_recieve4byte
	in	al,dx
	test	al,2
	jnz	.loop
.exit:
	pop	dx
	ret

;----------

; 10進変換
cd_hextodecimal:
	push	cx
	mov	ch,ah
	xor	ah,ah
	mov	cl,10
	div	cl
	shl	al,4
	add	al,ah
	mov	ah,ch
	pop	cx
	ret

;----------

; CDのセクタ番号を10進数に変換して保管
cd_set_sectorno:
	push	bx
	push	cx
	push	dx
	add	ax,150   ; CDの先頭セクタはセクタ150
	adc	dx,0
	mov	cx,75*60 ; M-S-F の M
	div	cx
	xchg	ax,dx
	; dx = M, ax = S-F
	mov	cl,75    ; S
	div	cl
	mov	cl,dl
	xchg	al,ah

	; cl-ah-al : M-S-F

	lea	dx,[bx+4]
	call	cd_hextodecimal
	out	dx,al
	sub	dx,2
	mov	al,ah
	call	cd_hextodecimal
	out	dx,al
	sub	dx,2
	mov	al,cl
	call	cd_hextodecimal
	out	dx,al
	pop	dx
	pop	cx
	pop	bx
	ret

;----------

cd_init_dma:
	; リセット
	mov	al,3
	out	0a0h,al

	; チャネルを CD にセット
	mov	al,3
	out	0a1h,al

	; DMA動作禁止
	mov	al,24h
	out	0a8h,al

	; デバイスコントロール
	xor	al,al
	out	0a9h,al

	; モードコントロール
	mov	al,54h
	out	0aah,al
	ret

;----------

cd_dma_setlength:
	out	0a2h,ax
	ret

;----------

cd_dma_setaddress:
	out	0a4h,ax
	mov	ax,dx
	out	0a6h,ax
	ret

;----------

cd_dma_getaddress:
	in	ax,0a6h
	mov	dx,ax
	in	ax,0a4h
	ret

;----------

; DMA転送を行う
cd_dma_transfer:
	push	dx
	; DMA動作許可
	mov	al,20h
	out	0a8h,al

	; 転送開始
	mov	dx,4c6h
	mov	al,10h
	out	dx,al

	; 転送が終わるまで待つ
	mov	dx,4c0h
.loop:
	in	al,dx
	test	al,10h
	jnz	.loop

	; DMA動作禁止
	mov	al,24h
	out	0a8h,al
	pop	dx
	ret
