PROCESS_RETURN_POINTER	DD		0
PROCESS_FILENAME_PTR	DD		0
PROCESS_EXEC_PARAM		DD		0
PROCESS_FILE_HANDLE		DW		0
PROCESS_ENVSEG			DW		0
PROCESS_BINSEG			DW		0
PROCESS_FCB_DRIVE_AVAIL	DW		0
PROCESS_EXEC_MODE		DB		0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; EXEC_OR_LOAD
;
; Analysis of the original MS-DOS V3.1
;
;AL=0,1
;param+00h  WORD  Source ENVSEG
;param+02h  DWORD Command Tail to be copied to new PSP:0080h
;param+06h  DWORD First FCB to be copied to child's PSP
;param+0Ah  DWORD Second FCB to be copied to child's PSP
;param+0Eh  DWORD Return Initial SS:SP if AL=1
;param+12h  DWORD Return Initial CS:IP if AL=1
;
;AL=3 (Overlay)
;param+00h  WORD  Segment to Load Overlay. Must be malloced by the calling process?
;param+02h  WORD  Relocation factor to load .EXE overlay.
;
;
;[BP-1Ah] Filename OFFSET
;[BP-18h] Filename SEG
;[BP-16h] Strlen(Filename)  CS:57F6
;[BP-14h] (Prob)Loading point
;[BP-12h] Malloced Segment
;[BP-10h] Malloc Size
;[BP-0Eh] New ENVSEG
;[BP-0Ch] Binary Size in paragraphs CS:58BB if .EXE (fileSize-headerSize)
;[BP-0Ah] Relocation Factor
;[BP-08h] File Handle of EXE
;[BP-06h] Flag EXE has max allocation paragraphs
;[BP-05h] Exec Mode
;[BP-04h] Exec Param Block OFFSET
;[BP-02h] Exec Param Block SEG
;
;CS:1111  Initial SP
;CS:1113  Initial SS
;CS:1115  Initial IP
;CS:1117  Initial CS
;
;CS:1119h +00h ExeHeader+00  "MZ" Exe Header
;CS:111Bh +02h Size of last page?
;CS:111Dh +04h (File size+511)/512
;CS:111fh +06h Relocation table count
;CS:1121h +08h Header size in paragraphs <- This must include relocation table
;CS:1123h +0Ah Min Alloc Paragraphs
;CS:1125h +0Ch Max Alloc Paragraphs
;CS:1127h +0Eh Initial SS	; Isn't it SP and SS reversed?  It is reversed.  COnfirmed.  CS:59B1.
;CS:1129h +10h Initial SP
;CS:112Bh +12h Checksum
;CS:112Dh +14h Initial IP
;CS:112Fh +16h Initial CS
;CS:1131h +18h Relocation Table Offset <- Offset from the top of the file.
;CS:1133h +1Ah Overlay number?
;
;
;
;system(exeFileName,srcEnvSeg,AL=openMode)
;
;CS:57C5  INT 21H AH=4B
;if(openMode!=0 && openMode!=1 && openMode!=3)
;{
;	return DOSERR_INVALID_FUNC;
;}
;CS:57FF
;if(fp=fopen(exeFileName) returns error, or fp is CHARDEV)
;{
;	return DOSERR_FILE_NOT_FOUND;
;}
;
;CS:5825
;newEnvSeg=NULL;  // Temporarily nulify newEnvSeg
;
;CS:582E
;if(openMode!=3)  // Overlay->Don't worry about ENVSEG
;{
;	CS:5830
;	copyEnvFrom=NULL;
;	if(NULL!=srcEnvSeg)
;	{
;		copyEnvFrom=srcEnvSeg;
;	}
;	else
;	{
;		copyEnvFrom=currentPDB.envSeg;
;	}
;	if(NULL!=copyEnvFrom)
;	{
;		CX=length of copyEnvFrom (Search for double 0s)
;		if(7fffh<CX)
;		{
;			return DOSERR_BAD_ENV;
;		}
;		CX+=strlen(exeFileName)+1+10h	; What is this 10h bytes for?
;		newEnvSeg=Malloc(CX);
;		if(NULL==newEnvSeg)
;		{
;			return DOSERR_OUT_OF_MEMORY;
;		}
;		Copy from copyEnvFrom to newEnvSeg, including last 00 00
;		Append 01h 00h (CS:5879)
;		Append Filename
;	}
;}
;// newEnvSeg is NULL if exec mode==3(Overlay) or a copy from src.
;
;// At this poitn, CX,BX,DX,SI,DS don't care.  Probably AX doesn't care.  BP cares.
;// ES is New ENVSEG.
;
;CS:5885
;bytesRead=fread(CS:exeHeader,0,0x1A,fp); // CS:1119h
;if(ferror(fp))
;{
;	fclose(fp);
;	return DOSERR_BAD_FORMAT;
;}
;else if(0x1A==bytesRead && exeHeader starts with "MZ" or "ZM") // Apparently it accepts ZM as well.
;{
;	CS:589F
;	if(0==WORD PTR(exeHeader+0Ch) // Maximum Allocation Paragraphs
;	{
;		BYTE PTR [BP-06h]=0FFh
;	}
;
;	AX=(WORD PTR(exeHeader+4)); // File size in 512-byte pages
;	AX*=32;                     // Convert to 16-byte paragraphs
;	AX-=WORD PTR(exeHeader+8);  // Subtract header-size in paragraphs to get binary size
;	WORD PTR[BP-0Ch]=AX;  CS:58C6
;	if(3==openMode)
;	{
;		; Must be loading .EXE as overlay
;		[BP-14h]=execParam.loadPoint (=srcEnvSeg)
;		[BP-0Ah]=execParam.relocation factor to apply to overlay if in .EXE
;	}
;	else
;	{
;		CS:58FA ; Must be continue loading .EXE
;		AX+=10h
;		if(Max Available Paragraphs<11h ||
;		   Max Available Paragraphs<AX)
;		{
;			fclose(fp);
;			return DOSERR_OUT_OF_MEMORY
;		}
;		if(AX+exeHeader.MinAllocParagraphs overflows)
;		{
;			fclose(fp);
;			return DOSERR_OUT_OF_MEMORY
;		}
;		if(MaxAvailableParagraphs<AX+exeHeader.MinAllocParagraphs)
;		{
;			fclose(fp);
;			return DOSERR_OUT_OF_MEMORY
;		}
;
;		auto requestSize=AX+exeHeader.MinAllocParagraphs; // This is known to be available
;		if(exeHeader.MinAllocParagraphs<exeHeader.MaxAllocParagraphs) // It is possible if EXE is not correct.
;		{
;			requestSize=min(MaxAvailableParagraphs,AX+exeHeader.MaxAllocParagraphs)
;		}
;		if(0==exeHeader.MinAllocParagraphs)
;		{
;			requestSize=maxAvailableParagraphs;
;		}
;		[BP-10h](MallocSize)=requestSize;
;		[BP-12h](MallocedSegment)=MALLOC(requestSize); // THis is supposed to succeed
;		if(failed to malloc) // But check anyway
;		{
;			fclose(fp);
;			return DOSERR_OUT_OF_MEMORY;
;		}
;
;		// MS-DOS Encycropedia pp.121 explains correctly.  If both MINALLOC and MAXALLOC are both zero,
;		// Binary image is loaded at the high-end of the allocated arena.
;		// MS-DOS Encycropedia pp.124 implies that the binary is loaded into the high-end of the allocated block.
;		// However, disassembly implies it loads into the high-end only when MaxAllocSize is non zero.
;		if([BP-06h]) if MAXALLOC==0
;		{
;			[BP-0Ah] Relocation Factor=MallocedSegment+MallocSize-BinarySize;
;			[BP-14h] Loading Point    =MallocedSegment+MallocSize-BinarySize;
;		}
;		else
;		{
;			[BP-0Ah] Relocation Factor=MallocedSegment+10h;  // Prob 100h for PSP
;			[BP-14h] Loading Point    =MallocedSegment+10h;
;		}
;	}
;
;	// By this point, need:
;	//   LoadPoint
;	//   RelocationFactor
;	//   MallocSize
;	//   MallocedSegment (or zero if overlay)  I have never seen EXE overlay....
;
;	CS:5957 at leat loading point and reloc factor ready.
;	fseek(fp,header size in bytes,SEEK_SET);
;	if(error)
;	{
;		fclose(fp);
;		return whatever error returned by fseek.
;	}
;	fread binary.
;	if(error)
;	{
;		fclose(fp);
;		return whatever error returned by fread.
;	}
;
;	CS:59B1
;	Relocate and Save Initial SP,SS, IP,CS in CS:1111,1113,1115,1117.  SP and SS order in file is reversed in file.
;
;	fseek(fp,exeHeader.RelocationTableOffset,SEEK_SET);
;	if(error)
;	{
;		fclose(fp);
;		return DOSERR_BAD_FORMAT;
;	}
;
;	while(0<relocation Count)
;	{
;		if(buffer exhausted)
;		{
;			fread to up to 184h bytes into file name buffer (CS:360h)
;			rewind pointer
;		}
;		fetch SEG,OFFSET from table
;		add word ptr (SEG+RelocationFactor):OFFSET,ReloationFactor
;	}
;}
;else
;{
;	CS:5A20 ; Must be loading .COM or .SYS
;	if(3==openMode)
;	{
;		CS:5A26
;		[BP-14h]=srcEnvSeg; // In this case, srcEnvSeg is load point.
;		AX=0ffffh
;	}
;	else
;	{
;		CS:5A32
;		Allocate Max Available Memory
;		if(fail)
;		{
;			fclose(fp);
;			return DOSERR_OUT_OF_MEMORY;
;		}
;		[BP-10h]MallocSize=Max Available Paragraphs;
;		[BP-12h]=Malloced Segment;
;		[BP-14h]Load Point=Malloced Segment+10h;  Save space for PSP
;		AX=either max available bytes-100h or 0FF00h
;	}
;	CS:5A5E AX is bytes to read.
;	fseek(fp,0,SEEK_SET)
;	fread for max AX bytes
;	if(ferror(fp))
;	{
;		fclose(fp);
;		return DOSERR_BAD_FORMAT;
;	}
;
;	CS:5A7F
;	if(3!=openMode)
;	{
;		Initial IP=0100h
;		Initial CS=Load Point-10h (Offset -100h bytes to include PSP)
;		Initial SP=00FEh
;		Initial SS=Load Point-10h (Offset -100h bytes to include PSP)
;		WORD PTR Initial SS:[0FEh]=0
;	}
;}
;
;CS:5AA9
;fclose(fp);
;CS:5AB4
;if(3==openMode)
;{
;	; In Fact, if overlay, there is no malloc, no copy of envseg.  Therefore, done.
;	if New ENVSEG!=0 PSP_OWNER of New ENVSEG MCB to CurrentPDB
;	if Malloced Segment!=0, PSP_OWNER of Malloced Segment to CurrentPDB
;	; If Overlay, done.
;	return DOSERR_NOERROR;
;}
;else
;{
;	if New ENVSEG!=0 PSP_OWNER of New ENVSEG MCB to MallocedSegment(=New PSP) 
;	PSP_OWNER of Malloced Segment to MallocedSegment(=New PSP)
;}
;
;CS:5AE3
;Call INT 21H AH=55h with NewPSP=[BP-12h](Malloced Seg), MemorySize=[BP-12h]+[BP-10h]
;ªQuestion: Does it update CurrentPDB?  Yes it does after DOS 2.0.
;
;PSP:[ENVSEG]=[BP+0Eh] New ENVSEG
;Copy First FCB for 0Ch bytes then write 0000 to make it 10h bytes
;Copy Second FCB for 0CH bytes then write 0000 to make it 10h bytes
;Copy Parameter to PSP+80h
;
;CS:5B20h
;BL=First FCB drive byte
;BH=Second FCB drive byte
;Set Up Current CDS ? Call CS:6100h
;BH,BL will become 00 or FF: 00:FCB drive available FF:FCB drive unavailable.
;
;Copy REturn Address to PSP.INT22H
;Copy Return Address to INT 22H Handler
;
;Set DTA Address to PSP:0080h
;if(1==openMode) // Load but don't exec
;{
;	Write BX to Initial SS:SP.
;	Subtract Initial SP by 2.
;	Copy Initial SS:SP to Exec Param Block+0Eh
;	Copy Initial CS:IP to Exec Param Block+12h
;	CS:5B97
;	return DOSERR_NOERROR
;}
;else
;{
;	DS:SI=InitialCS:InitialIP
;	ES:DI=InitialSS:InitialSP
;	CLI	// Needed because INDOS==0 implies SS!=CS
;	CS:[INDOS]=0
;	SS:SP=InitialSS:InitialSP
;	STI
;	// I believe DX never changed after Call INT 21H AH=55h.  So, DX must be PSP segment.
;	DS=DX; // Where is this DX coming from?
;	ES=DX; // Where is this DX coming from?
;	AX=BX; // From FCB drive availability
;	PUSH InitialCS:InitialIP
;	CS:5BBB
;	RETF into new process
; }
;
; Input:
;   DS:SI  C-String Filename
;   ES:DI  Exec Param Block
;   AL     Exec Mode
EXEC_OR_LOAD_PROC:
						MOV		BYTE PTR CS:[STARTING_SHSUCDX],0

						MOV		CS:[PROCESS_EXEC_MODE],AL
						MOV		WORD PTR CS:[PROCESS_FILENAME_PTR],SI
						MOV		WORD PTR CS:[PROCESS_FILENAME_PTR+2],DS
						MOV		WORD PTR CS:[PROCESS_EXEC_PARAM],DI
						MOV		WORD PTR CS:[PROCESS_EXEC_PARAM+2],ES

						CALL	LOAD_EXE_OR_COM
						; If CF=0
						;     CX=ENVSEG or zero if not created
						;     DX=LoadPoint
						;     AX=Allocation Size (Zero if Overlay)
						;     BX=Allocated Segment (Zero if Overlay)
						;     ESI=Initial SS:SP (Hiword=SS, Loword=OFFSET)
						;     EDI=Initial CS:IP (Hiword=SS, Loword=OFFSET)
						; If CF=1
						;     AX=DOS Error Code
						JC		EXEC_OR_LOAD_ERROR_END

						MOV		DWORD PTR CS:[EXE_INITIAL_SP],ESI
						MOV		DWORD PTR CS:[EXE_INITIAL_IP],EDI

						CALL	TOWNS_CMP_FILENAME_BUFFER_SHSUCDXCOM
						JNE		EXEC_OR_LOAD_NOT_SHSUCDX
						MOV		BYTE PTR CS:[STARTING_SHSUCDX],1
EXEC_OR_LOAD_NOT_SHSUCDX:

						; Binary Loaded


						CMP		BYTE PTR CS:[PROCESS_EXEC_MODE],3		; If overlay, it's done.
						JE		EXEC_OR_LOAD_LOAED_SUCCESSFULLY


						; Set MCB Owner to ENVSEG and PSP

						PUSH	ES

						DEC		BX
						MOV		ES,BX
						INC		BX
						MOV		ES:[MCB_PID],BX	; Allocated Segment=Child PSP

						OR		CX,CX	; ENVSEG
						JE		EXEC_OR_LOAD_NOENVSEG

						DEC		CX
						MOV		ES,CX
						INC		CX
						MOV		ES:[MCB_PID],BX	; Allocated Segment=Child PSP
EXEC_OR_LOAD_NOENVSEG:

						POP		ES


						;     CX=ENVSEG or zero if not created
						;     DX=LoadPoint
						;     AX=Allocation Size (Zero if Overlay)
						;     BX=Allocated Segment (Zero if Overlay) Will be Child PSP
						;     ESI=Initial SS:SP (Hiword=SS, Loword=OFFSET)
						;     EDI=Initial CS:IP (Hiword=SS, Loword=OFFSET)
						PUSH	CX
						PUSh	DX

						MOV		DX,BX	; DX needs to be ChildPSP

						MOV		SI,AX
						ADD		SI,BX
						CALL	CREATE_PDB

						POP		DX
						POP		CX

						; AX is free after calculating PSP_ENDMEM.
						; BX is free.  Copied to CS:[CurrentPDB]
						; EDI,ESI are backed up in CS:[EXE_INITIAL_IP],CS:[EXE_INITIAL_SP]

						MOV		ES,CS:[CurrentPDB]
						MOV		ES:[PSP_ENV_SEG],CX

						LDS		SI,CS:[PROCESS_EXEC_PARAM]
						LDS		SI,DS:[SI+EXEC_NORMAL_FIRSTFCB]
						MOV		DI,PSP_FCB_1
						MOVSD
						MOVSD
						MOVSD
						MOV		WORD PTR ES:[DI],0

						LDS		SI,CS:[PROCESS_EXEC_PARAM]
						LDS		SI,DS:[SI+EXEC_NORMAL_SECONDFCB]
						MOV		DI,PSP_FCB_2
						MOVSD
						MOVSD
						MOVSD

						LDS		SI,CS:[PROCESS_EXEC_PARAM]
						LDS		SI,DS:[SI+EXEC_NORMAL_COMMANDARG]
						MOV		DI,PSP_COMMAND_LINE
						MOV		CX,PSP_COMMAND_LINE_LEN
						REP	MOVSB

						MOV		AL,ES:[PSP_FCB_1]
						CALL	FCBDRIVE_TO_SANE_DRIVE	; Yes, I am saying FCB is insane.
						CALL	IS_DRIVE_AVAILABLE      ; BH=00 Available FF Unavailable

						MOV		BL,BH

						MOV		ES,CS:[CurrentPDB]
						MOV		AL,ES:[PSP_FCB_2]
						CALL	FCBDRIVE_TO_SANE_DRIVE
						CALL	IS_DRIVE_AVAILABLE

						; BX is FCB-drive availability

						MOV		CS:[PROCESS_FCB_DRIVE_AVAIL],BX

						MOV		ES,CS:[CurrentPDB]


						; Original MS-DOS V3.1  CS:5B38h


						_LDS	SI,CS:[SP_RESTORE_POINT]
						MOV		ESI,DS:[SI+SAVE_REGISTERS_STACK_LEN]

						; ES=CurrentPDB
						; BX=FCB-drive availability
						; ESI=Return Address
						MOV		ES:[PSP_INT22H],ESI	; Won't INT 22H crash?
						XOR		AX,AX
						MOV		DS,AX
						MOV		DS:[0022h*4],ESI	; INT 22H Handler.

						MOV		WORD PTR CS:[DMA_BUFFER_PTR],DMA_BUFFER_INITIAL_OFFSET
						MOV		WORD PTR CS:[DMA_BUFFER_SEG],ES

						; INT 22H Just jumps back to the previous address?
						; Without resetting stack, current PDB, etc?
						; I don't think INT 22H really works.

						CMP		BYTE PTR CS:[PROCESS_EXEC_MODE],1	; Load but don't exec
						JE		EXEC_OR_LOAD_FINISH_LOADING

; Jump to the process
						; DOS Expects ES,DS,BP,DI,SI,DX,CX,BX,AX in the stack.
						RESTORE_REGISTERS
						PUSH	ES
						PUSH	DS
						PUSH	BP
						PUSH	DI
						PUSH	SI
						PUSH	DX
						PUSH	CX
						PUSH	BX
						PUSH	AX

						; This SS:SP needs to be recorded in the CurrentPDB's PSP_STACK_PTR,
						; and Caller PSP's PSP_STACK_PTR.
						PUSH	ESI
						PUSH	DI	; What to record is SP+6

						MOV		SI,SS
						SHL		ESI,16
						MOV		SI,SP
						ADD		SI,6
						MOV		ES,CS:[CurrentPDB]
						MOV		ES:[PSP_STACK_PTR],ESI

						MOV		DI,ES:[PSP_CALLER_PSP_SEG]
						OR		DI,DI
						JE		EXEC_OR_LOAD_JUMP
						MOV		ES,DI
						MOV		ES:[PSP_STACK_PTR],ESI
EXEC_OR_LOAD_JUMP:
						POP		DI
						POP		ESI

						MOV		AX,CS:[PROCESS_FCB_DRIVE_AVAIL]
						MOV		DS,CS:[CurrentPDB]
						MOV		ES,CS:[CurrentPDB]

						; For the short time, INDOS and SS becomes inconsistent
						; Therefore need CLI and STI.
						CLI
						MOV		BYTE PTR CS:[INDOS],0
						LSS		SP,CS:[EXE_INITIAL_SP]
						STI

;						JMP		FAR [CS:EXE_INITIAL_IP]			; --USE_IN_NASM--
						JMP		DWORD PTR CS:[EXE_INITIAL_IP]	; --NOT_IN_NASM--


EXEC_OR_LOAD_FINISH_LOADING:
						SUB		WORD PTR CS:[EXE_INITIAL_SP],2
						LDS		SI,CS:[EXE_INITIAL_SP]
						MOV		BX,CS:[PROCESS_FCB_DRIVE_AVAIL]
						MOV		DS:[SI],BX	; FCB Drive Availability at the top of the stack.

						LDS		SI,CS:[PROCESS_EXEC_PARAM]
						MOV		EAX,CS:[EXE_INITIAL_IP]
						MOV		DS:[SI+EXEC_NORMAL_INIT_CSIP],EAX
						MOV		EAX,CS:[EXE_INITIAL_SP]
						MOV		DS:[SI+EXEC_NORMAL_INIT_SSSP],EAX
EXEC_OR_LOAD_LOAED_SUCCESSFULLY:
						CLC
						RET

EXEC_OR_LOAD_ERROR_END:
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX=Source ENVSEG (0->Use CurrentPDB's ENVSEG)
;   ES:DI=Executable Filename
; Return
;   CF=0 AX=ES=New ENVSEG, Zero if no source ENVSEG
;   CF=1 Out of memory
; Destroys DS,SI
; Preserves FS,GS,BP
COPY_ENVSEG_FOR_NEWPROC:
						PUSH	BP
						PUSH	FS
						PUSH	GS

						OR		AX,AX
						JNE		COPY_ENVSEG_SOURCE_FIXED

						MOV		DS,CS:[CurrentPDB]
						MOV		AX,DS:[PSP_ENV_SEG]

COPY_ENVSEG_SOURCE_FIXED:
						MOV		DS,AX
						OR		AX,AX
						JE		COPY_ENVSEG_NO_SOURCE

						; DS is Source ENVSEG
						; ES:DI is exe file name

						CALL	ENVLEN	; In>DS=ENVSEG Out>SI=Index at 00 00
						ADD		SI,4	; 00 00 01 00

						PUSH	ES
						PUSH	DI
						PUSH	DS		; Save Source ENVSEG

						PUSH	SI		; Save ENVSEG length
						CALL	STRLEN_ESDI	; In>ES:DI=C-String Out>CX=Number of letters
						POP		AX

						ADD		CX,AX
						ADD		CX,011h	; 10h bytes extra?  Plus 1 byte for string termination.

						MOV		BX,CX
						ADD		BX,0FH
						SHR		BX,4
						CALL	MALLOC	; AX is allocated segment

						POP		DS
						POP		DI
						POP		ES
						JC		COPY_ENVSEG_EXIT

						PUSH	ES
						PUSH	DI

						MOV		ES,AX
						XOR		DI,DI
						XOR		SI,SI
						CALL	ENVCPY
						; DI points to the last 00 00h

						ADD		DI,2
						MOV		AX,0001h
						STOSW

						POP		SI
						POP		DS
						CALL	STRCPY

						MOV		AX,ES

COPY_ENVSEG_EXIT:
						POP		GS
						POP		FS
						POP		BP
						RET

COPY_ENVSEG_NO_SOURCE:
						MOV		ES,AX
						CLC
						POP		GS
						POP		FS
						POP		BP
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input:
;   DS:SI=Filename
;   ES:DI=Exec Parameter Block
;   AL=Mode (0:Load and Exec, 1:Load but not exec, 3:Load Overlay)
; Output
;   CF=0
;     CX=ENVSEG or zero if not created
;     DX=LoadPoint
;     AX=Allocation Size (Zero if Overlay)
;     BX=Allocated Segment (Zero if Overlay)
;     ESI=Initial SS:SP (Hiword=SS, Loword=OFFSET)
;     EDI=Initial CS:IP (Hiword=SS, Loword=OFFSET)
;     CS:[PROCESS_EXEC_MODE]
;     CS:[PROCESS_EXEC_PARAM]
;   CF=1
;     AX=DOS Error Code
LOAD_EXE_OR_COM:
						CMP		AL,0
						JE		LOAD_EXE_OR_COM_MODEOK
						CMP		AL,1
						JE		LOAD_EXE_OR_COM_MODEOK
						CMP		AL,3
						JE		LOAD_EXE_OR_COM_MODEOK

						MOV		AX,DOSERR_INVALID_FUNC
						STC
						JMP		LOAD_EXE_OR_COM_EXIT

LOAD_EXE_OR_COM_MODEOK:
						MOV		WORD PTR CS:[PROCESS_FILENAME_PTR],SI
						MOV		WORD PTR CS:[PROCESS_FILENAME_PTR+2],DS

						MOV		CS:[PROCESS_EXEC_MODE],AL
						MOV		WORD PTR CS:[PROCESS_EXEC_PARAM],DI
						MOV		WORD PTR CS:[PROCESS_EXEC_PARAM+2],ES

						MOV		WORD PTR CS:[PROCESS_FILE_HANDLE],0
						MOV		WORD PTR CS:[PROCESS_ENVSEG],0
						MOV		WORD PTR CS:[PROCESS_BINSEG],0

						MOV		AL,0	; Read Mode
						CALL	FOPEN
						JC		LOAD_EXE_OR_COM_EXIT

						MOV		CS:[PROCESS_FILE_HANDLE],AX

						CALL	CHECK_FILE_IS_CHARDEV
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JC		LOAD_EXE_OR_COM_ERREND


						CMP		BYTE PTR CS:[PROCESS_EXEC_MODE],3
						JE		LOAD_EXE_OR_COM_ENVSEG_DONE

						LDS		SI,CS:[PROCESS_EXEC_PARAM]
						MOV		AX,DS:[SI+EXEC_NORMAL_SRC_ENVSEG]
						LES		DI,CS:[PROCESS_FILENAME_PTR]
						CALL	COPY_ENVSEG_FOR_NEWPROC
						MOV		BX,AX
						MOV		AX,DOSERR_OUT_OF_MEMORY
						JC		LOAD_EXE_OR_COM_ERREND
						MOV		CS:[PROCESS_ENVSEG],BX

LOAD_EXE_OR_COM_ENVSEG_DONE:
						; Let's cache LoadPoint and RelocFactor in case Exec Mode=Overlay
						XOR		DX,DX
						XOR		BX,BX
						CMP		BYTE PTR CS:[PROCESS_EXEC_MODE],3
						JNE		LOAD_EXE_OR_COM_TYPE_ID

						LDS		SI,CS:[PROCESS_EXEC_PARAM]
						MOV		DX,DS:[SI+EXEC_OVERLAY_LOADPOINT]
						MOV		BX,DS:[SI+EXEC_OVERLAY_RELOCATION]

LOAD_EXE_OR_COM_TYPE_ID:
						PUSH	DX	; Save LoadPoint and RelocFactor for Overlay or Zero for normal
						PUSH	BX

						MOV		DX,CS
						SHL		EDX,16
						MOV		DX,OFFSET EXE_HEADER_BUFFER
						MOV		ECX,EXEHEADER_size
						MOV		AX,CS:[PROCESS_FILE_HANDLE]
						CALL	FREAD_FROM_JFN

						POP		BX
						POP		DX

						JC		LOAD_EXE_OR_COM_EXIT
						CMP		ECX,EXEHEADER_size
						JNE		LOAD_EXE_OR_COM_MAYBE_COM	; A .COM file can be shorter than 01Ah bytes.

						CMP		WORD PTR CS:[EXE_HEADER_BUFFER+EXE_SIGNATURE],05A4Dh ; "MZ"
						JE		LOAD_EXE_OR_COM_MUSTBE_EXE
						CMP		WORD PTR CS:[EXE_HEADER_BUFFER+EXE_SIGNATURE],04D5Ah ; "ZM"
						JNE		LOAD_EXE_OR_COM_MAYBE_COM

LOAD_EXE_OR_COM_MUSTBE_EXE:
						; Input
						;   CS:[EXE_HEADER]  1Ah byte EXE Header
						;   AX=File Handle
						;   DX=Load Point (Non-Zero means Overlay)
						;   BX=Relocation Factor (Valid only when Load Point is non zero)
						MOV		AX,CS:[PROCESS_FILE_HANDLE]
						; DX and BX is already set.
						CALL	LOAD_EXE
						; Output
						;   DX=LoadPoint
						;   AX=Allocation Size (Zero if Overlay)
						;   BX=Allocated Segment (Zero if Overlay)
						;   ESI=Initial SS:SP (Hiword=SS, Loword=OFFSET)
						;   EDI=Initial CS:IP (Hiword=SS, Loword=OFFSET)
						MOV		CS:[PROCESS_BINSEG],BX
						JNC		LOAD_EXE_OR_COM_LOADED

						MOV		AX,DOSERR_BAD_FORMAT
						JMP		LOAD_EXE_OR_COM_ERREND


LOAD_EXE_OR_COM_MAYBE_COM:
						MOV		AX,CS:[PROCESS_FILE_HANDLE]

						; Input
						;   AX=File Handle
						;   DX=Load Point (Non-Zero mean Overlay mode.  Zero means need malloc.)
						CALL	LOAD_COM_OR_SYS
						; Return
						;   CF=0
						;   DX=Load Point
						;   AX=Malloc Size in Paragraphs, or zero if load point was given as input
						;   BX=Segment that Malloc returned, or zero if load point was given as input
						;   CF=1
						;   AX=DOS Error Code
						JC		LOAD_EXE_OR_COM_ERREND

						MOVZX	ESI,AX
						SHL		ESI,4
						MAKESMALLER_UNSIGNED	ESI,10000h
						SUB		SI,2;

						SUB		DX,10h	; 100h bytes

						ROL		ESI,16
						MOV		SI,DX
						ROL		ESI,16

						MOV		DI,DX
						ROL		EDI,16
						MOV		DI,0100h

						MOV		DS,DX
						MOV		WORD PTR DS:[SI],0

						ADD		DX,10h	; Bring it back.

						;   ESI=Initial SS:SP (Hiword=SS, Loword=OFFSET)
						;   EDI=Initial CS:IP (Hiword=SS, Loword=OFFSET)

LOAD_EXE_OR_COM_LOADED:
						MOV		DWORD PTR CS:[EXE_INITIAL_SP],ESI
						MOV		DWORD PTR CS:[EXE_INITIAL_IP],EDI

						PUSHAD	; Pretty much all registers
						MOV		AX,CS:[PROCESS_FILE_HANDLE]
						CALL	FCLOSE
						POPAD	; Pretty much all registers

						CLC

LOAD_EXE_OR_COM_EXIT:
						MOV		CX,CS:[PROCESS_ENVSEG]
						RET

LOAD_EXE_OR_COM_ERREND:
						PUSH	AX
						MOV		AX,CS:[PROCESS_FILE_HANDLE]
						OR		AX,AX
						JE		LOAD_EXE_OR_COM_ERR_FILE_CLOSED
						CALL	FCLOSE

LOAD_EXE_OR_COM_ERR_FILE_CLOSED:
						MOV		AX,CS:[PROCESS_ENVSEG]
						OR		AX,AX
						JE		LOAD_EXE_OR_COM_ERR_ENVSEG_FREED
						MOV		ES,AX
						CALL	MFREE

LOAD_EXE_OR_COM_ERR_ENVSEG_FREED:
						MOV		AX,CS:[PROCESS_BINSEG]
						OR		AX,AX
						JE		LOAD_EXE_OR_COM_ERR_BINSEG_FREED
						MOV		ES,AX
						CALL	MFREE

LOAD_EXE_OR_COM_ERR_BINSEG_FREED:
						POP		AX
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CS:[EXE_HEADER]  1Ah byte EXE Header
;   AX=File Handle
;   DX=Load Point (Non-Zero means Overlay)
;   BX=Relocation Factor (Valid only when Load Point is non zero)
; Output
;   DX=LoadPoint
;   AX=Allocation Size (Zero if Overlay)
;   BX=Allocated Segment (Zero if Overlay)
;   ESI=Initial SS:SP (Hiword=SS, Loword=OFFSET)
;   EDI=Initial CS:IP (Hiword=SS, Loword=OFFSET)
LOAD_EXE:
						PUSH	BP

						XOR		CX,CX	; Temporarily
						XOR		DI,DI	; Temporarily
						OR		DX,DX
						JNE		LOAD_EXE_HAVE_POINTERS
						PUSH	AX
						CALL	LOAD_EXE_MALLOC
						POP		AX
						JC		LOAD_EXE_EXIT
						; CX=Allocated Segment
						; DX=LoadPoint
						; DI=Allocation Size

						MOV		BX,DX	; If not overlay, LoadPoint=RelocationFactor

LOAD_EXE_HAVE_POINTERS:
						; At this point;
						;   AX=File Handle
						;   DX=Load Point
						;   CX=Allocated Segment
						;   BX=Relocation Factor
						;   DI=Allocation Size
						PUSH	DI	; Allocation Size
						PUSH	CX	; PSP Segment
						PUSH	BX	; Reloc Factor
						PUSH	DX	; Load Point
						PUSH	AX	; File Handle

						CALL	LOAD_EXE_FREAD_BINARY
						JC		LOAD_EXE_ERROR_MIDDLE_STAGE

						POP		AX
						POP		DX
						POP		BX
						; BX Reloc Factor
						; DX Load Point
						; AX File Handle
						CALL	LOAD_EXE_RELOCATE_BINARY	; This preserves AX,BX, and DX

						POP		CX
						POP		AX	; AX is Allocation Size.  Don't need file handle any more.
						JC		LOAD_EXE_ERROR_LATE_STAGE


						;   ESI=Initial SS:SP (Hiword=SS, Loword=OFFSET)
						MOV		SI,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_INIT_SS]
						ADD		SI,BX
						SHL		ESI,16
						MOV		SI,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_INIT_SP]

						;   EDI=Initial CS:IP (Hiword=SS, Loword=OFFSET)
						MOV		DI,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_INIT_CS]
						ADD		DI,BX
						SHL		EDI,16
						MOV		DI,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_INIT_IP]

						; At this point;
						;   AX=Allocation Size
						;   DX=Load Point
						;   CX=Allocated Segment
						;   BX=Relocation Factor

						; Need to return
						;   DX=LoadPoint
						;   BX=Allocated Segment (Zero if Overlay)
						MOV		BX,CX

						CLC
LOAD_EXE_EXIT:
						POP		BP
						RET

LOAD_EXE_ERROR_MIDDLE_STAGE:
						POP		BX
						POP		BX
						POP		BX
						CALL	MFREE	; Already allocated.  Free it.
						ADD		SP,4
						XOR		BX,BX
						STC
						POP		BP
						RET

LOAD_EXE_ERROR_LATE_STAGE:
						MOV		BX,CX
						CALL	MFREE
						XOR		BX,BX
						STC
						POP		BP
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Subroutine from LOAD_EXE
;   CS:[EXE_HEADER]  1Ah byte EXE Header
;   AX=File Handle
;   DX=Load Point (Non-Zero means Overlay)
LOAD_EXE_FREAD_BINARY:
						PUSH	AX
						PUSH	DX

						XOR		BL,BL	; SEEK_SET
						MOVZX	EDX,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_HEADER_SIZE]
						SHL		DX,4
						CALL	FSEEK_BY_HANDLE

						POP		DX
						POP		BX

						JC		LOAD_EXE_FREAD_BINARY_EXIT

						MOV		AX,BX

						MOVZX	ECX,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_FILE_SIZE_DIV_512]
						SHL		ECX,9	; My FREAD is supposed to read beyond 64KB.

						SHL		EDX,16	; Make it Hiword=SEG, Loword=OFFSET (In this case OFFSET=0)

						CALL	FREAD_FROM_JFN

LOAD_EXE_FREAD_BINARY_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Subroutine from LOAD_EXE
;   CS:[EXE_HEADER]  1Ah byte EXE Header
;    AX	 File Handle
;    BX	 Reloc Factor
;    DX	 Load Point
; The original MS DOS V3.1 uses 184h-byte file-name buffer to read relocation table
; piece by piece.  I thought about using 256byte to be used for PSP, but realized
; no PSP if in overlay mode.  Also thought about temporarily allocating arena,
; but exe like RUN386.EXE and CONTROL.EXE is likely to claim entire available
; conventional memory.  Thought about Sector Buffer as well, but it is used
; for FREAD.
; Thought about expanding YSDOS Stack and use the top of stack, but that part is
; also used as DEVCALL command buffer, which means the Device Driver will write
; return code after reading data, and the data may be destroyed.
;
; Forget about it.  I made 1024-byte relocation buffer in the code segment.
LOAD_EXE_RELOCATE_BINARY:
						CMP		WORD PTR CS:[EXE_HEADER_BUFFER+EXE_RELOC_TABLE_COUNT],0
						CLC
						JE		LOAD_EXE_RELOCATE_DONE

						PUSH	AX
						PUSH	BX
						PUSH	DX

						XOR		BL,BL	; SEEK_SET
						MOVZX	EDX,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_RELOC_TABLE_OFFSET]
						CALL	FSEEK_BY_HANDLE
						; At this point, FSEEK is not supposed to fail.
						; This file handle has passed FSEEK and FREAD already.

						POP		DX
						POP		BX
						POP		AX

						MOV		DI,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_RELOC_TABLE_COUNT]

						; DI is number of reloc table entries to go.
						; Original MSDOS.SYS directly uses WORD PTR CS:[EXE_HEADER_BUFFER+EXE_RELOC_TABLE_COUNT] counter.
LOAD_EXE_RELOC_OUTER_LOOP:
						PUSH	AX
						PUSH	BX
						PUSH	DX
						PUSH	DI

						MOV		ECX,YSDOS_RELOC_BUFFER_LEN

						MOV		DX,CS
						SHL		EDX,16
						MOV		DX,OFFSET YSDOS_RELOC_BUFFER

						CALL	FREAD_FROM_JFN

						POP		DI
						POP		DX
						POP		BX
						POP		AX

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET YSDOS_RELOC_BUFFER
						MOV		CX,YSDOS_RELOC_BUFFER_LEN/4
LOAD_EXE_RELOC_INNER_LOOP:
						PUSH	AX
						PUSH	DX

						PUSH	DI

						LODSW
						MOV		DI,AX

						LODSW
						ADD		AX,DX	; Add LoadPoint
						MOV		ES,AX

						ADD		WORD PTR ES:[DI],BX	; Add Relocation Factor

						POP		DI

						POP		DX
						POP		AX

						CLC
						DEC		DI
						JE		LOAD_EXE_RELOCATE_DONE

						LOOP	LOAD_EXE_RELOC_INNER_LOOP
						JMP		LOAD_EXE_RELOC_OUTER_LOOP

LOAD_EXE_RELOCATE_DONE:
						RET




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CS:[EXE_HEADER]  1Ah byte EXE Header
; Output
;   DX=Load Point=Relocation Factor
;   CX=Segment returned by Malloc
;   DI=Allocated Size
LOAD_EXE_MALLOC:
						MOV		BX,0ffffh
						CALL	MALLOC	; This is supposed to fail and returns max available paragraphs

						CMP		BX,11h
						JBE		LOAD_EXE_MALLOC_OUT_OF_MEMORY1

						MOVZX	EAX,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_FILE_SIZE_DIV_512]
						SHL		EAX,5												; Make it DIV_16=Number of Paragraphs
						MOV		EDI,EAX		; Save binary size in EDI
						ADD		EAX,10h		; 100h bytes for PSP

						MOVZX	ECX,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_HEADER_SIZE]	; In paragraphs
						SUB		EAX,ECX

						MOVZX	EDX,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_MAX_ALLOC_PAGE]
						; MS-DOS Encycropedia pp.121
						; If Maximum Alloc Paragraphs is zero, allocate maximum available memory, and 
						; load the executable binary image at the end of the arena.
						REPLVALUE	DX,0,0FFFFh
						MOVZX	ECX,WORD PTR CS:[EXE_HEADER_BUFFER+EXE_MIN_ALLOC_PAGE]

						ADD		EDX,EAX		; Maximum paragraphs requested
						ADD		EAX,ECX		; Minimum paragraphs required
						MAKEGREATER_UNSIGNED	EDX,EAX	; In case maximum<minimum (very possible min!=0 && max==0)

						MOVZX	EBX,BX
						CMP		EAX,EBX
						JG		LOAD_EXE_MALLOC_OUT_OF_MEMORY1	; Not enough memory for minimum required

						; Now I know I have enough memory.  If possible, want EDX paragraphs, but if not up to available.
						MAKESMALLER_UNSIGNED	EBX,EDX

						; Now EBX is memory arena size to malloc.
						PUSH	BX
						CALL	MALLOC
						POP		CX	; CX is allocated size.
						JC		LOAD_EXE_MALLOC_OUT_OF_MEMORY2	; Not supposed to happen though.

						CMP		WORD PTR CS:[EXE_HEADER_BUFFER+EXE_MAX_ALLOC_PAGE],0
						JNE		LOAD_EXE_LOW_END
;LOAD_EXE_HIGH_END:
						; AX=Segment Allocated
						; BX=Requested Size
						ADD		BX,AX	; Now BX is 1 paragraph after the memory arena
						SUB		BX,DI	; BX is Load Point
						JMP		LOAD_EXE_HAVE_LOADPOINT
LOAD_EXE_LOW_END:
						MOV		BX,AX
						ADD		BX,10h	; Skip 100h bytes for PSP.

LOAD_EXE_HAVE_LOADPOINT:
						MOV		DI,CX	; DI=allocated size.
						MOV		DX,BX
						MOV		CX,AX
						CLC
						RET


LOAD_EXE_MALLOC_OUT_OF_MEMORY2:
						TSUGARU_DEBUG_BREAK	0	; Not supposed to happen

LOAD_EXE_MALLOC_OUT_OF_MEMORY1:
						MOV		AX,DOSERR_OUT_OF_MEMORY
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX=File Handle
;   DX=Load Point (Non-Zero mean Overlay mode.  Zero means need malloc.)
; Return
;   CF=0
;   DX=Load Point
;   AX=Malloc Size in Paragraphs, or zero if load point was given as input
;   BX=Segment that Malloc returned, or zero if load point was given as input
;   CF=1
;   AX=DOS Error Code
; Don't expect registers are saved.
LOAD_COM_OR_SYS:
						PUSH	BP
						PUSH	AX

						PUSh	DX
						XOR		BL,BL	; SEEK_SET
						XOR		EDX,EDX	; File Pointer
						; AX is already file handle
						CALL	FSEEK_BY_HANDLE
						POP		DX
						MOV		AX,DOSERR_BAD_FORMAT
						JC		LOAD_COM_OR_SYS_ERROR

						; Temporarily Nullify BX and AX
						XOR		AX,AX
						XOR		BX,BX

						OR		DX,DX
						JNE		LOAD_COM_SYS_LOADPOINT_GIVEN

						; Need malloc

						POP		AX
						PUSH	AX	; I still need File Handle for FREAD
						CALL	GET_FILE_SIZE
						; EBX is file size.

						MOV		AX,DOSERR_BAD_FORMAT
						JC		LOAD_COM_OR_SYS_ERROR
						MAKESMALLER_UNSIGNED	EBX,0FEF0h

						; Although I can rule out that the file is not .COM or .SYS by checking
						; file size against 64KB, I need to dummy-read anyway.  See the comment
						; below.


						ADD		BX,010Fh	; 100h bytes for PSP, 0Fh for round up.
						SHR		BX,4		; Number of paragraphs needed for loading.
						; Now BX is number of paragraphs needed

						PUSH	BX
						MOV		BX,0ffffh
						CALL	MALLOC		; THis is supposed to fail, and give max available paragraphs in BX
						POP		CX
						; CX is number of paragraphs needed

						CMP		CX,BX
						JA		LOAD_COM_SYS_OUT_OF_MEMORY

						; BX is maximum available.
						CALL	MALLOC
						JC		LOAD_COM_SYS_OUT_OF_MEMORY

						MOV		DX,AX
						ADD		DX,10h	; 10h paragraphs=100h bytes for PSP

LOAD_COM_SYS_LOADPOINT_GIVEN:
						; AX=Allocated Segment
						; BX=Number of Paragraphs Allocated
						; DX=Load Point Segment

						POP		SI	; SI is now file handle.
						PUSH	SI	; Just to keep SP consistent.
						PUSH	AX	; Allocated Segment
						PUSH	BX	; Number of Paragraphs Allocated
						PUSh	DX	; Load Point

						PUSH	SI	; I need file handle one more time for checking file size.
						MOV		AX,SI
						MOV		CX,0ffffh ; Up to 65535 bytes.
						SHL		EDX,16	  ; Hiword EDX=SEG, Loword EDX=OFFSET
						CALL	FREAD_FROM_JFN
						; I think I don't need the file handle any more.
						POP		SI
						MOV		AX,DOSERR_BAD_FORMAT
						JC		LOAD_COM_OR_SYS_ERROR_LAST_STAGE

						; If the file size is greater than 64KB, I need to dummy-read to saturate
						; SHSUCDX's sector buffer, and then return DOSERR_OUT_OF_MEMORY.
						; Why?  FM TOWNS OS V1.1 L20 and newer uses a extremely weird RAM drive
						; known as DRIVE_R.  It caches only one file RUN386.EXE in the sprite RAM.
						; It is destroyed, obviously, if an application uses sprite.
						; CONTROL.EXE re-loads DRIVE_R.IMG to the sprite RAM if INT 21H AX=4B01h
						; returns an error, and then re-try loading R:\RUN386.EXE.
						; The first INT 21H AX=4B01H tries to load it as a .COM executable because
						; the first two bytes is not "MZ".
						; It issues INT 2FH AX=1120H, Flush Buffers.  However, SHSUCDX
						; does not process it.
						; Then, since the sector from the broken drive-image is in the
						; SHSUCDX cache, the subsequent read just gives a broken data, and
						; INT 21H AX=4B01h never succeeds.
						; The solution to this problem is overwhelm the SHSUCDX's sector buffer
						; so that the next time it reads the EXE header fresh.
						; I need to make sure broken R:\RUN386.EXE is executed as a .COM
						; by checking the file size after dummy-reading and saturating the
						; buffers.

						MOV		AX,SI
						CALL	GET_FILE_SIZE
						MOV		AX,DOSERR_OUT_OF_MEMORY
						CMP		EBX,10000h
						JAE		LOAD_COM_OR_SYS_ERROR_LAST_STAGE


						; Success.
						CLC
						POP		DX	; DX is Load Point
						POP		AX	; AX is Malloc Size or zero if overlay
						POP		BX	; BX is Segment returned by Malloc or zero if overlay
						POP		BP
						POP		BP
						RET

LOAD_COM_OR_SYS_ERROR_LAST_STAGE:
						POP		DX
						POP		AX
						POP		BX ; BX is Segment returned by Malloc or zero if overlay
						OR		BX,BX
						JE		LOAD_COM_OR_SYS_ERROR
						MOV		ES,BX
						CALL	MFREE
						JMP		LOAD_COM_OR_SYS_ERROR

LOAD_COM_SYS_OUT_OF_MEMORY:
						MOV		AX,DOSERR_OUT_OF_MEMORY
LOAD_COM_OR_SYS_ERROR:
						POP		BP	; Dummy pop to skip incoming_AX
						POP		BP
						XOR		BX,BX
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS  PSP Segment (CurrentPDB for AH=31h,AH=4Ch, CallerCS for AH=00h)
;   AL  Return code
;   DX  Number of paragraphs to keep (Directly given to MREALLOC to resize Arena of PSP)
; Will not return
EXIT_PROCESS_AND_STAY_RESIDENT:
						PUSH	FS
						PUSH	GS
						PUSH_ALL_HIWORD

						MOV		AH,PROC_RETTYPE_NORMAL
						MOV		CS:[ERRORLEVEL],AX
						MOV		CS:[TERMINATION_TYPE],AH

						PUSH	DS
						PUSH	DS
						POP		ES
						MOV		BX,DX
						; Input
						;    BX=New size in number of paragraphs
						;    ES=Segment (MCB+1) to resize
						CALL	MREALLOC
						JNC		EXIT_PROC_STAY_MREALLOCED
						;    CF=1  AX=error code  BX=maxinum number of paragraphs possible for resize
						; Out of memory, but there's no way to tell.
						; MSDOS V3.1 Disassembly was doing this:
						MOV		AX,DS
						ADD		AX,BX
						MOV		DS:[PSP_ENDMEM],AX
EXIT_PROC_STAY_MREALLOCED:
						POP		DS

						CALL	RESTORE_INT222324_HANDLER
						; Returns EAX=INT 22h Vector
						MOV		CS:[PROCESS_RETURN_POINTER],EAX

						CALL	CALL_INT2FH_PROC_TERM_HOOK

						MOV		AX,DS:[PSP_CALLER_PSP_SEG]
						MOV		CS:[CurrentPDB],AX

						POP_ALL_HIWORD
						POP		GS
						POP		FS

						JMP		IRET_BACK_TO_CALLER_PSP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS  PSP Segment (CurrentPDB for AH=31h,AH=4Ch, CallerCS for AH=00h)
;   AL  Return code
; Will not return
EXIT_PROCESS_WITH_RETURNCODE:
						PUSH	FS
						PUSH	GS
						PUSH_ALL_HIWORD

						MOV		AH,PROC_RETTYPE_NORMAL
						MOV		CS:[ERRORLEVEL],AX
						MOV		CS:[TERMINATION_TYPE],AH

						CALL	RESTORE_INT222324_HANDLER
						; Returns EAX=INT 22h Vector
						MOV		CS:[PROCESS_RETURN_POINTER],EAX

						CALL	CALL_INT2FH_PROC_TERM_HOOK

						; STC if:
						;   Terminating PSP(DS)==CS:[CurrentPDB] &&
						;   CS:[CurrentPDB]!=CALLER_PSP
						CALL	STC_IF_CURRENTPDB_MUST_CHANGE
						JNC		EXIT_PROCESS_CURPDB_NO_CHANGE

						PUSH	DS
						MOV		AX,DS
						CALL	MFREE_FOR_PSP
						CALL	CLOSE_ALL_FILES_FOR_CURPDB
						CALL	CLOSE_ALL_FCB_FOR_CURPDB
						POP		DS
						MOV		AX,DS:[PSP_CALLER_PSP_SEG]
						MOV		CS:[CurrentPDB],AX

EXIT_PROCESS_CURPDB_NO_CHANGE:

						POP_ALL_HIWORD
						POP		GS
						POP		FS



IRET_BACK_TO_CALLER_PSP:
						CALL	FLUSH_BUFFERS

						MOV		BYTE PTR CS:[INDOS],0

						MOV		DS,CS:[CurrentPDB]	; Make sure to use the updated PSP
						LSS		SP,DS:[PSP_STACK_PTR]
						POP		AX
						POP		BX
						POP		CX
						POP		DX
						POP		SI
						POP		DI
						POP		BP
						POP		DS
						POP		ES

						ADD		SP,6

						PUSH	0F202h
						PUSH	DWORD PTR CS:[PROCESS_RETURN_POINTER]
						IRET	; Jump by IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS  PSP Segment (CurrentPDB for AH=31h,AH=4Ch, CallerCS for AH=00h)
; Return
;   EAX INT 22h Vector After Restored
RESTORE_INT222324_HANDLER:
						PUSH	FS
						XOR		AX,AX
						MOV		FS,AX
						MOV		EAX,DS:[PSP_INT24H]
						MOV		FS:[0024h*4],EAX
						MOV		EAX,DS:[PSP_INT23H]
						MOV		FS:[0023h*4],EAX
						MOV		EAX,DS:[PSP_INT22H]
						MOV		FS:[0022h*4],EAX	; Return INT 22h Vector
						POP		FS
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; DS=PSP
; SS=CS
CALL_INT2FH_PROC_TERM_HOOK:
						MOV		AX,INT2FH_PROC_TERM_HOOK
						INT		2Fh
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS  PSP of terminating process (Maybe different from CurrentPDB if INT 21H AH=00h)
; Return
;   ES  
STC_IF_CURRENTPDB_MUST_CHANGE:
						MOV		AX,DS				; AX is terminating PSP
						MOV		BX,CS:[CurrentPDB]	; BX is CurrentPDB
						MOV		ES,BX				; ES is CurrentPDB

						; Free memory and close files if CurrentPDB!=CALLER_PSP && CurrentPDB==Closing PSP
						; The second condition is questionable (probably the program will crash), but it is
						; as written in MS-DOS V3.0 disassembly.

						CMP		BX,ES:[PSP_CALLER_PSP_SEG]
						JE		STC_IF_CURRENTPDB_MUST_CHANGE_EXIT
						CMP		AX,BX
						JNE		STC_IF_CURRENTPDB_MUST_CHANGE_EXIT

						STC
						RET

STC_IF_CURRENTPDB_MUST_CHANGE_EXIT:
						CLC
						RET
