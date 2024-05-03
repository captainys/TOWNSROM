; FM TOWNS Specific Initialization.



; This is included after DOSINIT.
; This code will be destroyed after initialization.

DOSINIT_TOWNS_NOTIFY_CS:
					PUSH	AX
					PUSH	DX

					MOV		DX,TSUGARUIO_VM_HOST_IF_CMD_STATUS
					MOV		AL,TOWNS_VMIF_CMD_NOTIFY_DOSSEG
					OUT		DX,AL

					POP		DX
					POP		AX
					RET



; Kasanova's Compatible FMT_SYS changes the system palette.
; This function will reset.
TOWNS_DEF_PALETTE:
;In      Out
		;112233->223311
		;aabbcc->bbccaa
		; Page 0
				;In             ; Out
				;aa   bb   cc   ; bbccaa
		DB		000h,000h,000h  ; 000000
		DB		088h,000h,000h  ; 000088
		DB		000h,088h,000h  ; 880000
		DB		088h,088h,000h  ; 880088
		DB		000h,000h,088h  ; 008800
		DB		088h,000h,088h  ; 008888
		DB		000h,088h,088h  ; 888800
		DB		088h,088h,088h  ; 888888
		DB		044h,044h,044h  ; 444444
		DB		0FFh,000h,000h  ; 0000FF
		DB		000h,0FFh,000h  ; FF0000
		DB		0FFh,0FFh,000h  ; FF00FF
		DB		000h,000h,0FFh  ; 00FF00
		DB		0FFh,000h,0FFh  ; 00FFFF
		DB		000h,0FFh,0FFh  ; FFFF00
		DB		0FFh,0FFh,0FFh  ; FFFFFF

;16-Color Palette (I don't care about Page 1)
;Page0:000000 000088 880000 880088 008800 008888 888800 888888 444444 0000FF FF0000 FF00FF 00FF00 00FFFF FFFF00 FFFFFF
;Page1:000000 0000BB BB0000 BB00BB 00BB00 00BBBB BBBB00 BBBBBB 000000 0000FF FF0000 FF00FF 00FF00 00FFFF FFFF00 FFFFFF
DOSINIT_TOWNS_PALETTE:
					PUSH	SI
					PUSH	AX
					PUSH	BX
					PUSH	DX

					MOV		SI,OFFSET TOWNS_DEF_PALETTE
					MOV		BL,0
DOSINIT_TOWNS_PALETTE_LOOP:
					MOV		DX,TOWNS_IO_PALETTE
					MOV		AL,BL
					OUT		DX,AL

					ADD		DX,2
					MOV		AL,CS:[SI]
					INC		SI
					OUT		DX,AL

					ADD		DX,2
					MOV		AL,CS:[SI]
					INC		SI
					OUT		DX,AL

					ADD		DX,2
					MOV		AL,CS:[SI]
					INC		SI
					OUT		DX,AL

					INC		BL
					CMP		BL,16
					JNE		DOSINIT_TOWNS_PALETTE_LOOP

					POP		DX
					POP		BX
					POP		AX
					POP		SI
					RET



DOSINIT_TOWNS_CLS:
					PUSH	ES
					PUSH	CX
					PUSH	DI
					PUSH	EAX
					MOV		AX,0C000h
					MOV		ES,AX
					XOR		EAX,EAX
					XOR		DI,DI
					MOV		CX,2000h
					REP STOSD
					POP		EAX
					POP		DI
					POP		CX
					POP		ES
					RET



; What is this?
; FM TOWNS OS V1.1 L30's MENU_DRV, included in IO.SYS has a bug, which makes SHSUCDX unusable.
; I personally think R-drive was a bad idea to start with.
;
; In MENU_DRV at 0A42:2AC0, it jumps if CF=0 from the previous call, obviousl CF=0 means no error.
; This skips POP BX, and the stack pointer shifts.
; Nonetheless, it returns successfully because it restores SS and SP from its own location,
; and then RETF.
; Probably the original MSCDEX.EXE pushes all the registers before calling MENU_DRV.
; SHSUCDX correctly assumes that the CD-ROM physical driver will save files, and therefore
; fails.
; 
; To patch it, I can change JAE 2AC9h, POP BX  to POP AX, JAE 2AC9h
; 0A42:00002ABE 5B                        POP     BX
; 0A42:00002ABF 1F                        POP     DS
; 0A42:00002AC0 7307                      JAE     00002AC9   -> 58h      POP AX
; 0A42:00002AC2 5B                        POP     BX         -> 73h 06h  JAE 2AC9
; 0A42:00002AC3 B80281                    MOV     AX,8102H
; 0A42:00002AC6 E9BB00                    JMP     00002B84
; 0A42:00002AC9 E9B500                    JMP     00002B81
;
; Also correct JB 2AC2h to JB 2AC0h at 0A42:2A8B
; From  0A42:00002A8B 7235                      JB      00002AC2
; To    0A42:00002A8B 7233                      JB      00002AC0
;
;
; V1.1 L20 MENU_DRV also comes with a bug.
;
; FROM
;0A7E:000046CE FA                        CLI
;0A7E:000046CF 8C165640                  MOV     [4056H],SS   <- CS:
;0A7E:000046D3 89265840                  MOV     [4058H],SP   <- CS:
;0A7E:000046D7 BC7E0A                    MOV     SP,0A7EH
;0A7E:000046DA 8ED4                      MOV     SS,SP
;0A7E:000046DC BC5A42                    MOV     SP,425AH
;0A7E:000046DF FB                        STI
; TO
;TO
;						; CLI,STI unnecessary because INT is disabled for the next instruction after SS change
;						ORG		46CEH
;						MOV     CS:[4056H],SS
;						MOV     CS:[4058H],SP
;						PUSH	CS
;						POP		SS
;						MOV     SP,425AH
;						STI
;						NOP
;
; 46CEH
; 2Eh,8Ch,16h,56h,40h
; 2Eh,89h,26h,58h,40h
; 0Eh
; 17h
; BCh,5Ah,42h
; FBh
; 90h
; 90h
;
; and
;
;FROM
;0A7E:00004848 FA                        CLI
;0A7E:00004849 8B265840                  MOV     SP,[4058H]   <- CS:
;0A7E:0000484D 8E165640                  MOV     SS,[4056H]   <- CS:
;0A7E:00004851 FB                        STI

;TO
;						ORG		4848h
;						MOV     SS,CS:[4056H]
;						MOV     SP,CS:[4058H]
;
;4848H
; 2Eh,8Eh,16h,56h,40h
; 2Eh,8Bh,26h,58h,40h
;
;
; Also it destroys DOS segment:
;0A7E:00004724 A36042                    MOV     [4260H],AX   <- Most likely CS:[4260H]
;0A7E:00004727 89166242                  MOV     [4262H],DX   <- Most likely CS:[4262H]
;0A7E:0000472B 53                        PUSH    BX
;0A7E:0000472C 89265C42                  MOV     [425CH],SP
;0A7E:00004730 2E803E6C4600              CMP     BYTE PTR CS:[466CH],00H
;0A7E:00004736 740B                      JE      00004743
;0A7E:0000480F FF0E5E42                  DEC     WORD PTR [425EH]   <- Most Likely CS:[425Eh]
;
; Unfortunately I cannot find extra bytes to insert CS prefix.
; Luckly, virtually zero FM TOWNS apps are based on Towns OS V1.1 L20.

DOSINIT_PATCH_TOSV11L30_MENU_DRV	PROC
						; Is it IO.SYS of TOWNS OS V1.1 L30?
						CMP		DWORD PTR DS:[2AC0h],0B85B0773h   ; 73 07 5B B8
						JNE		DOSINIT_PATCH_TOS_NOTV11L30
						CMP		DWORD PTR DS:[2AC4h],0BBE98102h
						JNE		DOSINIT_PATCH_TOS_NOTV11L30

						MOV		DWORD PTR DS:[2AC0h],0B8067358h   ; 58 73 06 B8


						CMP		WORD PTR DS:[2A8Bh],3572h ; From  0A42:00002A8B 7235    JB 00002AC2
						JNE		DOSINIT_PATCH_TOS_RETURN

						MOV		WORD PTR DS:[2A8Bh],3372h ; To    0A42:00002A8B 7233    JB 00002AC0


						JMP		DOSINIT_PATCH_TOS_RETURN


DOSINIT_PATCH_TOS_NOTV11L30:
						CMP		DWORD PTR DS:[46CFH],04056168Ch
						JNE		DOSINIT_PATCH_TOS_NOTV11L20
						CMP		DWORD PTR DS:[46D3H],040582689h
						JNE		DOSINIT_PATCH_TOS_NOTV11L20
						CMP		DWORD PTR DS:[4849h],04058268Bh
						JNE		DOSINIT_PATCH_TOS_NOTV11L20
						CMP		DWORD PTR DS:[484Dh],04056168Eh
						JNE		DOSINIT_PATCH_TOS_NOTV11L20

						MOV		DWORD PTR DS:[46CEh],056168C2Eh
						MOV		DWORD PTR DS:[46D2h],026892E40h
						MOV		DWORD PTR DS:[46D6h],0170E4058h
						MOV		DWORD PTR DS:[46DAh],0FB425ABCh
						MOV		WORD PTR DS:[46DEh],09090h

						MOV		DWORD PTR DS:[4848h],056168E2Eh
						MOV		DWORD PTR DS:[484Ch],0268B2E40h
						MOV		WORD PTR DS:[4850h],04058h

						MOV		DWORD PTR DS:[480Fh],90909090h


DOSINIT_PATCH_TOS_NOTV11L20:

DOSINIT_PATCH_TOS_RETURN:
						RET


DOSINIT_PATCH_TOSV11L30_MENU_DRV	ENDP
