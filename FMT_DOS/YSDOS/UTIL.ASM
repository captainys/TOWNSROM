;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  Source
;   ES:DI  Destination
;   CX     Bytes
; CX Zero
; DF Clear
UTIL_REP_MOVS			PROC
						CLD
						REP		MOVSB		; Let's start conservatively.
;						SHR		CX,1
;						; If CF==0(Above) and ZF==1(Equal), nothing to transfer.
;						JAE		UTIL_REP_MOVS_END
;
;						PUSHF
;						SHR		CX,1
;						REP		MOVSD
;						RCL		CX,1
;						REP		MOVSW
;						POPF
;						RCL		CX,1
;						REP		MOVSB
;UTIL_REP_MOVS_END:
						RET
UTIL_REP_MOVS			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS=ENVSEG
; Output
;   WORD PTR DS:[SI]=0
ENVLEN:
						XOR		SI,SI
ENVLEN_LOOP:			CMP		WORD PTR [SI],0
						JE		ENVLEN_FOUND
						INC		SI
						JMP		ENVLEN_LOOP
ENVLEN_FOUND:			RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  DS=Source ENVSEG
;  ES=Destination ENVSEG
;Output
;  SI=DI points to the last 00 00.
ENVCPY:
						XOR		SI,SI
						XOR		DI,DI
ENVCPY_LOOP:
						CMP		WORD PTR DS:[SI],0
						JE		ENVCPY_EXIT
						MOVSB
						JMP		ENVCPY_LOOP
ENVCPY_EXIT:
						MOV		WORD PTR ES:[DI],0
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:DI=String
; Output
;   CX=String length (DS:[SI+CX]=0)
;   AL=0
; Other registers preserved.
STRLEN_ESDI:
						PUSH	DI
						XOR		AL,AL
						MOV		CX,0ffffh
						REPNE SCASB
						POP		CX
						XCHG	DI,CX
						SUB		CX,DI
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




JANUARY					DB		31
FEBRUARY				DB		28
MARCH					DB		31
APRIL					DB		30
MAY						DB		31
JUNE					DB		30
JULY					DB		31
AUGUST					DB		31
SEPTEMBER				DB		30
OCTOBER					DB		31
NOVEMBER				DB		30
DECEMBER				DB		31

; Input
;   AX=Days since January 1 1980
; Return
;   BX=Years since 1980
;   CH=Month
;   CL=Date
;   DL=Day of week (0=Sun)
; Preserves SI,DI,BP
; Destroys AX, DH
; Anyway 16-bit does not represent year 2400, I don't care year%400==0 rule.
DAYS_SINCE_1980_TO_YEAR_MONTH_DATE_DAY:
						PUSH	AX

						XOR		DX,DX
						MOV		CX,365*4+1
						DIV		CX

						; AX is four-years.
						; DX is days into the four-year window.

						SHL		AX,2
						; AX is in years scale.

						CMP		DX,366;
						JAE		DAYS_SINCE_NOT_LEAP
;DAYS_SINCE_LEAP_YEAR:
						MOV		BYTE PTR CS:[FEBRUARY],29
						JMP		DAYS_SINCE_FEB_DAYS_SET
DAYS_SINCE_NOT_LEAP:
						MOV		BYTE PTR CS:[FEBRUARY],28

						MOV		BX,AX	; BX is base year (integer times four years since 1980)

						MOV		AX,DX
						DEC		AX
						XOR		DX,DX	; DX|AX is days into four-year window minus 1.
						MOV		CX,365
						DIV		CX
						ADD		AX,BX

DAYS_SINCE_FEB_DAYS_SET:
						; AX is years since 1980
						; CS:[FEBRUARY] is days in February
						; DX is days into year.

						PUSH	AX	; Years since 1980 in stack

						MOV		BX,OFFSET JANUARY
DAYS_SINCE_MONTH_COUNT_LOOP:
						MOVZX	AX,BYTE PTR CS:[BX]
						CMP		DX,AX
						JB		DAYS_SINCE_MONTH_COUNT_BREAK
						SUB		DX,AX
						INC		BX
						CMP		BX,OFFSET DECEMBER
						JB		DAYS_SINCE_MONTH_COUNT_LOOP

DAYS_SINCE_MONTH_COUNT_BREAK:
						INC		DX	; DX of day of month (First day is 1)
						SUB		BX,OFFSET JANUARY-1	; BX is month (January is 1)

						; AX is years since 1980
						; BX is month
						; DX is day of month

						MOV		CH,BL
						MOV		CL,DL
						;   CH=Month
						;   CL=Date

						POP		BX	; Years since 1980 in BX

						POP		AX	; Get dates since into AX
						PUSH	BX	; Save years since 1980

						XOR		DX,DX
						MOV		BX,7
						DIV		BX

						; January 1st 1980 was Tuesday  0:Sun 1:Mon 2:Tue
						ADD		DL,2
						; DL is day of week.
						POP		BX

						RET
