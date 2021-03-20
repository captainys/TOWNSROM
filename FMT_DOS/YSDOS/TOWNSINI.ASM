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



; Open Version of FMT_SYS alters the palette.
;16-Color Palette
;Page0:000000 000088 880000 880088 008800 008888 888800 888888 444444 0000FF FF0000 FF00FF 00FF00 00FFFF FFFF00 FFFFFF
;Page1:000000 0000BB BB0000 BB00BB 00BB00 00BBBB BBBB00 BBBBBB 000000 0000FF FF0000 FF00FF 00FF00 00FFFF FFFF00 FFFFFF
DOSINIT_TOWNS_PALETTE:
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
;
;
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

DOSINIT_PATCH_TOSV11L30_MENU_DRV	PROC
						; Is it IO.SYS of TOWNS OS V1.1 L30?
						CMP		DWORD PTR DS:[2AC0h],0B85B0773h   ; 73 07 5B B8
						JNE		DOSINIT_PATCH_TOS_NOTV11L30
						CMP		DWORD PTR DS:[2AC4h],0BBE98102h
						JNE		DOSINIT_PATCH_TOS_NOTV11L30

						MOV		DWORD PTR DS:[2AC0h],0B8067358h   ; 58 73 06 B8
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



DOSINIT_PATCH_TOS_NOTV11L20:

DOSINIT_PATCH_TOS_RETURN:
						RET


DOSINIT_PATCH_TOSV11L30_MENU_DRV	ENDP
