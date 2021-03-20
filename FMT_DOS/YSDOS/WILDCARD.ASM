;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  DS:SI  File Name (8-byte name plus 3-byte ext)
;  ES:DI  File Name that may have wildcard (8-byte name plus 3-byte ext).
;Ouptut
;  ZF=1  If match
;  ZF=0  If not match
;  DF=0
;  CX destroyed.
COMPARE_FILENAME_EXACT:
						PUSH	SI
						PUSH	DI

						CLD
						MOV		CX,2
						REPE	CMPSD
						JNE		COMPARE_FILENAME_EXACT_EXIT
						MOV		CX,3
						REPE	CMPSB

COMPARE_FILENAME_EXACT_EXIT:
						POP		DI
						POP		SI
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  Filename in DIRENT
;   ES:DI  Wildcard
; Output
;   E Match  NE Not match
;   CX Destroyed
; If DS:[SI]==0 or 0E5h(Deleted), it will return NE.
COMPARE_LESSER_WILDCARD11:
						PUSH	SI
						PUSH	DI

						CMP		BYTE PTR DS:[SI],0
						JE		COMPARE_LESSWC11_DELETED
						CMP		BYTE PTR DS:[SI],DELETED_FILE_FIRST_BYTE
						JE		COMPARE_LESSWC11_DELETED

						MOV		CX,11

COMPARE_LESSWC11_INNER_LOOP:
						CMP		BYTE PTR ES:[DI],'?'
						JE		COMPARE_LESSWC11_QUESTION

						CMPSB
						JNE		COMPARE_LESSWC11_EXIT
						LOOP	COMPARE_LESSWC11_INNER_LOOP
						JMP		COMPARE_LESSWC11_INNER_MATCH

COMPARE_LESSWC11_QUESTION:
						CMPSB
						; Then ignore result
						LOOP	COMPARE_LESSWC11_INNER_LOOP

COMPARE_LESSWC11_INNER_MATCH:
						XOR		CX,CX

COMPARE_LESSWC11_EXIT:
						POP		DI
						POP		SI
						RET

COMPARE_LESSWC11_DELETED:
						MOV		DI,100
						CMP		DI,99
						POP		DI
						POP		SI
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI C-String
; Return
;   CF=1  Wildcard present
;   CF=0  Wildcard not present
;   SI Destroyed
CHECK_WILDCARD_PRESENCE_CSTR:
						LODSB
						OR		AL,AL
						JE		CHECK_WILDCARD_CSTR_NO
						CMP		AL,'*'
						JE		CHECK_WILDCARD_CSTR_YES
						CMP		AL,'?'
						JE		CHECK_WILDCARD_CSTR_YES

						JMP_IF_NOT_KANJI	AL,CHECK_WILDCARD_PRESENCE_CSTR
						LODSB
						JMP		CHECK_WILDCARD_PRESENCE_CSTR
CHECK_WILDCARD_CSTR_NO:
						CLC
						RET
CHECK_WILDCARD_CSTR_YES:
						STC
						RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Kanji-Aware STRNCPY with Capitalization and Slash-to-Backslash
; Input:
;   DS:SI  Source
;   ES:DI  Destination
;   CX     Unsigned int length limit
; Output:
;   Length copied (excluding last 0)
KSTRNCPY_CAPS_BACKSLASH:
						PUSH	SI
						PUSH	DI
						PUSH	AX
						JCXZ	KSTRNCPY_CAPS_BACKSLASH_EXIT

KSTRNCPY_CAPS_BACKSLASH_NEXT:
						LODSB
						STC_IF_AL_IS_KANJI_FIRST_BYTE
						JC		KSTRNCPY_CAPS_BACKSLASH_ISKANJI

						OR		AL,AL
						JE		KSTRNCPY_CAPS_BACKSLASH_EXIT

						CMP		AL,'/'
						JNE		KSTRNCPY_CAPS_BACKSLASH_NOT_SLASH
						MOV		AL,'\'
						STOSB
						LOOP	KSTRNCPY_CAPS_BACKSLASH_NEXT
						JMP		KSTRNCPY_CAPS_BACKSLASH_EXIT

KSTRNCPY_CAPS_BACKSLASH_NOT_SLASH:
						CMP		AL,'a'
						JB		KSTRNCPY_CAPS_BACKSLASH_NOT_SMALL
						CMP		AL,'z'
						JA		KSTRNCPY_CAPS_BACKSLASH_NOT_SMALL
						ADD		AL,'A'-'a'

KSTRNCPY_CAPS_BACKSLASH_NOT_SMALL:
						STOSB
						LOOP	KSTRNCPY_CAPS_BACKSLASH_NEXT
						JMP		KSTRNCPY_CAPS_BACKSLASH_EXIT

KSTRNCPY_CAPS_BACKSLASH_ISKANJI:
						STOSB
						DEC		CX
						JCXZ	KSTRNCPY_CAPS_BACKSLASH_EXIT
						LODSB
						OR		AL,AL
						JE		KSTRNCPY_CAPS_BACKSLASH_EXIT
						STOSB
						LOOP	KSTRNCPY_CAPS_BACKSLASH_NEXT

KSTRNCPY_CAPS_BACKSLASH_EXIT:
						MOV		BYTE PTR ES:[DI],0
						MOV		CX,DI
						POP		AX
						POP		DI
						POP		SI
						SUB		CX,DI
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
;   CX  Byte actually copied (Excluding last 0)
; Preserves all other registers.
STRNCPY:
						PUSH	SI
						PUSH	DI
						PUSH	AX
						JCXZ	STRNCPY_EXIT

STRNCPY_LOOP:
						LODSB
						OR		AL,AL
						JE		STRNCPY_EXIT
						STOSB
						LOOP	STRNCPY_LOOP

STRNCPY_EXIT:
						MOV		CX,DI
						XOR		AX,AX
						STOSB

						POP		AX
						POP		DI
						POP		SI
						SUB		CX,DI
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
;   CX  Byte actually copied (Excluding last 0)
; Preserves all other registers.
STRCPY:
						PUSH	SI
						PUSH	DI
						PUSH	AX

STRCPY_LOOP:
						LODSB
						STOSB
						OR		AL,AL
						JNE		STRCPY_LOOP

						POP		AX
						POP		DI
						POP		SI
						SUB		CX,DI
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  Pathname
; Return
;   DS:DI  Pointer to last backslash or slash or zero or just incoming SI
;   AX     Destroyed
;   SI     Preserved
SEEK_LAST_BACKSLASH:
					PUSH	SI
					MOV		DI,SI
SEEK_LAST_BACKSLASH_LOOP:
					LODSB
					JMP_IF_KANJI	AL,SEEK_LAST_BACKSLASH_KANJI
					JMP_IF_SLASH	AL,SEEK_LAST_BACKSLASH_FOUND
					OR		AL,AL
					JNE		SEEK_LAST_BACKSLASH_LOOP

SEEK_LAST_BACKSLASH_EXIT:
					POP		SI
					RET

SEEK_LAST_BACKSLASH_FOUND:
					LEA		DI,[SI-1]
					JMP		SEEK_LAST_BACKSLASH_LOOP

SEEK_LAST_BACKSLASH_KANJI:
					LODSB
					JMP		SEEK_LAST_BACKSLASH_LOOP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI
; Output
;   DS:SI  Points to one after '\' or last zero.
;   AL     Last found backslash (5Ch) or zero
SEEK_NEXT_BACKSLASH:
						LODSB
						JMP_IF_SLASH	AL,SEEK_NEXT_BACKSLASH_FOUND
						JMP_IF_KANJI	AL,SEEK_NEXT_BACKSLASH_KANJI
						OR		AL,AL
						JNE		SEEK_NEXT_BACKSLASH

						DEC		SI		; If zero, don't overrun.
SEEK_NEXT_BACKSLASH_FOUND:
						RET

SEEK_NEXT_BACKSLASH_KANJI:
						LODSB
						JMP		SEEK_NEXT_BACKSLASH



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  Source File name
;   ES:DI  Destination 11-byte file name.
; Destroys EAX,CX
MAKE_11BYTE_FILENAME:
						PUSH	SI
						PUSH	DI

						MOV		EAX,20202020h
						STOSD
						STOSD
						STOSW
						STOSB
						SUB		DI,11

						MOV		CX,8
MAKE_11BYTE_FILENAME_LOOP:
						LODSB
						CMP		AL,'\'
						JE		MAKE_11BYTE_FILENAME_LOOP_BREAK
						CMP		AL,'/'
						JE		MAKE_11BYTE_FILENAME_LOOP_BREAK
						CMP		AL,0
						JE		MAKE_11BYTE_FILENAME_LOOP_BREAK
						CMP		AL,'.'
						JE		MAKE_11BYTE_FILENAME_LOOP_BREAK
						STOSB
						LOOP	MAKE_11BYTE_FILENAME_LOOP

						LODSB	; If no '.' after 8 letters, '.' must appear here.

MAKE_11BYTE_FILENAME_LOOP_BREAK:
						CMP		AL,'.'
						JNE		MAKE_11BYTE_FILENAME_EXIT

						ADD		DI,CX
						MOV		CX,3
MAKE_11BYTE_FILENAME_EXTENSION:
						LODSB
						CMP		AL,'\'
						JE		MAKE_11BYTE_FILENAME_EXIT
						CMP		AL,'/'
						JE		MAKE_11BYTE_FILENAME_EXIT
						CMP		AL,0
						JE		MAKE_11BYTE_FILENAME_EXIT
						CMP		AL,'.'
						JE		MAKE_11BYTE_FILENAME_EXIT
						STOSB
						LOOP	MAKE_11BYTE_FILENAME_EXTENSION

MAKE_11BYTE_FILENAME_EXIT:
						POP		DI
						POP		SI
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  11-byte filename+ext
;   ES:DI  13-byte buffer to receive plain plain filename.ext
; Output
;   ES:DI  Plain C-String filename.ext
;   Destroys AX,CX
PLAIN_FILENAME_FROM_11BYTE_FILENAME:
						PUSH	DI
						PUSH	SI

						MOV		CX,8
PLAIN_FROM_11_NAMEPART:
						LODSB
						CMP		AL,' '
						JE		PLAIN_FROM_11_NAMEDONE

						JMP_IF_NOT_KANJI	AL,PLAIN_FROM_11_NAME_NOTKANJI
						STOSB
						DEC		CX
						JE		PLAIN_FROM_11_NAMEDONE ; Broken Kanji but I cannot do anything about that.
						LODSB

PLAIN_FROM_11_NAME_NOTKANJI:
						STOSB
						LOOP	PLAIN_FROM_11_NAMEPART


PLAIN_FROM_11_NAMEDONE:
						POP		SI
						PUSH	SI
						ADD		SI,8

						CMP		BYTE PTR DS:[SI],' '
						JE		PLAIN_FROM_11_EXTDONE

						MOV		AL,'.'
						STOSB

						MOV		CX,3
PLAIN_FROM_11_EXTPART:
						LODSB
						CMP		AL,' '
						JE		PLAIN_FROM_11_EXTDONE
						STOSB
						LOOP	PLAIN_FROM_11_EXTPART

PLAIN_FROM_11_EXTDONE:
						XOR		AL,AL
						STOSB
						POP		SI
						POP		DI
						RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  Filename C-String "abc.xyz" format.
;   ES:DI  Minimum 13-byte buffer for storing lesser wild card.
; Output
;   CX     Number of chars in the lesser wild card.
;   DL     0FFh if there was '*'.  0 if there was no '*'.
;   EAX,EBX,DH    Destroyed
; This function converts
;   xyz*.x*
; to
;   xyz?????.x??
; It will copy as is until it finds a *.  Once it finds, the rest
; is filled with ?s.
; "*.*" will be converted to "????????.???"
MAKE_LESSER_WILDCARD:
						CMP		DWORD PTR DS:[SI],002A2E2Ah	; '*.*'
						JE		MAKE_LSR_WC_KOMEDOTKOME

						MOV		BX,SI
						SHL		EBX,16
						MOV		BX,DI
						MOV		CX,8
						MOV		DX,0200h ; DH=2 Doing name part.  DH=1 Doing ext part

MAKE_LSR_WC_LOOP:
						LODSB
						JMP_IF_KANJI	AL,MAKE_LSR_WC_KANJI
						JMP_IF_SLASH	AL,MAKE_LSR_WC_END_STRING
						OR		AL,AL
						JE		MAKE_LSR_WC_END_STRING

						CMP		AL,'*'
						JE		MAKE_LSR_WC_FOUNDSTAR
						CMP		AL,'.'
						JE		MAKE_LSR_WC_FOUNDDOT
						JMP		MAKE_LSR_WC_NOT_KANJI

MAKE_LSR_WC_KANJI:
						STOSB
						LODSB
						OR		AL,AL
						JE		MAKE_LSR_WC_END_STRING
						DEC		CX
						JE		MAKE_LSR_WC_FASTFWD
MAKE_LSR_WC_NOT_KANJI:
						STOSB
						LOOP	MAKE_LSR_WC_LOOP
						JMP		MAKE_LSR_WC_FASTFWD

MAKE_LSR_WC_FOUNDSTAR:
						MOV		DL,0FFh
						MOV		AX,'?'
						REP STOSB

MAKE_LSR_WC_FASTFWD:
						; Fast forward until zero or '.'
						LODSB
						STC_IF_AL_IS_KANJI_FIRST_BYTE
						JC		MAKE_LSR_WC_FASTFWD_KANJI
						CMP		AL,'.'
						JE		MAKE_LSR_WC_FOUNDDOT
						OR		AL,AL
						JE		MAKE_LSR_WC_END_STRING
						JMP		MAKE_LSR_WC_FASTFWD
MAKE_LSR_WC_FASTFWD_KANJI:
						LODSB
						JMP		MAKE_LSR_WC_FASTFWD

MAKE_LSR_WC_FOUNDDOT:
						DEC		DH
						JE		MAKE_LSR_WC_END_STRING
						MOV		AL,'.'
						STOSB
						MOV		CX,3
						JMP		MAKE_LSR_WC_LOOP


MAKE_LSR_WC_END_STRING:
						MOV		BYTE PTR ES:[DI],0
						MOV		CX,DI
						SUB		CX,BX
						MOV		DI,BX
						SHR		EBX,16
						MOV		SI,BX
						RET


MAKE_LSR_WC_KOMEDOTKOME:
						MOV		EAX,3F3F3F3Fh
						STOSD	; '????????'
						STOSD
						MOV		AL,2Eh
						STOSD	; '.???'
						MOV		BYTE PTR ES:[DI],0
						SUB		DI,12
						MOV		CX,12
						MOV		DL,0ffh
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL Flags
;     01h  Skip Leading Separator and Spaces
;     02h  Don't clear FCB Drive Byte
;     04h  Don't clear FCB File Name field
;     08h  Don't clear FCB Extension field
; Output
;   ES:DI Parsed FCB
;   DS:SI Next letter
;   AL=0 No wildcard
;   AL=1 With wildcard
;   AL=0FFh Error
; Uses FILENAME_BUFFER2 and TEMP_16CHAR_BUFFER
PARSE_TO_FCB:
						TEST	AL,02h
						JNE		PARSE_TO_FCB_DONT_CLEAR_DRIVE
						MOV		BYTE PTR ES:[DI],0
PARSE_TO_FCB_DONT_CLEAR_DRIVE:

						TEST	AL,04h
						JNE		PARSE_TO_FCB_DONT_CLEAR_FNAME
						MOV		DWORD PTR ES:[DI+1],20202020h
						MOV		DWORD PTR ES:[DI+5],20202020h
PARSE_TO_FCB_DONT_CLEAR_FNAME:

						TEST	AL,08h
						JNE		PARSE_TO_FCB_DONT_CLEAR_EXT
						MOV		WORD PTR ES:[DI+9],2020h
						MOV		BYTE PTR ES:[DI+11],20h
PARSE_TO_FCB_DONT_CLEAR_EXT:

						MOV		DWORD PTR ES:[DI+12],0

						TEST	AL,1
						JE		PARSE_TO_FCB_DONT_SKIP_LEADSEP

						CALL	SKIP_ALL_TAB_AND_SPACE
						MOV		AL,DS:[SI]
						CALL	CMP_AL_DIVIDER
						JNE		PARSE_TO_FCB_DONT_SKIP_LEADSEP
						INC		SI
PARSE_TO_FCB_DONT_SKIP_LEADSEP:
						CALL	SKIP_ALL_TAB_AND_SPACE

						CMP		BYTE PTR DS:[SI+1],':'
						JNE		PARSE_TO_FCB_DRIVE_DONE

						MOV		AL,DS:[SI]
						CAPITALIZE	AL
						CALL	CMP_AL_SEPARATOR
						JE		PARSE_TO_FCB_DRIVE_DONE
						CMP		AL,'Z'
						JA		PARSE_TO_FCB_DRIVE_DONE
						SUB		AL,'A'
						JB		PARSE_TO_FCB_DRIVE_DONE

						INC		AL
						MOV		ES:[DI],AL
						ADD		SI,2

PARSE_TO_FCB_DRIVE_DONE:
						; DS:SI File Name.  Drive name and ':' may be already skipped.
						; ES:DI FCB.

						PUSH	ES
						PUSH	DI

						PUSH	CS
						POP		ES
						MOV		DI,OFFSET FILENAME_BUFFER2
PARSE_TO_FCB_COPY_1:
						LODSB
						CAPITALIZE	AL
						CALL	CMP_AL_SEPARATOR
						JE		PARSE_TO_FCB_COPY_1_BREAK
						STOSB
						JMP		PARSE_TO_FCB_COPY_1

PARSE_TO_FCB_COPY_1_BREAK:
						DEC		SI

						SUB		DI,OFFSET FILENAME_BUFFER2
						MAKESMALLER_UNSIGNED	DI,12
						MOV		BYTE PTR CS:[FILENAME_BUFFER2+DI],0

						POP		DI
						POP		ES

						XOR		AL,AL ; Wildcard not found yet.
						CMP		BYTE PTR CS:[FILENAME_BUFFER2],0
						JE		PARSE_TO_FCB_DONE	; Nothing more to parse

						PUSH	DS
						PUSH	SI
						PUSH	ES
						PUSH	DI

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER2

						PUSh	CS
						POP		ES
						MOV		DI,OFFSET TEMP_16CHAR_BUFFER
						CALL	MAKE_LESSER_WILDCARD

						POP		DI
						POP		ES
						PUSH	ES
						PUSH	DI
						INC		DI

						; DS is already same as CS
						MOV		SI,OFFSET TEMP_16CHAR_BUFFER
						CALL	MAKE_11BYTE_FILENAME

						MOV		SI,OFFSET TEMP_16CHAR_BUFFER
						MOV		DL,1	; Tentatively Wildcard=1
PARSE_TO_FCB_CHECK_WILDCARD:
						LODSB
						CMP		AL,'*'
						JE		PARSE_TO_FCB_FOUND_WILDCARD
						CMP		AL,'?'
						JE		PARSE_TO_FCB_FOUND_WILDCARD
						CMP		AL,0
						JNE		PARSE_TO_FCB_CHECK_WILDCARD

						XOR		DL,DL	; Wildcard not found.
PARSE_TO_FCB_FOUND_WILDCARD:

						MOV		AL,DL

						POP		DI
						POP		ES
						POP		SI
						POP		DS
PARSE_TO_FCB_DONE:
						MOV		AH,29h ; Recover AH
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


SKIP_ALL_TAB_AND_SPACE_NEXT:
						INC		SI

SKIP_ALL_TAB_AND_SPACE:
						CMP		BYTE PTR DS:[SI],' '
						JE		SKIP_ALL_TAB_AND_SPACE_NEXT
						CMP		BYTE PTR DS:[SI],ASCII_TAB
						JE		SKIP_ALL_TAB_AND_SPACE_NEXT

						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


CMP_AL_TAB_OR_SPACE:
						CMP		AL,' '
						JE		CMP_AL_TAB_OR_SPACE_RET
						CMP		AL,ASCII_TAB
CMP_AL_TAB_OR_SPACE_RET:
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


CMP_AL_DIVIDER:
						CMP		AL,' '
						JE		CMP_AL_DIVIDER_RET
						CMP		AL,ASCII_TAB
						JE		CMP_AL_DIVIDER_RET
						CMP		AL,'+'
						JE		CMP_AL_DIVIDER_RET
						CMP		AL,','
						JE		CMP_AL_DIVIDER_RET
						CMP		AL,':'
						JE		CMP_AL_DIVIDER_RET
						CMP		AL,';'
						JE		CMP_AL_DIVIDER_RET
						CMP		AL,'<'
						JE		CMP_AL_DIVIDER_RET
						CMP		AL,'='
						JE		CMP_AL_DIVIDER_RET
						CMP		AL,'>'
						JE		CMP_AL_DIVIDER_RET
						CMP		AL,'|'
						JE		CMP_AL_DIVIDER_RET

CMP_AL_DIVIDER_RET:
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


CMP_AL_SEPARATOR:
						CMP		AL,' '
						JBE		CMP_AL_SEPARATOR_ZERO_RET
						CMP		AL,ASCII_DOUBLEQUOTE
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,'+'
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,','
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,'.'
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,'/'
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,':'
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,';'
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,'<'
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,'='
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,'>'
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,'['
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,'\'
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,']'
						JE		CMP_AL_SEPARATOR_RET
						CMP		AL,'|'
						JE		CMP_AL_SEPARATOR_RET
CMP_AL_SEPARATOR_RET:
						RET

CMP_AL_SEPARATOR_ZERO_RET:
						CMP		AL,AL
						RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



