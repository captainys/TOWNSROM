;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FIND_FCB_STRUCT			DB		FINDSTRUC_size dup (0)

FIND_FCB_FILE_TEMPLATE	DB		16 dup(0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


FIND_FIRST_FCB:
						PUSH	DWORD PTR CS:[DMA_BUFFER_PTR]

						CALL	COPY_FCB_TEMPLATE_TO_DMA_BUFFER

						MOV		WORD CS:[DMA_BUFFER_PTR],OFFSET FIND_FCB_STRUCT
						MOV		CS:[DMA_BUFFER_PTR+2],CS

						MOV		SI,DX
						CMP		BYTE PTR DS:[SI],0FFh
						JNE		FIND_FIRST_FCB_ERROR	; Not an extended FCB.

						MOV		DI,OFFSET FIND_FCB_FILE_TEMPLATE
						MOV		AL,DS:[SI+7]			; Drive number.  0 means current drive.  1 means A drive.
						AND		AL,AL
						JE		FIND_FIRST_FCB_CURR_DRV

						DEC		AL
						ADD		AL,'A'
						MOV		AH,':'
						MOV		CS:[DI],AX
						ADD		DI,2

FIND_FIRST_FCB_CURR_DRV:
						MOV		EAX,DS:[SI+7+1]
						MOV		CS:[DI],EAX
						MOV		EAX,DS:[SI+7+5]
						MOV		CS:[DI+4],EAX
						MOV		EAX,DS:[SI+7+9]
						SHL		EAX,8
						MOV		AL,'.'
						MOV		CS:[DI+8],EAX

						MOVZX	CX,BYTE PTR DS:[SI+6]

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FIND_FCB_FILE_TEMPLATE
						; Input
						;   DS:SI File Template
						;   CX Attribute Mask (CH=0)
						;   CS:[DMA_BUFFER_PTR] Pointer to store FINDSTRUCT
						CALL	FIND_FIRST
						; Output
						;   CF=0 Success
						;   CF=1 Error AX=Error Code DOSERR_FILE_NOT_FOUND,DOSERR_DIR_NOT_FOUND, or DOSERR_NO_MORE_FILES
						JB		FIND_FIRST_FCB_ERROR



						POP		DWORD PTR CS:[DMA_BUFFER_PTR]

						CALL	COPY_FINDSTRUC_TO_FCB
						XOR		AL,AL
						RET

FIND_FIRST_FCB_ERROR:
						MOV		AL,0FFh
						POP		DWORD PTR CS:[DMA_BUFFER_PTR]
						STC
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


FIND_NEXT_FCB:
						PUSH	DWORD CS:[DMA_BUFFER_PTR]

						CALL	COPY_FCB_TEMPLATE_TO_DMA_BUFFER

						MOV		WORD CS:[DMA_BUFFER_PTR],OFFSET FIND_FCB_STRUCT
						MOV		CS:[DMA_BUFFER_PTR+2],CS

						; Input
						;   CX Attribute Mask (CH=0)
						;   CS:[DMA_BUFFER_PTR] Pointer to FINDSTRUCT populated by FIND_FIRST
						CALL	FIND_NEXT
						; Output
						;   CF=0 Success
						;   CF=1 Error AX=Error Code DOSERR_FILE_NOT_FOUND,DOSERR_DIR_NOT_FOUND, or DOSERR_NO_MORE_FILES
						JB		FIND_NEXT_FCB_ERROR

						POP		DWORD CS:[DMA_BUFFER_PTR]
						CALL	COPY_FINDSTRUC_TO_FCB
						XOR		AL,AL
						RET

FIND_NEXT_FCB_ERROR:
						MOV		AL,0FFh
						POP		DWORD PTR CS:[DMA_BUFFER_PTR]
						STC
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Input DS:DX FCB template
;       CS:DMA_BUFFER_PTR
COPY_FCB_TEMPLATE_TO_DMA_BUFFER:
						MOV		SI,DX
						LES		DI,CS:[DMA_BUFFER_PTR]
						CLD
						MOV		CX,02CH/4
						REP		MOVSD
						RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

COPY_FINDSTRUC_TO_FCB:
						CLD
						LES		DI,CS:[DMA_BUFFER_PTR]

						PUSH	CS
						POP		DS

						MOV		BYTE PTR ES:[DI],0FFh	; Extended FCB

						MOV		AL,[FIND_FCB_STRUCT+FIND_FOUND_ATTR]
						MOV		ES:[DI+6],AL

						MOV		AX,[FIND_FCB_STRUCT+FIND_COUNT_IN_DIR]
						MOV		ES:[DI+7+0CH],AX

						MOV		AX,[FIND_FCB_STRUCT+FIND_FOUND_TIME]
						MOV		ES:[DI+7+16H],AX	; 16H is questionable.

						MOV		AX,[FIND_FCB_STRUCT+FIND_FOUND_DATE]
						MOV		ES:[DI+7+14H],AX	; 14H is questionable.

						MOV		AX,[FIND_FCB_STRUCT+FIND_COUNT_IN_DIR]
						MOV		ES:[DI+7+20H],AX

						MOV		EAX,[FIND_FCB_STRUCT+FIND_FOUND_FILE_SIZE]
						MOV		ES:[DI+7+10H],EAX


						MOV		CX,8
						LEA		DI,[DI+7+1]
						LEA		SI,[FIND_FCB_STRUCT+FIND_FOUND_FILENAME]
COPY_FINDSTRUC_TO_FCB_NAME_LOOP:
						MOV		AL,[SI]
						CMP		AL,'.'
						JE		COPY_FINDSTRUC_TO_FCB_NAME_LOOP_BREAK
						CMP		AL,0
						JE		COPY_FINDSTRUC_TO_FCB_NAME_LOOP_BREAK
						INC		SI
						STOSB
						LOOP	COPY_FINDSTRUC_TO_FCB_NAME_LOOP
COPY_FINDSTRUC_TO_FCB_NAME_LOOP_BREAK:

						MOV		AL,' '
						REP		STOSB
						MOV		CX,3

COPY_FINDSTRUC_TO_FCB_SKIPDOT_LOOP:
						LODSB
						CMP		AL,'.'
						JE		COPY_FINDSTRUC_TO_FCB_SKIPDOT_BREAK
						CMP		AL,0
						JE		COPY_FINDSTRUC_TO_FCB_EXT_BREAK		; No extension.  Skip EXT-Loop.
						JMP		COPY_FINDSTRUC_TO_FCB_SKIPDOT_LOOP
COPY_FINDSTRUC_TO_FCB_SKIPDOT_BREAK:


COPY_FINDSTRUC_TO_FCB_EXT_LOOP:
						LODSB
						CMP		AL,0
						JE		COPY_FINDSTRUC_TO_FCB_EXT_BREAK
						STOSB
						LOOP	COPY_FINDSTRUC_TO_FCB_EXT_LOOP
COPY_FINDSTRUC_TO_FCB_EXT_BREAK:


						MOV		AL,' '
						REP		STOSB

						RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
