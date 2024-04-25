
; Input
;   Stack
;   +00H     Flags:
;            b0  Add 0D 0A when ENTER key is pressed.
;            b1  Echo
;            b2  Overwrite or Insert (1 means overwrite)
;            Keep other bits zero.
;   +02H     Data Buffer Length
;   +04H     Data Buffer SEG:OFFSET
;   +08H     One-Char Input callback (AL must be the entered char code)  SEG:OFFSET
;   +0CH     (Will be history buffer.  Keep zero.)
; Output
;   CF     0: Normal  1: Error
;   AX     Number of bytes entered
;   Other registers won't be preserved.
LINE_INPUT:
							PUSH	BP
							MOV		BP,SP

							PUSH	CX
							PUSH	DS
							PUSH	DX
							PUSH	ES
							PUSH	BX
							PUSH	AX

							; [BP]     Prev BP
							; [BP+02H] Return IP
							; [BP+04H] Flags
							; [BP+06H] Data Buffer Length
							; [BP+08H] Data Buffer SEG
							; [BP+0AH] Data Buffer OFFSET
							; [BP+0CH] One-Char Input callback SEG
							; [BP+0EH] One-Char Input callback OFFSET
							; [BP+10H] History buffer SEG
							; [BP+12H] History buffer OFFSET
							; [BP+14H] Current Letter Count
							; [BP+16H] Current Cursor Position

							XOR		CX,CX
							PUSH	CX
							PUSH	CX

LINE_INPUT_LOOP:
							CALL	LINE_INPUT_ONE_STEP
							AND		AL,AL
							JE		LINE_INPUT_LOOP

							MOV		AX,[BP-]
							CLC
							MOV		SP,BP
							POP		BP
							RET


;Input

;Output
; AL   0:Continue Input   1:Buffer filled or Enter key is pressed
LINE_INPUT_ONE_STEP:
							CALLF	SS:[BP-]

							CMP		AL,' '
							JAE		LINE_INPUT_ONE_STEP_PRINTABLE
							CMP		AL,0DH  ; If ENTER key, return.
							JE		LINE_INPUT_ONE_STEP_ENTER_KEY
							CMP		AL,0AH  ; If ENTER key, return.
							JE		LINE_INPUT_ONE_STEP_BACKSPACE

							XOR		AL,AL
							RET
LINE_INPUT_ONE_STEP_OVER:
							MOV		AL,1
							RET

LINE_INPUT_ONE_STEP_PRINTABLE:


LINE_INPUT_ONE_STEP_ENTER_KEY:


LINE_INPUT_ONE_STEP_BACKSPACE:
