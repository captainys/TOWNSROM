						ASSUME	CS:CODE

						.386
CODE					SEGMENT	USE16
						ORG	0000h
MAIN:
						; MSDOS.SYS Loader by CaptainYS
						; IO.SYS reads only up to 7800H.
						; So, instead, this program reads 0FE00H
						; It adds a lot of room for experiments.
						; IO.SYS will pass DX as ENDMEM, and DS:SI as driver list.
						PUSHAD
						PUSH	DS
						PUSH	ES

						PUSH	CS
						POP		ES
						PUSH	CS
						POP		DS

						CLD
						MOV		SI,OFFSET TRANS_AND_RUN
						MOV		DI,TRANSFER_DESTIN
						MOV		CX,0100H
						REP 	MOVSB

						MOV		AX,TRANSFER_DESTIN
						PUSH	AX
						RET					; Jump by RET.   EXEC &HFE00

TRANS_AND_RUN:
						MOV		AX,0542h	; Command 05 Read Sector, Device Num=42h ROM Disk
						MOV		CX,0		; CH=0, CL=LBA High=0
						MOV		DX,00A4h+2	; One cluster after LOADER.SYS
						MOV		BX,127		; 127sectors times 512bytes = 0FE00h bytes.
						XOR		DI,DI		; OFFSET 0, DS=CS
						INT		93H

						POP		ES
						POP		DS
						POPAD

						PUSH	0000h
						RET					; Jump by RET.

TRANSFER_DESTIN			EQU		0FE00H

CODE					ENDS
						END
