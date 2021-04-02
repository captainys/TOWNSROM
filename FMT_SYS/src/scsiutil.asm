; SCSI Utility
; By CaptainYS


; Input
;   CL   SCSI ID
; Output
;   CL   05 or 04 means CD
;        00 means HD
;   Carry  Set if error
IDENTIFY_SCSI_DEVICE:
						PUSH	DS
						MOV		AX,CS
						MOV		DS,AX
						MOV		SI,SCSI_INQURY_CMD

						AND		CL,7
						MOV		BYTE [SI+1],0  ; Looks like Logical Unit ID needs to be zero.

						MOV		EDI,DS
						AND		EDI,0FFFFH
						SHL		EDI,4
						ADD		EDI,SCSI_DATABUF

						CALL	SCSI_COMMAND

						MOV		CL,[SCSI_DATABUF]
						JAE		.noerror
						MOV		CL,0FFH
.noerror:
						POP		DS
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
						PUSH	SS
						POP		DS
						SUB		SP,12
						MOV		SI,SP

						MOV		EAX,CS:[SCSI_READ_SECTOR_CMD]
						MOV		[SI],EAX
						MOV		EAX,CS:[SCSI_READ_SECTOR_CMD+4]
						MOV		[SI+4],EAX
						MOV		EAX,CS:[SCSI_READ_SECTOR_CMD+8]
						MOV		[SI+8],EAX

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

						ADD		SP,12
						RET


SCSI_READ_SECTOR_CMD	DB	28H,0,0,0,0,0,0,0,0,0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CL SCSI ID
; Output
;   AH      0 Unit is ready
;           Non Zero (Most likely 2) Unit is not ready
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
						CALL	SCSI_COMMAND

						POP		DS
						RET



SCSI_TEST_UNIT_READY_CMD	DB		0,0,0,0,0,0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CL SCSI ID
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
