; version 2003.03.04.1
;---------------------------------------------------------------------
;
; FM TOWNS 互換 ROM シリーズ
;
; FMT_SYS.ROM : FDアクセス
;
; by Kasanova & CaptainYS
;
;---------------------------------------------------------------------
; ※単独ではアセンブルしません

;---------------------------------------------------------------------
; 読み込み
; Corrected by CaptainYS >>
; al    : Device ID
; bx    : Number of Sectors
; cx    : Cylinder
; dh    : Head
; dl    : Sector
; ds:di : Buffer Address
; Corrected by CaptainYS <<
; [リターンコード]
;  ah : 0(正常終了)、bx : 読み残したセクタ数

fd_command_05:
	; by CaptainYS >>
	; ds:[si]=ax ds:[si+2]=dx
	; es:[di]=FLAGS es:[di+2]=bx es:[di+4]=cx es:[di+6]=bp es:[di+8]=si es:[di+10]=di es:[di+12]=ds es:[di+14]=es
	; Returned AH will be written to ds:[si+1] in disk_bios.

	call	fd_wait_ready

	mov		cl,ds:[si]
	call	fd_select_drive_2hd

	call	fd_wait_ready
	call	fd_motor_on_select_side_2hd

	call	fd_wait_ready
	mov		ax,es:[di+4]	; ax=cylinder
	call	fd_seek

	call	fd_wait_ready

fd_trap:
	jmp		fd_trap		; by CaptainYS
	; by CaptainYS <<
	ret

; by CaptainYS >>
; Input
;   CL=Drive (High 4-bits will be cleared)
fd_select_drive_2hd:
	mov		dx,IO_FDC_DRIVE_SELECT

	; For booting, 1232KB disk support is good enough, I think.
	mov		al,050h ; HISPD (360rpm 2HD)
	out		dx,al	; Clear drive selection once.

	mov		cl,ds:[si]
	and		cl,0fh	; Drive number
	mov		al,1
	shl		al,cl	; Set Drive Bit
	or		al,050h	; HISPD (360rpm 2HD)
	out		dx,al	; Drive selected, HISPD latched.

	ret


; ah=side 0 or 1
fd_motor_on_select_side_2hd:
	and		ah,1
	shl		ah,2
	mov		al,012h ; 2MHz Clock, Motor On, DDEN, IRQ Off
	or		al,ah
	mov		dx,IO_FDC_DRIVE_CONTROL
	out		dx,al
	ret


; Input
;   AL=Cylinder
fd_seek:
	mov		dx,IO_FDC_DATA
	out		dx,al
	mov		dx,IO_FDC_COMMAND
	mov		al,IO_FDC_CMD_SEEK
	out		dx,al
	ret


fd_wait_ready:
	mov		dx,IO_FDC_STATUS
	in		al,dx
	and		al,1
	jne		fd_wait_ready
	ret
; by CaptainYS <<


;---------------------------------------------------------------------
; ドライブの状態をチェック

fd_command_0e:
	ret

