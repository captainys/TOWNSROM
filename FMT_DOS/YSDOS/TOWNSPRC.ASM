; FM TOWNS Specific Procedures


; 43 3A 5C 4D C:\M
; 53 43 44 45 SCDE
; 58 2E 45 58 X.EX
; 45          E

MSCDEX_EXE				DB		"C:\MSCDEX.EXE"
						DB		0
SHSUCDX_COM				DB		"C:\SHSUCDX.COM"
						DB		0

TOWNS_FOPEN_RETRY:
						PUSH	SI
						PUSH	DI
						PUSH	CX
						PUSH	DS
						PUSH	ES

						MOV		SI,CS
						MOV		DS,SI
						MOV		ES,SI

						MOV		SI,OFFSET FILENAME_BUFFER
						MOV		DI,OFFSET MSCDEX_EXE
						MOV		CX,14
						REP CMPSB
						JNE		TOWNS_FOPEN_RETRY_NOTMSCDEX

						MOV		SI,OFFSET SHSUCDX_COM
						MOV		DI,OFFSET FILENAME_BUFFER
						MOV		CX,15
						REP MOVSB

						CLC
						POP		ES
						POP		DS
						POP		CX
						POP		DI
						POP		SI
						RET

TOWNS_FOPEN_RETRY_NOTMSCDEX:
						STC
						POP		ES
						POP		DS
						POP		CX
						POP		DI
						POP		SI
						RET



TOWNS_CMP_FILENAME_BUFFER_SHSUCDXCOM:
						PUSH	SI
						PUSH	DI
						PUSH	CX
						PUSH	DS
						PUSH	ES

						MOV		SI,CS
						MOV		DS,SI
						MOV		ES,SI

						MOV		SI,OFFSET FILENAME_BUFFER
						MOV		DI,OFFSET SHSUCDX_COM
						MOV		CX,14
						REP CMPSB

						POP		ES
						POP		DS
						POP		CX
						POP		DI
						POP		SI
						RET
