; version 2003.03.04.1
;---------------------------------------------------------------------
;
; FM TOWNS 互換 ROM シリーズ
;
; FMT_SYS.ROM : HDアクセス
;
; by Kasanova
;
;---------------------------------------------------------------------
; ※単独ではアセンブルしません

; SCSIコントロールは面倒くさいので、HDアクセスはうんづに投げられる
; ようにする予定

;---------------------------------------------------------------------
; 読み込み
; cl+dx : 読み込み開始セクタ番号(16進)
; bx    : 読み込むセクタ数
; ds:di : 転送先アドレス
; [リターンコード]
;  ah : 0(正常終了)、bx : 読み残したセクタ数

hd_command_05:
	; by CaptainYS >>
	; ds:[si]=ax ds:[si+2]=dx
	; es:[di]=FLAGS es:[di+2]=bx es:[di+4]=cx es:[di+6]=bp es:[di+8]=si es:[di+10]=di es:[di+12]=ds es:[di+14]=es
	; Returned AH will be written to ds:[si+1] in disk_bios.

	push	edx
	push	edi
	push	eax

	movzx	eax,word es:[di+12]
	shl		eax,4
	movzx	edx,word es:[di+10]
	add		eax,edx					; EAX is destination address.

	movzx	edx,byte es:[di+4]
	shl		edx,16
	mov		dx,ds:[si+2]			; EDX is sector

	mov		bx,es:[di+2]			; BX is number of sectors

	mov		cl,ds:[si]
	and		cl,0Fh					; CL is SCSI ID

	push	ds
	push	es
	push	di
	push	si
	mov		edi,eax					; EDI is destination address.

	push	cs
	pop		ds

	; Input
	;   CL    SCSI ID
	;   EDX   Starting Sector
	;   BX    Number of Sectors
	;   EDI   Data Buffer Physical Address
	;   DS=CS
	call	SCSI_READ_SECTOR
	; Output
	;   CF    Set if error

	pop		si
	pop		di
	pop		es
	pop		ds

	pop		eax
	pop		edi
	pop		edx

	mov		ah,00h
	jnc		.noerror

	mov		ah,80h
	mov		word es:[di+4],BIOSERR_DETAIL_HD_HARD_ERROR	; I should really call SENSE to find what happened.
.noerror:
	; << By CaptainYS

	ret

;---------------------------------------------------------------------
; ドライブの状態をチェック

hd_command_0e:
	ret

