; Turned to 0 at the beginning of INT 21H AH=4Bh
; Turned to 1 if the fully-qualified file name given to INT 21H AH=4Bh is "C:\SHSUCDX.COM"
; YSDOS.SYS needs to identify itself as MS-DOS V3.3 to SHSUCDX, but 3.1 to C:\COMMAND.COM from TOWNS ROM
; This trick will be unnecessary as soon as I write my own COMMAND.COM.
STARTING_SHSUCDX		DB		0



; CTL.SYS gets USER_SP, USER_SS, NSS, and NSP pointers by searching through MSDOS.SYS
; It expects to find six bytes from:
;1679:000011D2 8CCB                      MOV     BX,CS
;1679:000011D4 8EDB                      MOV     DS,BX
;1679:000011D6 FE06CF02                  INC     BYTE PTR [02CFH]
;1679:000011DA 33C0                      XOR     AX,AX
;1679:000011DC A3EA02                    MOV     [02EAH],AX
;1679:000011DF A1DE02                    MOV     AX,[02DEH]
;1679:000011E2 A3E802                    MOV     [02E8H],AX
;1679:000011E5 A11E05                    MOV     AX,[051EH]    11E6h=051Eh  USER_SP
;1679:000011E8 A38405                    MOV     [0584H],AX    11E9h=0584h  NSP
;1679:000011EB A12005                    MOV     AX,[0520H]    11ECh=0520h  USER_SS
;1679:000011EE A38205                    MOV     [0582H],AX    11EFh=0582h  NSS
; And then look at +14H for USER_SP, +17H for NSP, +1AH for USER_SS, and +1DH for NSS.
; WTF!
	DB	08Ch,0CBh,08Eh,0DBh,0FEh,006h
	DB	13 dup(0)
	DB	0
	DW	051Eh
	DB	0
	DW	0584h
	DB	0
	DW	0520h
	DB	0
	DW	0582h
