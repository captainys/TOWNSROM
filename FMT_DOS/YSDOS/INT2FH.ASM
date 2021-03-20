


INT_2FH_HANDLER:
						CMP		AX,1206H
						JE		INT_2FH_1206H

						PUSH	BP
						MOV		BP,SP
						; [BP] BP
						; [BP+2] IP
						; [BP+4] CS
						; [BP+6] FLAGS
						OR		WORD PTR [BP+6],1
						POP		BP
						MOV		AX,DOSERR_INVALID_FUNC
						IRET



; Since Towns OS V1.1 L20, it uses weird read-only RAM drive, Drive R.
; Drive R is located within the Sprite RAM, and keeps only one file,
; RUN386.EXE.  Obviously it is destroyed once an application uses sprite.
; CONTROL.EXE apparently makes it Drive Not Ready if the RAM drive is
; destroyed.
; So, here's what happens, unless (CS:[02F7h]&08h)!=0.
; (1) CONTROL.EXE hooks INT 21H AH=4B with Q:\RUN386.EXE and redirects
;     to R:\RUN386.EXE (Causes a recursive INT 21H AH=4BH)
; (2) Since R drive is controlled by MSCDEX, it shoots INT 2FH to
;     open the file.
; (3) If MENU_DRV driver sees the drive is destroyed, make it
;     Drive Not Ready.  I don't know what's going to happen if the
;     drive is partially corrupted.
; (4) MSCDEX shoots INT 2FH with AX=1206H
; (5) It is handled by MS-DOS's original INT 2FH handler.
;     Unless 0!=(CS:[02F7h]&08), it kills CONTROL.EXE.
; (6) REIPL.COM (Reboot) loop
; I don't know what CS:[02F7h] means.  It apparently defines the behavior
; of critical-error handling.
; But, I don't want to deal with what I don't understand.
; I don't want DOS to kill process just because of drive-not-ready.
; I just take over this function so that it simply returns AL=3 (Fail).
INT_2FH_1206H:
						MOV		AL,3 ; Fail
						IRET
