						ASSUME	CS:CODE

						PUBLIC	DOSCALL_RENAME

CODE					SEGMENT


DOSCALL_RENAME			PROC
						PUSH	EBP
						MOV		EBP,ESP
						PUSH	EDI
						PUSH	ESI
						PUSH	EDX
						PUSH	ES

						; [EBP] 	EBP
						; [EBP+4] 	EIP
						; [EBP+8]	First Param
						; [EBP+12]	Second Param
						MOV		EDX,[EBP+8]
						MOV		EDI,[EBP+12]
						PUSH	DS
						POP		ES
						MOV		AH,056H
						INT		21H
						JC		DOSCALL_RENAME_ERR

						XOR		EAX,EAX

DOSCALL_RENAME_ERR:
						POP		ES
						POP		EDX
						POP		ESI
						POP		EDI
						POP		EBP
						RET

DOSCALL_RENAME			ENDP


CODE					ENDS
						END
