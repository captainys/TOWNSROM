;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Memo to myself:
;   "Page" in DOS means a 16-byte block.  A page needs to be at the top of a segment, that is 16-byte aligned.
; Reference:
; https://www.drdobbs.com/architecture-and-design/mapping-dos-memory-allocation/184408026



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   REG   Register to return
;   MCB   Current MCB segment
GET_NEXT_MCB			MACRO	REG,MCB						;--NOT_IN_NASM--
						MOV		REG,MCB						;--NOT_IN_NASM--
						INC		REG							;--NOT_IN_NASM--
						ADD		REG,MCB:[MCB_BLOCK_SIZE]	;--NOT_IN_NASM--
						ENDM								;--NOT_IN_NASM--

;%MACRO					GET_NEXT_MCB	2					;--USE_IN_NASM--
;						MOV		%1,%2						;--USE_IN_NASM--
;						INC		%1							;--USE_IN_NASM--
;						ADD		%1,%2:[MCB_BLOCK_SIZE]		;--USE_IN_NASM--
;						%ENDMACRO							;--USE_IN_NASM--


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   BX  Number of pages requested
; Output
;   CF=0 -> AX=Segment Allocated (MCB+1)
;   CF=1 -> AX=Error Code  BX=Max available pages  Out of memory or broken MCB
; The function will split an available arena to make an arena with exactly
; requested number of pages.  Then assign PID from CurrentPDB, and return
; the MCB
MALLOC					PROC
						PUSH	DS
						PUSH	ES
						PUSH	BP
						PUSH	CX
						PUSH	BX

						MOV		BP,SP
						CALL	MEM_FIND_AVAILABLE
						JB		MALLOC_ERROR
						CALL	MEM_SPLIT_ARENA
						CALL	MEM_ASSIGN_CURRENT_PID

						MOV		AX,DS
						INC		AX		; Skipping MCB

MALLOC_EXIT:			POP		BX
						POP		CX
						POP		BP
						POP		ES
						POP		DS
						RET

MALLOC_ERROR:			MOV		SS:[BP],BX
						JMP		MALLOC_EXIT

MALLOC					ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   BX  Number of pages requested
; Output
;   CF=0 -> DS  MCB of the new arena  AX destroyed
;   CF=1 -> Out of memory or broken MCB  BX is max available pages  AX is error code
;   ES,CX  Destroyed
; It doesn't do anything smart.  It just returns the first-found big-enough system arena.
MEM_FIND_AVAILABLE		PROC
						MOV		DS,CS:[FIRST_MCB]
						MOV		CX,0

MEM_FIND_AVAILABLE_LOOP:
						CALL	MEM_CHECK_MCB_CHAIN_ID
						MOV		AX,DOSERR_MCB_BROKEN		; Tentative
						JB		MEM_FIND_AVAILABLE_ERROR_END

						CMP		WORD PTR DS:[MCB_PID],MCB_PID_SYSTEM
						JNE		MEM_FIND_AVAILABLE_NEXT

						CALL	MEM_MERGE_ARENAS

						CMP		WORD PTR DS:[MCB_BLOCK_SIZE],BX
						JB		MEM_FIND_AVAILABLE_NOT_BIG_ENOUGH

						; Found one.  CF=0 from the above JB condition.
						RET

MEM_FIND_AVAILABLE_NOT_BIG_ENOUGH:
						CMP		CX,WORD PTR DS:[MCB_BLOCK_SIZE]
						JAE		MEM_FIND_AVAILABLE_NEXT
						MOV		CX,WORD PTR DS:[MCB_BLOCK_SIZE]

MEM_FIND_AVAILABLE_NEXT:
						CMP		BYTE PTR DS:[MCB_CHAIN_ID],MCB_CHAIN_ID_LAST
						JE		MEM_FIND_AVAILABLE_ERROR_END

						GET_NEXT_MCB	AX,DS
						MOV		DS,AX
						JMP		MEM_FIND_AVAILABLE_LOOP

MEM_FIND_AVAILABLE_OUT_OF_MEMORY:
						MOV		AX,DOSERR_OUT_OF_MEMORY
MEM_FIND_AVAILABLE_ERROR_END:
						MOV		BX,CX
						STC
						RET
MEM_FIND_AVAILABLE		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS  MCB
; Output
;   CF=0  OK
;   CF=1  Broken
MEM_CHECK_MCB_CHAIN_ID		PROC
							CMP		BYTE PTR DS:[MCB_CHAIN_ID],MCB_CHAIN_ID_NORMAL
							JE		MEM_CHECK_MCB_CHAIN_ID_OK
							CMP		BYTE PTR DS:[MCB_CHAIN_ID],MCB_CHAIN_ID_LAST
							JE		MEM_CHECK_MCB_CHAIN_ID_OK
							STC
MEM_CHECK_MCB_CHAIN_ID_OK:	RET
MEM_CHECK_MCB_CHAIN_ID		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; Input
;   DS  MCB
;   BX  Requested number of pages
; Return
;   DS,BX     unchanged
;   ES,AX     Destroyed
; I'm not sure if it is ok to make an arena with zero block size.
; If I need to avoid zero block size, the current arena needs to be
; at least Requested+2 long because the left over will need
; MCB (1 block) + data area (1 block).
; Therefore, if the current arena is shorter than or equal to Requested+1,
; it doesn't split it.
; New arena always is assigned MCB_PID_SYSTEM
MEM_SPLIT_ARENA				PROC
							INC		BX		; BX=Requested+1
							CMP		BX,DS:[MCB_BLOCK_SIZE]
							JAE		MEM_SPLIT_ARENA_END		; If the size is less than or equal to Requested+2, don't split.

							; Current arena is at least Requested+2 pages.

							MOV		AX,DS
							ADD		AX,BX	; Now AX=MCB+1+Requested=Next MCB Segment
							MOV		ES,AX	; ES is new MCB.

							; Update CHAIN ID.
							; New MCB CHAIN ID is same as the old CHAIN ID.
							; Old MCB CHAIN ID always becomes NORMAL.
							MOV		AL,DS:[MCB_CHAIN_ID]
							MOV		ES:[MCB_CHAIN_ID],AL
							MOV		BYTE PTR DS:[MCB_CHAIN_ID],MCB_CHAIN_ID_NORMAL

							; PID of the new arena is always MCB_PID_SYSTEM
							MOV		WORD PTR ES:[MCB_PID],MCB_PID_SYSTEM

							; New Block Size=Current Block Size-(Requested+1)
							MOV		AX,DS:[MCB_BLOCK_SIZE]
							SUB		AX,BX
							MOV		ES:[MCB_BLOCK_SIZE],AX

							; Current Block Size=Requested=BX-1
							MOV		DS:[MCB_BLOCK_SIZE],BX
							DEC		WORD PTR DS:[MCB_BLOCK_SIZE]

MEM_SPLIT_ARENA_END:
							DEC		BX
							RET
MEM_SPLIT_ARENA				ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS  MCB
; Return
;   DS  Unchanged
;   AX  CurrentPDB
MEM_ASSIGN_CURRENT_PID		PROC
							MOV		AX,CS:[CurrentPDB]
							MOV		DS:[MCB_PID],AX
							RET
MEM_ASSIGN_CURRENT_PID		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS  MCB
; Output
;   ES,AX destroyed.
MEM_MERGE_ARENAS			PROC
							; while(this MCB is not last && Next MCB PID is same as this MCB PID)

MEM_MERGE_ARENAS_LOOP:
							CMP		BYTE PTR DS:[MCB_CHAIN_ID],MCB_CHAIN_ID_LAST
							JE		MEM_MERGE_ARENAS_END

							GET_NEXT_MCB	AX,DS
							MOV		ES,AX

							MOV		AX,DS:[MCB_PID]
							CMP		ES:[MCB_PID],AX
							JNE		MEM_MERGE_ARENAS_END

							; Add block size + 1 to the current MCB
							MOV		AX,ES:[MCB_BLOCK_SIZE]
							INC		AX
							ADD		DS:[MCB_BLOCK_SIZE],AX

							; Copy MCB_CHAIN_ID
							MOV		AL,ES:[MCB_CHAIN_ID]
							MOV		DS:[MCB_CHAIN_ID],AL

							JMP		MEM_MERGE_ARENAS_LOOP

MEM_MERGE_ARENAS_END:
							RET
MEM_MERGE_ARENAS			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Force merge the arena given by DS and the next arena.
; It doesn't touch the MCB_PID.
; Input
;   DS
; Output
;   ES,AX destroyed.
MEM_FORCE_MERGE				PROC
							GET_NEXT_MCB	AX,DS
							MOV		ES,AX
							MOV		AL,ES:[MCB_CHAIN_ID]
							MOV		DS:[MCB_CHAIN_ID],AL
							MOV		AX,ES:[MCB_BLOCK_SIZE]
							INC		AX
							ADD		DS:[MCB_BLOCK_SIZE],AX
							RET
MEM_FORCE_MERGE				ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Free memory.
; Input:
;   ES  Segment returned by MALLOC
; Output:
;   CF=0  Success
;   CF=1  Error  AX=DOSERR_INVALID_MCB(7)
MFREE						PROC
							PUSH	ES
							PUSH	DS
							PUSH	AX

							MOV		AX,ES
							DEC		AX			; AX=Incoming_ES-1
							MOV		DS,AX

							CALL	MEM_CHECK_MCB_CHAIN_ID
							JC		MFREE_INVALID_MCB

							MOV		WORD PTR DS:[MCB_PID],MCB_PID_SYSTEM
							CALL	MEM_MERGE_ARENAS

							POP		AX
							JMP		MFREE_RET

MFREE_INVALID_MCB:			POP		AX
							MOV		AX,DOSERR_INVALID_MCB

MFREE_RET:					POP		DS
							POP		ES
							RET

MFREE						ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;    BX=New size in number of paragraphs
;    ES=Segment (MCB+1) to resize
; Output
;    CF=0  Success  AX,BX unchanged.
;    CF=1  AX=error code  BX=maxinum number of paragraphs possible for resize
;          Error code can be one of:
;            DOSERR_MCB_BROKEN    (7)
;            DOSERR_OUT_OF_MEMORY (8)
;            DOSERR_INVALID_MCB   (9)
; Destroyed.
MREALLOC					PROC
							PUSH	ES
							PUSH	DS
							PUSH	AX

							MOV		AX,ES
							DEC		AX
							MOV		DS,AX	; DS is MCB
							MOV		ES,AX	; ES is MCB

							CMP		BX,DS:[MCB_BLOCK_SIZE]
							JE		MREALLOC_NOERROR	; No change in size

							MOV		AX,BX				; Cannot write LEA AX,[BX+1] in 16-bit address size :-P
							INC		AX					; AX is requested+1
							CMP		AX,DS:[MCB_BLOCK_SIZE]
							JE		MREALLOC_NOERROR	; No change
							JB		MREALLOC_SHRINK


							CALL	MEM_CHECK_MCB_CHAIN_ID
							JC		MREALLOC_INVALID_MCB

							CMP		BYTE PTR DS:[MCB_CHAIN_ID],MCB_CHAIN_ID_LAST
							JE		MREALLOC_NOTHING_AVAILABLE

							GET_NEXT_MCB	AX,DS
							MOV		DS,AX
							CMP		WORD PTR DS:[MCB_PID],MCB_PID_SYSTEM
							JNE		MREALLOC_NOTHING_AVAILABLE

							; ES=Old MCB
							; DS=Next MCB
							PUSH	ES
							CALL	MEM_MERGE_ARENAS
							POP		ES

							MOV		AX,DS:[MCB_BLOCK_SIZE]	; This MCB plus
							INC		AX						; Next MCB header plus
							ADD		AX,ES:[MCB_BLOCK_SIZE]	; Next MCB
							; AX is possible number of pages (Current+Next+1)
							; BX is still requested number of pages.

							CMP		AX,BX
							JB		MREALLOC_NOT_ENOUGH

							MOV		AX,ES
							MOV		DS,AX				; AX is this MCB.
							PUSH	BX
							CALL	MEM_FORCE_MERGE		; ES and AX destroyed, but doesn't matter.
							POP		BX

							CALL	MEM_SPLIT_ARENA

MREALLOC_NOERROR:
							POP		AX
							POP		DS
							POP		ES
							CLC
							RET

MREALLOC_INVALID_MCB:
							POP		AX
							MOV		AX,DOSERR_INVALID_MCB
							XOR		BX,BX
							POP		DS
							POP		ES
							; CF is already 1 from MEM_CHECK_MCB_CHAIN_ID
							RET

MREALLOC_NOTHING_AVAILABLE:
							POP		AX
							MOV		AX,DOSERR_OUT_OF_MEMORY
							XOR		BX,BX
							POP		DS
							POP		ES
							STC
							RET

MREALLOC_SHRINK:
							CALL	MEM_SPLIT_ARENA	; Supposed to succeed
							GET_NEXT_MCB	AX,DS
							MOV		DS,AX
							MOV		WORD PTR DS:[MCB_PID],MCB_PID_SYSTEM
							JMP		MREALLOC_NOERROR

MREALLOC_NOT_ENOUGH:
							XCHG	BX,AX
							POP		AX
							POP		DS
							POP		ES
							MOV		AX,DOSERR_OUT_OF_MEMORY
							STC
							RET

MREALLOC					ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX PSP
; Destroys
;   DS
MFREE_FOR_PSP:
							MOV		DS,CS:[FIRST_MCB]
MFREE_FOR_PSP_LOOP:
							CMP		AX,DS:[MCB_PID]
							JNE		MFREE_FOR_PSP_NEXT
							MOV		WORD PTR DS:[MCB_PID],MCB_PID_SYSTEM

MFREE_FOR_PSP_NEXT:
							CMP		BYTE PTR DS:[MCB_CHAIN_ID],MCB_CHAIN_ID_LAST
							JE		MFREE_FOR_PSP_BREAK

							GET_NEXT_MCB	BX,DS
							MOV		DS,BX
							JMP		MFREE_FOR_PSP_LOOP

MFREE_FOR_PSP_BREAK:
							RET
