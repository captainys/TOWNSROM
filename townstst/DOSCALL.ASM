						ASSUME	CS:CODE

						PUBLIC	DOSCALL_RENAME
						PUBLIC	DOSCALL_OPEN_RD
						PUBLIC	DOSCALL_OPEN_WR
						PUBLIC	DOSCALL_CLOSE
						PUBLIC	DOSCALL_WRITE

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





DOSCALL_OPEN_RD			PROC
						PUSH	EBP
						MOV		EBP,ESP
						PUSH	EDI
						PUSH	ESI
						PUSH	EDX
						PUSH	ES

						; [EBP] 	EBP
						; [EBP+4] 	EIP
						; [EBP+8]	First Param
						MOV		EDX,[EBP+8]
						MOV		AX,3D00h
						INT		21H
						JNC		DOSCALL_OPEN_RD_EXIT

						OR		EAX,80000000h

DOSCALL_OPEN_RD_EXIT:
						POP		ES
						POP		EDX
						POP		ESI
						POP		EDI
						POP		EBP
						RET

DOSCALL_OPEN_RD			ENDP





DOSCALL_OPEN_WR			PROC
						PUSH	EBP
						MOV		EBP,ESP
						PUSH	EDI
						PUSH	ESI
						PUSH	EDX
						PUSH	ES

						; [EBP] 	EBP
						; [EBP+4] 	EIP
						; [EBP+8]	First Param
						MOV		EDX,[EBP+8]
						MOV		AX,3D01h
						INT		21H
						JNC		DOSCALL_OPEN_WR_EXIT

						OR		EAX,80000000h

DOSCALL_OPEN_WR_EXIT:
						POP		ES
						POP		EDX
						POP		ESI
						POP		EDI
						POP		EBP
						RET

DOSCALL_OPEN_WR			ENDP





DOSCALL_CLOSE			PROC
						PUSH	EBP
						MOV		EBP,ESP
						PUSH	EDI
						PUSH	ESI
						PUSH	EDX
						PUSH	ES

						; [EBP] 	EBP
						; [EBP+4] 	EIP
						; [EBP+8]	First Param
						MOV		EBX,[EBP+8]
						TEST	EBX,80000000h
						JNE		DOSCALL_CLOSE_EXIT

						MOV		AX,3E00h
						INT		21H
						JNC		DOSCALL_CLOSE_EXIT

						OR		EAX,80000000h

DOSCALL_CLOSE_EXIT:
						POP		ES
						POP		EDX
						POP		ESI
						POP		EDI
						POP		EBP
						RET

DOSCALL_CLOSE			ENDP





DOSCALL_WRITE			PROC
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
						; [EBP+16]	Third Param
						MOV		EBX,[EBP+8]
						TEST	EBX,80000000h
						JNE		DOSCALL_WRITE_EXIT

						MOV		ECX,[EBP+12]
						MOV		EDX,[EBP+16]

						MOV		AX,4000h
						INT		21H
						JNC		DOSCALL_WRITE_EXIT

						OR		EAX,80000000h

DOSCALL_WRITE_EXIT:
						POP		ES
						POP		EDX
						POP		ESI
						POP		EDI
						POP		EBP
						RET

DOSCALL_WRITE			ENDP




CODE					ENDS
						END
