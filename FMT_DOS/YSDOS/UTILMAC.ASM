; MASM gives SYMBOL NOT DEFINED error -> Unless MACRO is defined before used. (G** D*** It!)
; Wasn't MASM a two-pass assembler?
; Of course, MASM was giving a meaningless error to confuse me, but I figured.
; It works with MASM 5.10 as long as I include this UTILMAC.ASM before where it is used.



SET_IF_NO_CARRY			MACRO	REG,VALUE		;--NOT_IN_NASM--
						LOCAL	CARRYSET		;--NOT_IN_NASM--
						JC		CARRYSET		;--NOT_IN_NASM--
						MOV		REG,VALUE		;--NOT_IN_NASM--
CARRYSET:										;--NOT_IN_NASM--
						ENDM					;--NOT_IN_NASM--



;%MACRO					SET_IF_NO_CARRY		2	;--USE_IN_NASM--
;						JC		%%CARRYSET		;--USE_IN_NASM--
;						MOV		%1,%2			;--USE_IN_NASM--
;%%CARRYSET:									;--USE_IN_NASM--
;						%ENDMACRO				;--USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



MAKESMALLER_UNSIGNED	MACRO	REG,VALUE		;--NOT_IN_NASM--
						LOCAL	VALUESET		;--NOT_IN_NASM--
						CMP		REG,VALUE		;--NOT_IN_NASM--
						JBE		VALUESET		;--NOT_IN_NASM--
						MOV		REG,VALUE		;--NOT_IN_NASM--
VALUESET:										;--NOT_IN_NASM--
						ENDM					;--NOT_IN_NASM--



;%MACRO					MAKESMALLER_UNSIGNED	2	;--USE_IN_NASM--
;						CMP		%1,%2				;--USE_IN_NASM--
;						JBE		%%VALUESET			;--USE_IN_NASM--
;						MOV		%1,%2				;--USE_IN_NASM--
;%%VALUESET:										;--USE_IN_NASM--
;						%ENDMACRO					;--USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



MAKEGREATER_UNSIGNED	MACRO	REG,VALUE		;--NOT_IN_NASM--
						LOCAL	VALUESET		;--NOT_IN_NASM--
						CMP		REG,VALUE		;--NOT_IN_NASM--
						JAE		VALUESET		;--NOT_IN_NASM--
						MOV		REG,VALUE		;--NOT_IN_NASM--
VALUESET:										;--NOT_IN_NASM--
						ENDM					;--NOT_IN_NASM--



;%MACRO					MAKEGREATER_UNSIGNED	2	;--USE_IN_NASM--
;						CMP		%1,%2				;--USE_IN_NASM--
;						JAE		%%VALUESET			;--USE_IN_NASM--
;						MOV		%1,%2				;--USE_IN_NASM--
;%%VALUESET:										;--USE_IN_NASM--
;						%ENDMACRO					;--USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; If REG==FROM THEN REG=TO
REPLVALUE				MACRO	REG,FROM,TO			;--NOT_IN_NASM--
						LOCAL	NOCHANGE			;--NOT_IN_NASM--
						CMP		REG,FROM			;--NOT_IN_NASM--
						JNE		NOCHANGE			;--NOT_IN_NASM--
						MOV		REG,TO				;--NOT_IN_NASM--
NOCHANGE:											;--NOT_IN_NASM--
						ENDM						;--NOT_IN_NASM--



;%MACRO					REPLVALUE	3				;--USE_IN_NASM--
;						CMP		%1,%2				;--USE_IN_NASM--
;						JNE		%%NOCHANGE			;--USE_IN_NASM--
;						MOV		%1,%3				;--USE_IN_NASM--
;%%NOCHANGE:										;--USE_IN_NASM--
;						%ENDMACRO					;--USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Linear address 32-bit to Hiword=SEG, Lower=OFFSET
LINEAR2SEGOFF_EAX		MACRO
						SHL		EAX,12
						ROL		AX,4
						ENDM

LINEAR2SEGOFF_EBX		MACRO
						SHL		EBX,12
						ROL		BX,4
						ENDM

LINEAR2SEGOFF_ECX		MACRO
						SHL		ECX,12
						ROL		CX,4
						ENDM

LINEAR2SEGOFF_EDX		MACRO
						SHL		EDX,12
						ROL		DX,4
						ENDM

LINEAR2SEGOFF_ESI		MACRO
						SHL		ESI,12
						ROL		SI,4
						ENDM

LINEAR2SEGOFF_EDI		MACRO
						SHL		EDI,12
						ROL		DI,4
						ENDM

LINEAR2SEGOFF_EBP		MACRO
						SHL		EBP,12
						ROL		BP,4
						ENDM



; Hiword=SEG, Loword=OFFSET to Linear
SEGOFF2LINEAR_EAX		MACRO
						PUSH	EBX
						MOVZX	EBX,AX
						SHR		EAX,16
						SHL		EAX,4
						ADD		EAX,EBX
						POP		EBX
						ENDM

SEGOFF2LINEAR_EBX		MACRO
						PUSH	EAX
						MOVZX	EAX,BX
						SHR		EBX,16
						SHL		EBX,4
						ADD		EBX,EAX
						POP		EAX
						ENDM

SEGOFF2LINEAR_ECX		MACRO
						PUSH	EAX
						MOVZX	EAX,CX
						SHR		ECX,16
						SHL		ECX,4
						ADD		ECX,EAX
						POP		EAX
						ENDM

SEGOFF2LINEAR_EDX		MACRO
						PUSH	EAX
						MOVZX	EAX,DX
						SHR		EDX,16
						SHL		EDX,4
						ADD		EDX,EAX
						POP		EAX
						ENDM

SEGOFF2LINEAR_ESI		MACRO
						PUSH	EAX
						MOVZX	EAX,SI
						SHR		ESI,16
						SHL		ESI,4
						ADD		ESI,EAX
						POP		EAX
						ENDM

SEGOFF2LINEAR_EDI		MACRO
						PUSH	EAX
						MOVZX	EAX,DI
						SHR		EDI,16
						SHL		EDI,4
						ADD		EDI,EAX
						POP		EAX
						ENDM

SEGOFF2LINEAR_EBP		MACRO
						PUSH	EAX
						MOVZX	EAX,BP
						SHR		EBP,16
						SHL		EBP,4
						ADD		EBP,EAX
						POP		EAX
						ENDM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



XCHGSTACK				MACRO	REG1,REG2		;--NOT_IN_NASM--
						PUSH	REG1			;--NOT_IN_NASM--
						PUSH	REG2			;--NOT_IN_NASM--
						POP		REG1			;--NOT_IN_NASM--
						POP		REG2			;--NOT_IN_NASM--
						ENDM					;--NOT_IN_NASM--

;%MACRO					XCHGSTACK	2			;--USE_IN_NASM--
;						PUSH	%1				;--USE_IN_NASM--
;						PUSH	%2				;--USE_IN_NASM--
;						POP		%1				;--USE_IN_NASM--
;						POP		%2				;--USE_IN_NASM--
;						%ENDMACRO				;--USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



PUSH_ALL_HIWORD			MACRO
						ROR		EAX,16
						ROR		EBX,16
						ROR		ECX,16
						ROR		EDX,16
						ROR		ESI,16
						ROR		EDI,16
						ROR		EBP,16
						PUSHA
						ROR		EAX,16
						ROR		EBX,16
						ROR		ECX,16
						ROR		EDX,16
						ROR		ESI,16
						ROR		EDI,16
						ROR		EBP,16
						ENDM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



POP_ALL_HIWORD			MACRO
						ROR		EAX,16
						ROR		EBX,16
						ROR		ECX,16
						ROR		EDX,16
						ROR		ESI,16
						ROR		EDI,16
						ROR		EBP,16
						POPA
						ROR		EAX,16
						ROR		EBX,16
						ROR		ECX,16
						ROR		EDX,16
						ROR		ESI,16
						ROR		EDI,16
						ROR		EBP,16
						ENDM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



XCHG_DSSI_ESDI			MACRO
						PUSH	DS
						PUSh	ES
						POP		DS
						POP		ES
						PUSH	SI
						PUSH	DI
						POP		SI
						POP		DI
						ENDM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



JMP_IF_KANJI			MACRO	REG,IS_KANJI	; --NOT_IN_NASM--
						LOCAL	NOT_KANJI	; --NOT_IN_NASM--
						CMP		REG,081h	; --NOT_IN_NASM--
						JB		NOT_KANJI	; --NOT_IN_NASM--
						CMP		REG,0A0h	; --NOT_IN_NASM--
						JB		IS_KANJI	; --NOT_IN_NASM--
						CMP		REG,0E0h	; --NOT_IN_NASM--
						JB		NOT_KANJI	; --NOT_IN_NASM--
						CMP		REG,0FCh	; --NOT_IN_NASM--
						JBE		IS_KANJI	; --NOT_IN_NASM--
NOT_KANJI:									; --NOT_IN_NASM--
						ENDM				; --NOT_IN_NASM--

;%MACRO					JMP_IF_KANJI	2	; --USE_IN_NASM--
;						CMP		%1,081h		; --USE_IN_NASM--
;						JB		%%NOT_KANJI	; --USE_IN_NASM--
;						CMP		%1,0A0h		; --USE_IN_NASM--
;						JB		%2			; --USE_IN_NASM--
;						CMP		%1,0E0h		; --USE_IN_NASM--
;						JB		%%NOT_KANJI	; --USE_IN_NASM--
;						CMP		%1,0FCh		; --USE_IN_NASM--
;						JBE		%2			; --USE_IN_NASM--
;%%NOT_KANJI:								; --USE_IN_NASM--
;%ENDMACRO									; --USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



JMP_IF_NOT_KANJI		MACRO	REG,NOT_KANJI	; --NOT_IN_NASM--
						LOCAL	IS_KANJI	; --NOT_IN_NASM--
						CMP		REG,081h	; --NOT_IN_NASM--
						JB		NOT_KANJI	; --NOT_IN_NASM--
						CMP		REG,0A0h	; --NOT_IN_NASM--
						JB		IS_KANJI	; --NOT_IN_NASM--
						CMP		REG,0E0h	; --NOT_IN_NASM--
						JB		NOT_KANJI	; --NOT_IN_NASM--
						CMP		REG,0FCh	; --NOT_IN_NASM--
						JA		NOTKANJI	; --NOT_IN_NASM--
IS_KANJI:									; --NOT_IN_NASM--
						ENDM				; --NOT_IN_NASM--


;%MACRO					JMP_IF_NOT_KANJI	2	; --USE_IN_NASM--
;						CMP		%1,081h			; --USE_IN_NASM--
;						JB		%2				; --USE_IN_NASM--
;						CMP		%1,0A0h			; --USE_IN_NASM--
;						JB		%%IS_KANJI		; --USE_IN_NASM--
;						CMP		%1,0E0h			; --USE_IN_NASM--
;						JB		%2				; --USE_IN_NASM--
;						CMP		%1,0FCh			; --USE_IN_NASM--
;						JA		%2				; --USE_IN_NASM--
;%%IS_KANJI:									; --USE_IN_NASM--
;%ENDMACRO										; --USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



JMP_IF_SLASH			MACRO	REG,DESTIN	; --NOT_IN_NASM--
						CMP		REG,'/'		; --NOT_IN_NASM--
						JE		DESTIN		; --NOT_IN_NASM--
						CMP		REG,'\'		; --NOT_IN_NASM--
						JE		DESTIN		; --NOT_IN_NASM--
						ENDM				; --NOT_IN_NASM--

;%MACRO					JMP_IF_SLASH	2	; --USE_IN_NASM--
;						CMP		%1,'/'		; --USE_IN_NASM--
;						JE		%2			; --USE_IN_NASM--
;						CMP		%1,'\'		; --USE_IN_NASM--
;						JE		%2			; --USE_IN_NASM--
;%ENDMACRO									; --USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



JMP_IF_NOT_SLASH		MACRO	REG,DESTIN	; --NOT_IN_NASM--
						LOCAL	BAILOUT		; --NOT_IN_NASM--
						CMP		REG,'/'		; --NOT_IN_NASM--
						JE		BAILOUT		; --NOT_IN_NASM--
						CMP		REG,'\'		; --NOT_IN_NASM--
						JNE		DESTIN		; --NOT_IN_NASM--
BAILOUT:									; --NOT_IN_NASM--
						ENDM				; --NOT_IN_NASM--

;%MACRO					JMP_IF_NOT_SLASH	2	; --USE_IN_NASM--
;						CMP		%1,'/'			; --USE_IN_NASM--
;						JE		%%BAILOUT		; --USE_IN_NASM--
;						CMP		%1,'\'			; --USE_IN_NASM--
;						JNE		%2				; --USE_IN_NASM--
;%%BAILOUT:										; --USE_IN_NASM--
;%ENDMACRO										; --USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



CAPITALIZE				MACRO	REG				;--NOT_IN_NASM--
						LOCAL	CAPSDONE		;--NOT_IN_NASM--
						CMP		REG,'a'			;--NOT_IN_NASM--
						JB		CAPSDONE		;--NOT_IN_NASM--
						CMP		REG,'z'			;--NOT_IN_NASM--
						JA		CAPSDONE		;--NOT_IN_NASM--
						SUB		REG,'a'-'A'		;--NOT_IN_NASM--
CAPSDONE:										;--NOT_IN_NASM--
						ENDM					;--NOT_IN_NASM--



;%MACRO					CAPITALIZE	1			;--USE_IN_NASM--
;						CMP		%1,'a'			;--USE_IN_NASM--
;						JB		%%CAPSDONE		;--USE_IN_NASM--
;						CMP		%1,'z'			;--USE_IN_NASM--
;						JA		%%CAPSDONE		;--USE_IN_NASM--
;						SUB		%1,'a'-'A'		;--USE_IN_NASM--
;%%CAPSDONE:									;--USE_IN_NASM--
;						%ENDMACRO				;--USE_IN_NASM--



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; ****ing DWORD PTR requirement and non-requirement of MASM and NASM
_LDS					MACRO	REG,ADDR			;--NOT_IN_NASM--
						LDS		REG,DWORD PTR ADDR	;--NOT_IN_NASM--
						ENDM						;--NOT_IN_NASM--

;%MACRO					_LDS	2				;--USE_IN_NASM--
;						LDS		%1,%2			;--USE_IN_NASM--
;						%ENDMACRO				;--USE_IN_NASM--

_LES					MACRO	REG,ADDR			;--NOT_IN_NASM--
						LES		REG,DWORD PTR ADDR	;--NOT_IN_NASM--
						ENDM						;--NOT_IN_NASM--

;%MACRO					_LES	2				;--USE_IN_NASM--
;						LES		%1,%2			;--USE_IN_NASM--
;						%ENDMACRO				;--USE_IN_NASM--

_LFS					MACRO	REG,ADDR			;--NOT_IN_NASM--
						LFS		REG,DWORD PTR ADDR	;--NOT_IN_NASM--
						ENDM						;--NOT_IN_NASM--

;%MACRO					_LFS	2				;--USE_IN_NASM--
;						LFS		%1,%2			;--USE_IN_NASM--
;						%ENDMACRO				;--USE_IN_NASM--

_LGS					MACRO	REG,ADDR			;--NOT_IN_NASM--
						LGS		REG,DWORD PTR ADDR	;--NOT_IN_NASM--
						ENDM						;--NOT_IN_NASM--

;%MACRO					_LGS	2				;--USE_IN_NASM--
;						LGS		%1,%2			;--USE_IN_NASM--
;						%ENDMACRO				;--USE_IN_NASM--

_LSS					MACRO	REG,ADDR			;--NOT_IN_NASM--
						LSS		REG,DWORD PTR ADDR	;--NOT_IN_NASM--
						ENDM						;--NOT_IN_NASM--

;%MACRO					_LSS	2				;--USE_IN_NASM--
;						LSS		%1,%2			;--USE_IN_NASM--
;						%ENDMACRO				;--USE_IN_NASM--

