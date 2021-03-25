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
	cmp		word es:[di+2],0	; bx
	jne		.non_zero_sector
	xor		ah,ah
	ret

.non_zero_sector:
	push	edx
	push	eax

	call	fd_wait_ready
	or		al,al
	js		.fd_drive_not_ready

	mov		cl,ds:[si]
	call	fd_select_drive_2hd

	call	fd_wait_ready
	call	fd_motor_on_select_side_2hd


	mov		bx,es:[di+4]	; bx=cylinder
	mov		cx,ds:[si+2]	; ch=head, cl=sector

	movzx	edx,word es:[di+12]	; DS
	shl		edx,4
	movzx	eax,word es:[di+10]	; DI
	add		edx,eax

	cli		; should be recovered when leaving the BIOS

.fd_sector_loop:
	push	bx		; cylinder
	push	cx		; ch=head, cl=sector
	push	edx		; DMA addr

	mov		ah,ch
	call	fd_wait_ready
	call	fd_motor_on_select_side_2hd

	call	fd_wait_ready
	mov		ax,bx
	call	fd_seek
	call	fd_wait_ready
	test	al,010h
	jne		.fd_seek_error

	call	fd_dma_initialize
	pop		edx
	push	edx
	mov		ax,SECTOR_LENGTH_1232KB_DISK
	call	sys_setup_dma

	pop		edx
	pop		cx
	pop		bx

	push	bx
	push	cx
	push	edx

	mov		al,bl
	mov		dx,IO_FDC_TRACK
	out		dx,al
	mov		al,cl
	mov		dx,IO_FDC_SECTOR
	out		dx,al
	mov		al,IO_FDC_CMD_READ_DATA
	mov		dx,IO_FDC_COMMAND
	out		dx,al

	call	fd_wait_ready
	test	al,08h	; CRC Error
	je		.fd_crc_error
	test	al,10h	; Record not found
	je		.fd_record_not_found
	test	al,04h	; Lost data
	je		.fd_lost_data

	pop		edx
	pop		cx
	pop		bx

	add		edx,SECTOR_LENGTH_1232KB_DISK

	inc		cl
	cmp		cl,SECTOR_PER_TRACK_1232KB_DISK
	jb		.fd_sector_continue

	xor		cl,cl
	inc		ch
	and		ch,1
	jne		.fd_sector_continue

	inc		bx

.fd_sector_continue:
	dec		word es:[di+2]	;	bx
	jne		.fd_sector_loop

	; IO.SYS apparently won't reset Highest Byte of the DMA address.
	; Make sure to clear when exit.
	xor		al,al
	out		IO_DMA_ADDR_HIGH,AL


.fd_trap:
	jmp		.fd_trap		; by CaptainYS
	; by CaptainYS <<

	pop		eax
	pop		edx
	xor		ah,ah
	ret

.fd_drive_not_ready:
	pop		eax
	pop		edx
	mov		ah,80h
	mov		word es:[di+4],BIOSERR_DETAIL_DISK_DRIVE_NOT_READY
	ret

.fd_seek_error:
	pop		bx
	pop		cx
	pop		edx
	pop		eax
	pop		edx
	mov		ah,80h
	mov		word es:[di+4],BIOSERR_DETAIL_DISK_SEEK_ERROR
	ret

.fd_crc_error:
	pop		bx
	pop		cx
	pop		edx
	pop		eax
	pop		edx
	mov		ah,80h
	mov		word es:[di+4],BIOSERR_DETAIL_DISK_CRC_ERROR
	ret

.fd_record_not_found:
	pop		bx
	pop		cx
	pop		edx
	pop		eax
	pop		edx
	mov		ah,80h
	mov		word es:[di+4],BIOSERR_DETAIL_DISK_RECORD_NOT_FOUND
	ret

.fd_lost_data:
	pop		bx
	pop		cx
	pop		edx
	pop		eax
	pop		edx
	mov		ah,80h
	mov		word es:[di+4],BIOSERR_DETAIL_DISK_LOST_DATA
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


; Input
;   EDX=Physical Address
;   AX=Sector Length
sys_setup_dma:
	PUSH	EAX
	MOV		EAX,EDX
	MOV		DX,IO_DMA_ADDR_LOW
	OUT		DX,AL

	SHR		EAX,8
	INC		DX
	OUT		DX,AL

	SHR		EAX,8
	INC		DX
	OUT		DX,AL

	SHR		EAX,8
	INC		DX
	OUT		DX,AL

	POP		EAX

	MOV		DX,IO_DMA_COUNT_LOW
	OUT		DX,AL

	SHR		AX,8
	INC		DX
	OUT		DX,AL

	RET



fd_dma_initialize:
	MOV		AL,3	; Reset SCSI Controller
	OUT		IO_DMA_INITIALIZE,AL
	MOV		AL,DMA_CHANNEL_FDC
	OUT		IO_DMA_CHANNEL,AL
	MOV		AL,20H	; DMA enable
	OUT		IO_DMA_DEVICE_CTRL_LOW,AL
	RET



; by CaptainYS <<


;---------------------------------------------------------------------
; ドライブの状態をチェック

fd_command_0e:
	ret

