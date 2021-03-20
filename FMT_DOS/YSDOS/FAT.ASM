DPB_STC_IF_FAT12		MACRO	DPBSEG,DPBOFFSET		; --NOT_IN_NASM--
						CMP		WORD PTR DPBSEG:[DPBOFFSET.DPB_MAX_CLUSTER_NUM],0FF6h	; --NOT_IN_NASM--
						ENDM	; --NOT_IN_NASM--

;%MACRO					DPB_STC_IF_FAT12	2							; --USE_IN_NASM--
;						CMP		WORD %1:[%2+DPB_MAX_CLUSTER_NUM],0FF6h	; --USE_IN_NASM--
;						%ENDMACRO										; --USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input:
;   GS:BP  DPB
; Output:
;   ZF, CF, OF may change from CMP.
; Decrement available cluster count if it is not 0ffffh
DEC_AVAIL_CLUSTER_COUNT:
						CMP		WORD PTR GS:[BP+DPB_NUM_FREE_CLUSTERS],0ffffh
						JE		DEC_AVAIL_CLUSTER_COUNT_RET
						DEC		WORD PTR GS:[BP+DPB_NUM_FREE_CLUSTERS]
DEC_AVAIL_CLUSTER_COUNT_RET:
						RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input:
;   GS:BP  DPB
;   ZF, CF, OF may change from CMP.
; Increment available cluster count if it is not 0ffffh
INC_AVAIL_CLUSTER_COUNT:
						CMP		WORD PTR GS:[BP+DPB_NUM_FREE_CLUSTERS],0ffffh
						JE		INC_AVAIL_CLUSTER_COUNT_RET
						INC		WORD PTR GS:[BP+DPB_NUM_FREE_CLUSTERS]
INC_AVAIL_CLUSTER_COUNT_RET:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  Drive Parameter Block
;   BX     Cluster
; Output
;   CF=0   DX=Next Cluster
;   CF=1   DX Destroyed
; EBX, Hiword of EDX Preserved
; DS,EDI  Destroyed
; EAX,ECX Destroyed
GET_NEXT_CLUSTER		PROC
						PUSH	EBX
						PUSHHI_EDX

						CMP		BX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JA		GET_NEXT_CLUSTER_ERROR

						; Need:
						;   Bytes into FAT (BX*2 for FAT16, BX*3/2 for FAT12)
						;   Then, sectors into fat, bytes into sector.

						MOVZX	EBX,BX
						MOV		EAX,EBX
						ADD		EAX,EBX
						DPB_STC_IF_FAT12	GS,BP
						JNC		GET_NEXT_CLUST_EAX_IS_BYTES

						ADD		EAX,EBX
						SHR		EAX,1

GET_NEXT_CLUST_EAX_IS_BYTES:
						CDQ
						MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						DIV		ECX
						ADD		AX,GS:[BP+DPB_FIRST_FAT_SECTOR]

						MOV		BX,DX	; BX is bytes into sector
						MOV		DX,AX	; DX is FAT sector (LBA)

						; Need to fetch two bytes
						; AX is a value fetching.
						MOV		CX,2
GET_NEXT_CLUSTER_LOOP:
						PUSH	DX
						PUSH	CX		; Probably CX is safe
						PUSH	BX		; Probably BX is safe
						PUSH	AX

						XOR		AL,AL

						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						;          AL!=0 Don't read sector (Just make an available buffer)
						; Output
						;   DS:DI  Buffer
						;   AX     Destroyed
						;   Hiword EDI  Destroyed 
						CALL	GETBUFFER_FAT

						POP		AX
						POP		BX
						POP		CX
						POP		DX
						JC		GET_NEXT_CLUSTER_ERROR

						LEA		DI,[DI+IO_BUF_INFO_size+BX]
						MOV		AL,AH
						MOV		AH,DS:[DI]

						DEC		CL
						JE		GET_NEXT_CLUSTER_HAVE_TWO_BYTES

						INC		DX	; Tentatively next sector
						INC		BX	; Tentatively next byte
						SUB		BX,GS:[BP+DPB_BYTES_PER_SECTOR]
						JAE		GET_NEXT_CLUSTER_LOOP ; Jump if it crossed the sector boundary?

						MOV		AL,AH
						MOV		AH,DS:[DI+1]

GET_NEXT_CLUSTER_HAVE_TWO_BYTES:
						MOV		DX,AX

						; DX is next cluster

						POPHI_EDX
						POP		EBX

						DPB_STC_IF_FAT12	GS,BP
						JNC		GET_NEXT_CLUSTER_DONE
						TEST	BX,1
						JE		GET_NEXT_CLUSTER_FAT12_DONE
						SHR		DX,4
GET_NEXT_CLUSTER_FAT12_DONE:
						AND		DX,0FFFh

GET_NEXT_CLUSTER_DONE:
						CLC
						RET

GET_NEXT_CLUSTER_ERROR:
						POPHI_EDX
						POP		EBX
						STC
						RET

GET_NEXT_CLUSTER		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  GS:BP  DPB
;  BX     Cluster
;  DX     Value to write
;Output
;  CF=0 Success (Buffer is dirty)  AX=Previous Cluster Value (Next Cluster)
;  CF=1 Fail.
; EAX,EDI,ECX Destroyed
;   Hiword EDI  Destroyed from GETBUFFER_FAT
WRITE_CLUSTER:
						PUSH	EBX
						PUSH	EDX
						PUSH	0	; To save previous Cluster Value

						CMP		BX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JA		WRITE_CLUSTER_ERROR

						; Need:
						;   Bytes into FAT (BX*2 for FAT16, BX*3/2 for FAT12)
						;   Then, sectors into fat, bytes into sector.

						MOVZX	EBX,BX
						MOV		EAX,EBX
						ADD		EAX,EBX
						AND		EDX,0ffffh ; Hiword of EDX is AND pattern for FAT16 tentatively.
						DPB_STC_IF_FAT12	GS,BP
						JNC		WRITE_CLUSTER_EAX_IS_BYTES

						; Is FAT12
						AND		DX,00fffh
						MOV		CX,0f000h	; AND Pattern
						TEST	EBX,1
						JE		WRITE_CLUSTER_CX_IS_AND_PTN
						ROL		CX,4
						SHL		DX,4
WRITE_CLUSTER_CX_IS_AND_PTN:
						SHL		ECX,16
						OR		EDX,ECX ; Hiword of EDX is AND pattern
						ADD		EAX,EBX
						SHR		EAX,1

WRITE_CLUSTER_EAX_IS_BYTES:
						PUSH	EDX	; Save value to write, AND pattern

						CDQ
						MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						DIV		ECX
						ADD		AX,GS:[BP+DPB_FIRST_FAT_SECTOR]

						MOV		BX,DX	; BX is bytes into sector
						MOV		DX,AX	; DX is FAT sector (LBA)

						POP		EAX	; Restore value to write and AND pattern in EAX

						; Need to fetch two bytes
						MOV		CX,2
WRITE_CLUSTER_LOOP:
						PUSH	DX
						PUSH	CX		; Probably CX is safe
						PUSH	BX		; Probably BX is safe
						PUSH	EAX

						XOR		AL,AL

						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						;          AL!=0 Don't read sector (Just make an available buffer)
						; Output
						;   DS:DI  Buffer
						;   AX     Destroyed
						;   Hiword EDI  Destroyed 
						CALL	GETBUFFER_FAT
						OR		BYTE PTR DS:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_DIRTY

						POP		EAX
						POP		BX
						POP		CX
						POP		DX
						JC		WRITE_CLUSTER_ERROR

						LEA		DI,[DI+IO_BUF_INFO_size+BX]

						SHL		ECX,16	; Save CX in Hiword
						POP		CX
						MOV		CL,CH
						MOV		CH,BYTE PTR DS:[DI]
						PUSH	CX
						SHR		ECX,16 ; Restore CX from Hiword

						; Hiword EAX is AND pattern, Loword EAX is OR pattern.
						ROR		EAX,16
						AND		BYTE PTR DS:[DI],AL
						ROR		EAX,16
						OR		BYTE PTR DS:[DI],AL
						SHR		EAX,8	; Done with one byte.

						DEC		CL
						JE		WRITE_CLUSTER_HAVE_TWO_BYTES

						INC		DX	; Tentatively next sector
						INC		BX	; Tentatively next byte
						SUB		BX,GS:[BP+DPB_BYTES_PER_SECTOR]
						JAE		WRITE_CLUSTER_LOOP ; Jump if it crossed the sector boundary?

						POP		CX
						MOV		CL,CH
						MOV		CH,DS:[DI+1]
						PUSH	CX

						ROR		EAX,16
						AND		BYTE PTR DS:[DI+1],AL
						ROR		EAX,16
						OR		BYTE PTR DS:[DI+1],AL
						SHR		EAX,8

WRITE_CLUSTER_HAVE_TWO_BYTES:
						POP		AX
						POP		EDX
						POP		EBX

						DPB_STC_IF_FAT12	GS,BP
						JNC		WRITE_CLUSTER_DONE
						MOV		CL,BL
						AND		CL,1
						SHL		CL,2	; If 0!=(BX&1) THEN Shift 4 bits.
						SHR		AX,CL
						AND		AX,0FFFh
WRITE_CLUSTER_DONE:
						CLC
						RET

WRITE_CLUSTER_ERROR:
						POP		CX	; Dummy Pop
						POP		EDX
						POP		EBX
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  GS:BP  DPB
;  BX     Cluster
;Output
;  CF=0 Success (Buffer is dirty)
;  CF=1 Fail.
; BX,DX Destroyed
; EAX,EDI,ECX, Hiword EDI  Destroyed from WRITE_CLUSTER
FREE_CLUSTER_CHAIN:

FREE_CLUSTER_CHAIN_LOOP:
						OR		BX,BX
						JE		FREE_CLUSTER_CHAIN_EXIT
						CMP		BX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JA		FREE_CLUSTER_CHAIN_EXIT
						XOR		DX,DX
						CALL	WRITE_CLUSTER
						JC		FREE_CLUSTER_CHAIN_ERROR
						MOV		BX,AX
						JMP		FREE_CLUSTER_CHAIN_LOOP

FREE_CLUSTER_CHAIN_EXIT:
						CLC
						RET
; I think FAT is corrupt if it comes here.  Rest In Peace...
FREE_CLUSTER_CHAIN_ERROR:
						STC
						RET




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  Drive Parameter Block
; Output
;   DX     Tail Cluster Threshold (0FF8H or 0FFF8h)
GET_TAIL_CLUSTER_THRESHOLD	PROC
						DPB_STC_IF_FAT12	GS,BP
						JC		GET_TAIL_CLUSTER_FAT12
						MOV		DX,0FFF8h
						RET

GET_TAIL_CLUSTER_FAT12:
						MOV		DX,0FF8h
						RET
GET_TAIL_CLUSTER_THRESHOLD	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  Drive Parameter Block
;   DX     Cluster
; Return
;   EBX    First Sector of the cluster
;   EAX,CL Destroyed
CLUSTER_TO_SECTOR		PROC
						DEC		DX
						DEC		DX
						MOVZX	EBX,DX
						MOV		CL,GS:[BP+DPB_CLUSTER_SHIFT]
						SHL		EBX,CL ; EBX is sectors from the first data sector
						MOVZX	EAX,WORD PTR GS:[BP+DPB_FIRST_DATA_SECTOR]
						ADD		EBX,EAX
						RET
CLUSTER_TO_SECTOR		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DX     Cluster to start search
;   GS:BP  DPB
; Output
;   CF=0   EDX=Free cluster
;   CF=1   EDX Destroyed
; EBX Destroyed
; DS,EDI  Destroyed from GET_NEXT_CLUSTER
; EAX,ECX Destroyed from GET_NEXT_CLUSTER
FIND_FREE_CLUSTER:
						MOV		BX,DX
						CALL	GET_NEXT_CLUSTER  ; This preserves BX
						JC		FIND_FREE_CLUSTER_NEXT
						OR		DX,DX
						MOV		DX,BX
						JE		FIND_FREE_CLUSTER_FOUND

FIND_FREE_CLUSTER_NEXT:
						INC		DX
						CMP		DX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JBE		FIND_FREE_CLUSTER

						STC
						RET

FIND_FREE_CLUSTER_FOUND:
						CLC
						RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  Driver Parameter Block
;   ECX    Clusters needed
; Output
;   CF=0   EBX First of the cluster chain, or tail-cluster ID if ECX=0
;   CF=1   EBX 0:No clusters available.  1:Allocated clusters, but not enough.
; Destroyed
;   DX      Destroyed
;   DS      Destroyed from GET_NEXT_CLUSTER from FIND_FREE_CLUSTER
;   EAX,ECX Destroyed from GET_NEXT_CLUSTER from FIND_FREE_CLUSTER
ALLOCATE_CLUSTER_CHAIN:
						PUSH	EDI

						CALL	GET_TAIL_CLUSTER_THRESHOLD
						MOVZX	EBX,DX ; EBX is tail-cluster ID (tentative)
						CLC		; If ECX=0, just succeed.
						JECXZ	ALLOCATE_CLUSTER_CHAIN_END

						XOR		DX,DX
						PUSH	CX
						CALL	FIND_FREE_CLUSTER
						POP		CX
						XOR		EBX,EBX ; Tentative
						JC		ALLOCATE_CLUSTER_CHAIN_END

						MOVZX	EBX,DX
						PUSH	EBX	; Remember first of the chain
						; Hope I can support bigger FAT, so keep hiword zero.

						; For the rest, I have only 16-bit for the time being. Just BX.
						PUSH	BX
						CALL	GET_TAIL_CLUSTER_THRESHOLD
						; BX Write destination cluster
						; DX Value to write
						PUSH	CX
						CALL	WRITE_CLUSTER	; Tentatively terminate the chain
						POP		CX
						POP		BX

						CALL	DEC_AVAIL_CLUSTER_COUNT

						; EBX is the last cluster
						CLC
						DEC		CX		; I made one.  I need to subtract CX by one.
						JE		ALLOCATE_CLUSTER_CHAIN_BREAK

ALLOCATE_CLUSTER_CHAIN_LOOP:
						; Find a free cluster
						PUSH	CX

						PUSH	BX
						MOV		DX,BX
						CALL	FIND_FREE_CLUSTER
						POP		BX

						POP		CX	; Keep Stack Consistent
						JC		ALLOCATE_CLUSTER_CHAIN_BREAK
						PUSH	CX	; Keep Stack Consistent

						; BX is the previous cluster.
						; DX is a new available cluster.

						PUSH	DX
						; BX Write destination cluster
						; DX Value to write
						CALL	WRITE_CLUSTER	; Connect new cluster to previous.
						POP		BX   ; BX=New Cluster

						PUSH	BX
						CALL	GET_TAIL_CLUSTER_THRESHOLD ; DX=0FF8h of 0FFF8h
						CALL	WRITE_CLUSTER
						CALL	DEC_AVAIL_CLUSTER_COUNT
						POP		BX

						; Write new free cluster to the previous cluster
						POP		CX
						LOOP	ALLOCATE_CLUSTER_CHAIN_LOOP

						; Write tail-cluster ID

ALLOCATE_CLUSTER_CHAIN_BREAK:
						POP		EBX
						CLC


ALLOCATE_CLUSTER_CHAIN_END:
						POP		EDI
						RET
