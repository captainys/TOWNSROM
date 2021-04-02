; SCSI Utility
; By CaptainYS



%MACRO					PREP_SCSI_CMD	1
						PUSH	SS
						POP		DS
						SUB		SP,12
						MOV		SI,SP
						MOV		EAX,CS:[%1]
						MOV		[SI],EAX
						MOV		EAX,CS:[%1+4]
						MOV		[SI+4],EAX
						MOV		EAX,CS:[%1+8]
						MOV		[SI+8],EAX
%ENDMACRO

%MACRO					UNPREP_SCSI_CMD	0
						PUSHF
						ADD		SP,12
						POPF
%ENDMACRO



%MACRO					PREP_SCSI_DATA	1
						SUB		SP,%1
%ENDMACRO

%MACRO					UNPREP_SCSI_DATA	1
						PUSHF
						ADD		SP,%1
						POPF
%ENDMACRO



; Input
;   CL   SCSI ID
; Output
;   CL   05 or 04 means CD
;        00 means HD
;   Carry  Set if error
IDENTIFY_SCSI_DEVICE:
						PUSH	BP
						PUSH	DS
						PREP_SCSI_CMD SCSI_INQURY_CMD
						PREP_SCSI_DATA	8	; SS:SP is the data buffer

						AND		CL,7
						MOV		BYTE [SI+1],0  ; Looks like Logical Unit ID needs to be zero.

						MOV		DI,SS
						MOVZX	EDI,DI
						SHL		EDI,4
						MOVZX	EAX,SP
						ADD		EDI,EAX

						CALL	SCSI_COMMAND

						MOV		DI,SP
						MOV		CL,SS:[DI]
						JAE		.noerror
						MOV		CL,0FFH
.noerror:
						UNPREP_SCSI_DATA	8
						UNPREP_SCSI_CMD
						POP		DS
						POP		BP
						RET


SCSI_INQURY_CMD			DB		12H,0,0,0,8,0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CL    SCSI ID
;   EDX   Starting Sector
;   BX    Number of Sectors
;   EDI   Data Buffer Physical Address
; Output
;   CF    Set if error
SCSI_READ_SECTOR:
						PUSH	DS
						PREP_SCSI_CMD	SCSI_READ_SECTOR_CMD

						AND		CL,7
						MOV		BYTE [SI+1],0 ; Looks like Logical Unit ID needs to be zero.

						MOV		[SI+4],DH
						MOV		[SI+5],DL
						ROR		EDX,16
						MOV		[SI+2],DH
						MOV		[SI+3],DL

						MOV		[SI+7],BH
						MOV		[SI+8],BL

						CALL	SCSI_COMMAND

						UNPREP_SCSI_CMD
						POP		DS
						RET


SCSI_READ_SECTOR_CMD	DB	28H,0,0,0,0,0,0,0,0,0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CL SCSI ID
; Output
;   AH      0 Unit is ready
;           Non Zero (Most likely 2) Unit is not ready
;   Not available from ROM
SCSI_TEST_UNIT_READY:
						PUSH	DS

						PUSH	CS
						POP		DS
						AND		CL,7
						MOV		SI,SCSI_TEST_UNIT_READY_CMD
						MOV		EDI,0
						MOV		DI,CS
						SHL		EDI,4
						ADD		EDI,SCSI_DATABUF
						; TEST_UNIT_READY is not supposed to return data.
						; But, just in case.
						; If it is pointing to ROM, that's ok.
						CALL	SCSI_COMMAND

						POP		DS
						RET



SCSI_TEST_UNIT_READY_CMD	DB		0,0,0,0,0,0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CL SCSI ID
; Not available from ROM
SCSI_SENSE:
						PUSH	DS

						PUSH	CS
						POP		DS
						AND		CL,7
						MOV		SI,SCSI_SENSE_CMD
						MOV		EDI,0
						MOV		DI,CS
						SHL		EDI,4
						ADD		EDI,SCSI_DATABUF
						CALL	SCSI_COMMAND
						POP		DS
						RET




SCSI_SENSE_CMD			DB	03H,0,0,0,18,0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



SCSI_DATABUF			DB		256 dup (0)
