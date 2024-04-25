FILE_BYTES_TO_READ_WRITE	DD	0
FILE_BYTES_DID_READ_WRITE	DD	0
FILE_BYTES_INTO_SECTOR		DW	0
FILE_SECTORS_INTO_CLUSTER	DW	0
FILE_SECTORS_INTO_FILE		DD	0
FILE_CLUSTERS_INTO_FILE		DD	0
FILE_READ_WRITE_POINTER		DD	0	; Linear address
FILE_CURRENT_SECTOR			DD	0

FILE_INPUT_FILENAME			DD	0
FILE_FILENAME_2				DD	0
FILE_CUR_SFN				DB	0
FILE_CUR_JFN				DB	0
FILE_OPENMODE				DB	0

FILE_CREATE_ATTRIB			DB	0

FILE_DRIVE					DB	0	; Used in RENAME
FILE_RENAME_SRC_DIR_SECTOR	DD	0
FILE_RENAME_SRC_DIR_OFFSET	DW	0
FILE_RENAME_SRC_DIR_CLUSTER	DD	0

FILE_TRASH					DW	0	; Used for popping WORD without changing FLAGS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
;   CF=1   AL beyond NUM_CDS
;   CF=0   DS:SI=ALth CDS
; Destroys
;   AX
GET_ALth_CDS_IN_DSSI:
							CMP		AL,CS:[NUM_CDS]
							; JAE		ERROR
							CMC
							JB		GET_ALth_CDS_DSSI_EXIT
							MOV		AH,CURRENT_DIR_STRUCT_size
							MUL		AH
							LDS		SI,CS:[FIRST_CDS_PTR]
							ADD		SI,AX
GET_ALth_CDS_DSSI_EXIT:
							RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  Input file name
; Output
;   CS:FILE_NAME_BUFFER  Full-Path Name.
; This function will make a full-path name.
; I think it is fully-qualified name in DOS terminology.
; If the file name does not explicitly describe the drive, it takes from BYTE PTR CS:[CURRENT_DRIVE].
; If the file name matches one of the CHAR devices, it makes like A:/TOWNS_CD.
; The DOS apparently uses forward slash (/) for a device name, and back slash (\) for a file name.
; Don't expect registers are preserved.
MAKE_FULLPATH:
						PUSH	CS
						POP		ES
						MOV		DI,OFFSET FILENAME_BUFFER
						MOV		AX,INT2FH_QUALIFY_FILENAME
						INT		2FH
						JC		MAKE_FULLPATH_NOT_INT2F
						RET

MAKE_FULLPATH_NOT_INT2F:
						CMP		WORD PTR DS:[SI],02F2Fh ; '//' Network file name, or already qualified.
						JE		MAKE_FULLPATH_IS_BSBS
						CMP		WORD PTR DS:[SI],05C5Ch	; '\\' Network file name, or already qualified.
						JNE		MAKE_FULLPATH_NOT_BSBS

MAKE_FULLPATH_IS_BSBS:
						MOV		DI,OFFSET FILENAME_BUFFER
						CALL	KSTRNCPY_CAPS_BACKSLASH
						CLC
						RET


MAKE_FULLPATH_NOT_BSBS:
						; First copy incoming file name to FILE_NAME_BUFFER2, capitalizing 
						; and converting / to \.
						MOV		DI,OFFSET FILENAME_BUFFER2
						MOV		CX,FILENAME_BUFFER_LEN
						CALL	KSTRNCPY_CAPS_BACKSLASH

						; It can be a CHARDEV if:
						;   The second byte is not ':'
						;   The file name starts with '\DEV\'
						; But, let's worry about it later.

						PUSH	CS
						POP		DS
						; ES is already equal to CS
						MOV		SI,OFFSET FILENAME_BUFFER2
						MOV		DI,OFFSET FILENAME_BUFFER

						CMP		BYTE PTR DS:[SI+1],':'
						JNE		MAKE_FULLPATH_DRVNOTGIVEN
						MOVSW	; Copy Drive
						JMP		MAKE_FULLPATH_DRVDONE
MAKE_FULLPATH_DRVNOTGIVEN:
						MOV		AL,CS:[CURRENT_DRIVE]
						ADD		AL,'A'
						MOV		AH,':'
						STOSW

MAKE_FULLPATH_DRVDONE:
						; SI is after FILENAME_BUFFER2 or FILENAME_BUFFER2+2
						; DI is FILENAME_BUFFER+2
						; BYTE PTR CS:[FILENAME_BUFFER] is drive letter.

						CALL	MATCH_CHARDEV_DSSI
						JC		MAKE_FULLPATH_NOT_CHARDEV
						PUSH	CS
						POP		ES
						MOV		DI,OFFSET FILENAME_BUFFER+2
						MOV		AL,'/' ; CHARDEV uses forward slash
						STOSB
						MOV		CX,8
						CALL	STRNCPY

						; It at least needs CURRENT_CDS_STRUCT be set.
						; TSUGARU_DEBUG_BREAK 0

						CLC
						RET

MAKE_FULLPATH_NOT_CHARDEV:
						; Full-Path or Rel-Path?
						CMP		BYTE PTR DS:[SI],'\'
						JNE		MAKE_FULLPATH_IS_RELPATH

						; Full-path name given.
						MOV		CX,FILENAME_BUFFER_LEN-2
						CALL	STRNCPY
						JMP		MAKE_FULLPATH_CRUNCHDOT

MAKE_FULLPATH_IS_RELPATH:
						; Get to the CDS
						PUSH	DS
						PUSH	SI
						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	GET_ALth_CDS_IN_DSSI
						POP		EAX	; DS:SI is preserved in EAX
						JB		MAKE_FULLPATH_DIR_NOT_FOUND

						MOV		DI,OFFSET FILENAME_BUFFER
						MOV		CX,FILENAME_BUFFER_LEN
						CALL	STRNCPY ; Returns number of chars copied.
						ADD		DI,CX
						CMP		BYTE PTR ES:[DI-1],'\'
						JE		MAKE_FULLPATH_IS_RELPATH_2
						MOV		WORD PTR ES:[DI],005Ch ; '\' and '\0'
						INC		CX

MAKE_FULLPATH_IS_RELPATH_2:
						MOV		SI,AX
						SHR		EAX,16
						MOV		DS,AX

						MOV		DI,OFFSET FILENAME_BUFFER
						ADD		DI,CX ; Where RELPATH must be appended
						NEG		CX
						ADD		CX,FILENAME_BUFFER_LEN

						CALL	STRNCPY

MAKE_FULLPATH_CRUNCHDOT:


						CLC
						RET



MAKE_FULLPATH_DIR_NOT_FOUND:
						MOV		AX,DOSERR_DIR_NOT_FOUND
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  File Name
; Output
;   CF=0  CS:[FILENAME_BUFFER] Full Path Name
; Make full path name and crunch "." and "..", but not expand to lesser wildcard.
MAKE_FULLPATH_CRUNCH:
						PUSH	CS
						POP		ES
						MOV		DI,OFFSET FILENAME_BUFFER
						CALL	MAKE_FULLPATH
						JB		MAKE_FULLPATH_CRUNCH_EXIT

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER
						CALL	CRUNCH_FILEPATH

MAKE_FULLPATH_CRUNCH_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  File Name
; Output
;   CF=0  CS:[FILENAME_BUFFER] Full Path Name
MAKE_FULLPATH_CRUNCH_LESSERWC:
						CALL	MAKE_FULLPATH_CRUNCH
						JB		MAKE_FULLPATH_CRUNCH_LESSERWC_EXIT

						CALL	FULLPATH_TO_LESSER_WILDCARD

						CLC

MAKE_FULLPATH_CRUNCH_LESSERWC_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
;  AL Drive Number (0=ADrive)
DRIVE_NUMBER_FROM_FILENAME_BUFFER:
						CALL	DRIVE_LETTER_FROM_FILENAME_BUFFER
						SUB		AL,'A'
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
;  AL=Alphabetical drive letter, or 0ffh if unidentified.
DRIVE_LETTER_FROM_FILENAME_BUFFER:
						CMP		BYTE PTR CS:[FILENAME_BUFFER+1],':'
						JE		REGULAR_FULLPATH_NAME
						CMP		WORD PTR CS:[FILENAME_BUFFER],05C5Ch  ; \\  It can be \\Q.A. format
						JE		REDIRECTED_FULLPATH_NAME
						CMP		WORD PTR CS:[FILENAME_BUFFER],02F2Fh  ; //  It can be //Q.A. format
						JE		REDIRECTED_FULLPATH_NAME
						MOV		AL,0ffh
						RET

REDIRECTED_FULLPATH_NAME:
						MOV		AL,CS:[FILENAME_BUFFER+2]
						RET
REGULAR_FULLPATH_NAME:
						MOV		AL,CS:[FILENAME_BUFFER]
						RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input:
;   DS:SI  Full Path Name
; Return:
;   CF=1  Too many ..s
; Crunch "\.\" to "\", "\*\..\" to "\"
CRUNCH_FILEPATH:
						PUSH	ES

						PUSH	DS
						POP		ES

						MOV		BX,SI		; Remember where to begin.

CRUNCH_FILEPATH_STARTOVER:
						MOV		DX,0ffffh	; Ptr to Last Seen '\'

CRUNCH_FILEPATH_LOOP:
						MOV		EAX,DS:[SI]
						JMP_IF_KANJI	AL,CRUNCH_FILEPATH_KANJI

						OR		AL,AL
						JE		CRUNCH_FILEPATH_EXIT

						CMP		EAX,5C2E2E5Ch	; '\..\'
						JE		CRUNCH_FILEPATH_DOUBLE
						CMP		EAX,002E2E5Ch	; '\..0'
						JE		CRUNCH_FILEPATH_DOUBLE

						AND		EAX,0ffffffh
						CMP		EAX,5C2E5Ch		; '\.\'
						JE		CRUNCH_FILEPATH_SINGLE
						CMP		EAX,002E5Ch		; '\.0'
						JE		CRUNCH_FILEPATH_SINGLE

						CMP		AL,'\'
						JNE		CRUNCH_FILEPATH_NEXT
						MOV		DX,SI

CRUNCH_FILEPATH_NEXT:
						ADD		SI,1
						JMP		CRUNCH_FILEPATH_LOOP

CRUNCH_FILEPATH_KANJI:
						ADD		SI,2
						OR		AH,AH
						JNE		CRUNCH_FILEPATH_LOOP

CRUNCH_FILEPATH_EXIT:
						MOV		SI,BX
						CALL	RECOVER_ROOT_AFTER_CRUNCH
						CLC
						POP		ES
						RET

CRUNCH_FILEPATH_ERROR:
						MOV		SI,BX
						CALL	RECOVER_ROOT_AFTER_CRUNCH
						STC
						POP		ES
						RET


CRUNCH_FILEPATH_SINGLE:
						MOV		AX,SI
						MOV		DI,SI
						ADD		SI,2
						CALL	STRCPY
						MOV		SI,AX
						JMP		CRUNCH_FILEPATH_LOOP

CRUNCH_FILEPATH_DOUBLE:
						; Because of Kanji, it needs to start over
						; from the beginning of the string :-P
						CMP		DX,0ffffh
						JE		CRUNCH_FILEPATH_ERROR
						ADD		SI,3
						MOV		DI,DX
						CALL	STRCPY
						MOV		SI,BX
						JMP		CRUNCH_FILEPATH_STARTOVER



RECOVER_ROOT_AFTER_CRUNCH:
						CMP		WORD PTR DS:[SI+1],003AH
						JNE		RECOVER_ROOT_AFTER_CRUNCH_EXIT
						MOV		WORD PTR DS:[SI+2],005CH
RECOVER_ROOT_AFTER_CRUNCH_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  Path with all slash and caps
; Output
;   File name will be converted to lesser wildcard (looser matching, no '*')
;   DL     0 no conversion  0FFh converted
; Uses TEMP_16CHAR_BUFFER
; Will not do anything if the last \ is beyond 115 bytes into the string.
FULLPATH_TO_LESSER_WILDCARD:
						MOV		DL,0
						CALL	SEEK_LAST_BACKSLASH	; -> DS:DI is PTR to last slash
						MOV		AL,DS:[DI]
						JMP_IF_NOT_SLASH	AL,FULLPATH_TO_LESSER_WILDCARD_EXIT

						INC		DI		; SKIP '/' or '\'
						MOV		CX,DI
						SUB		CX,SI
						CMP		CX,MAX_PATH-12
						JGE		FULLPATH_TO_LESSER_WILDCARD_EXIT

						XCHG	SI,DI
						PUSH	CS
						POP		ES
						MOV		DI,OFFSET TEMP_16CHAR_BUFFER
						CALL	MAKE_LESSER_WILDCARD
						OR		DL,DL
						JE		FULLPATH_TO_LESSER_WILDCARD_EXIT

						XCHG	SI,DI
						XCHGSTACK	ES,DS
						CALL	STRCPY

FULLPATH_TO_LESSER_WILDCARD_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  GS:BP  DPB
;  EAX    File Size
;Output
;  EAX    Cluster Size
;  ECX,EDX    Destroyed
FILE_SIZE_TO_CLUSTER_SIZE:
							MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
							ADD		EAX,ECX
							DEC		EAX		; Round up a sector

							XOR		EDX,EDX
							DIV		ECX

							; EAX is number of sectors

							MOVZX	EDX,BYTE PTR GS:[BP+DPB_CLUSTER_MASK]
							ADD		EAX,EDX	; Round up a cluster

							MOV		CL,GS:[BP+DPB_CLUSTER_SHIFT]
							SHR		EAX,CL

							RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  FS:DI  SF_ENTRY
;Output
;  GS:BP  DPB
;  CS:[FILE_BYTES_TO_READ_WRITE]  Populated
;  CS:[FILE_BYTES_INTO_SECTOR]    Populated
;  CS:[FILE_SECTORS_INTO_FILE]    Populated
;  CS:[FILE_CLUSTERS_INTO_FILE]   Populated
;  EAX,ECX,EDX destroyed
FILE_PREP_RW_BLOCKDEV	PROC
						LGS		BP,FS:[DI+SF_DRIVER_POINTER]
						; SF_DRIVER_POINTER is DPB if BLOCKDEV (not CHARDEV)

						MOV		EAX,FS:[DI+SF_FILE_POINTER]	; Bytes into file
						XOR		EDX,EDX
						MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						DIV		ECX

						MOV		CS:[FILE_BYTES_INTO_SECTOR],DX  ; EDX is current bytes into sector, but never be greater than sector size.
						MOV		CS:[FILE_SECTORS_INTO_FILE],EAX ; EAX is sectors into file

						MOV		EDX,EAX ;EDX is also sectors into file.
						AND		AL,BYTE PTR GS:[BP+DPB_CLUSTER_MASK]
						XOR		AH,AH
						MOV		CS:[FILE_SECTORS_INTO_CLUSTER],AX
						MOV		CL,GS:[BP+DPB_CLUSTER_SHIFT]
						SHR		EDX,CL
						MOV		CS:[FILE_CLUSTERS_INTO_FILE],EDX

						MOV		DWORD PTR CS:[FILE_BYTES_DID_READ_WRITE],0

						RET
FILE_PREP_RW_BLOCKDEV	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; FCLOSE
; Input
;     AX   JFN
; Return
;     CF=0  Successful
;     CF=1  AX is error code
; Pretty much every registers are destroyed.
;int fclose(JFN) ; JFN is 0 to 19(13h), pointing to an SFN in the PDB.
;{
;	auto &sf=GetSFfromJFN(JFN);
;	if(sf is invalid || sf.machineNumber!=machineNumber) // What's the hell is this machine number???
;	{
;		return DOSERR_INVALID_HANDLE;
;	}
;
;	if((sf.mode&0xF0)==0x70)
;	{
;		CurrentPDB.SFN[JFN]=FILE_NOT_OPEN;
;	}
;
;	// 1679:34CE
;;	if(sf.type==INT2FDevice)
;;	{
;;		return INT2FClose(fp);
;;	}
;	else
;	{
;		if((sf.devflags&0x4000)==0 || (sf.devflags&0xC0)==0)
;		{
;			// 04000h: Block Device DATE/TIME Set
;			// 040h: Block Device: Unchanged
;			// 080h: Is CHARDEV
;			sf.time=CurrentTime();
;			sf.date=CurrentDate();
;			CALL CS:[0094h] with AX=0;  What's the hell is this?
;		}
;
;		prevRefCount=sf.refCount;  // Is it necessary?  Probably not.  Just delete by one.
;		--sf.refCount;
;		if(0==sf.refCount)
;		{
;			sf.refCount=-1;
;		}
;
;		// Don't write DIRENT back if is a CHARDRV or UNCHANGED.
;		if((0x00C0&sf.devFlags)==0) // Is a block device && changed.
;		{
;			// 040h: Block Device: Unchanged
;			// 080h: Is CHARDEV
;			CALLF CS:[0064H]; // What's the hell is this?
;
;			if(DriveNotReady(sf.drive))
;			{
;				return DOSERR_INVALID_DRIVE;
;			}
;
;		This part probably is re-used from other functions >>
;			if(MediaCheck returned error) // 1679:540C
;			{
;				return DOSERR_ACCESS_DENIED;
;			}
;			if((BYTE)returncode from media check or DPB.AccessFlag is minus)
;			// According to https://sites.google.com/site/pcdosretro/dostables
;			// Returncode from media check (DEVREQ+0Eh): 1=unchanged, 0=unknown, -1=changed,
;			// Access flag is 00=accessed, FF=not accessed.
;			{
;				// 1679:54B2
;				Get One Sector Buffer (if (DEVFLAG&0x2000h)==0, read the first FAT sector at 1679:54E6.  Is it mandatory?)
;				// 0x2000h is DEVFLAG_MEDIA_DESC_IN_FAT_REQUIRED
;				// If Media Descriptor is required, FAT sector is unknown until media type is know.
;				// therefore it doesn't make sense to read the FAT sector in here.
;				// If Media Descriptor is not required, DPB can tell where the first FAT sector is.
;				Build BPB by CALL SETDPB // 1679:5502
;				if(error)
;				{
;					return DOSERR_ACCESS_DENIED;
;				}
;				Copy NUM_FAT and SECTORS_PER_FAT to the used Sector Buffer.
;			}
;			else if(returncode from media check or DPB.AccessFlag is non zero)
;			{
;				// Accessed but status unknown.
;				// 1679:5455
;			}
;			else
;			{
;				// 1679:5494
;			}
;		This part probably is re-used from other functions <<
;
;			dpb.AccessedFlag=0ffh
;
;			sectorBufPtr=GetDirectorySector(sf);
;			dirEntPtr=GetDirectoryEntry(sectorBufPtr,sf); // In it, take buffer, populate buffer, then point to the location
;			if(Error Reading Directory)
;			{
;				return DOSERR_ACCESS_DENIED;
;			}
;
;			if(MatchFile(sf.fileName,dirEntPtr->fileName))
;			{
;				// 1679:351F
;				if(At least one of DIR,SYS,HID flags was turne off (1 in DIRENT, 0 in SF_ENTRY))
;				{
;					return DOSERR_FILE_NOT_FOUND;
;				}
;
;				dirEntPtr->attr|=SF_ATTR_ARCHIVE;
;				dirEntPtr->date=sf->date;
;				dirEntPtr->time=sf->time;
;				dirEntPtr->size=sf->size;
;				dirEntPtr->firstCluster=sf->firstCluster;
;				sectorBufPtr->flags|=IO_BUF_FLAG_WRITTEN; // Same as dirty.
;
;				if(Write All Dirty Buffers of the drive returns an error)
;				{
;					if(true!=(sf.devFlags&IS_INT2F_DEVICE) // This cond is checked in DEVCALL_CLOSE_SF
;					{
;						DEVCALL_CLOSE(sf);
;						sf.refCount=prevRefCount-1;
;					}
;					return DOSERR_ACCESS_DENIED;
;				}
;			}
;			else
;			{
;				return DOSERR_FILE_NOT_FOUND;
;			}
;		}
;		if(true!=(sf.devFlags&IS_INT2F_DEVICE) // This cond is checked in DEVCALL_CLOSE_SF
;		{
;			DEVCALL_CLOSE(sf);
;			sf.refCount=prevRefCount-1;
;		}
;		return DOSERR_NOERROR;
;	}
;}
FCLOSE					PROC
						PUSH	AX
						CALL	GET_SF_ENTRY_FROM_JFN
						POP		BX
						JC		FCLOSE_INVALID_HANDLE
						; FS:DI is SF_ENTRY

						MOV		AH,BYTE PTR FS:[DI+SF_MODE]
						AND		AH,0F0h
						CMP		AH,070h
						JE		CLOSE_SF_DONT_MARK_CLOSED

						MOVZX	BX,BL	; Just in case.  BX=JFN
						MOV		BYTE PTR GS:[PSP_FILE_TABLE+BX],FILE_NOT_OPEN
CLOSE_SF_DONT_MARK_CLOSED:

						CALL	CLOSE_SF
						; Just take CF and Error Code from CLOSE_SF
						RET

FCLOSE_INVALID_HANDLE:
						MOV		AX,DOSERR_INVALID_HANDLE
						STC
						RET
FCLOSE					ENDP



; Input
;   FS:DI  SF_ENTRY
; Return
;   CF=0   Successful
;   CF=1   AX=Error Code
; Registered destroyed.
CLOSE_SF				PROC
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_REDIRECTED
						JE		CLOSE_SF_NOT_INT2F
						MOV		AX,INT2F_CLOSE
						PUSH	FS
						POP		ES
						INT		2FH
						RET


CLOSE_SF_NOT_INT2F:
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_BLOCK_NOT_WRITTEN+SF_DEVFLAG_BLOCK_TIME_SET+SF_DEVFLAG_IS_CHARDEV
						JNE		CLOSE_SF_DONT_SET_DATETIME

						CALL	READ_CLOCK_FOR_DIRENT
						MOV		FS:[DI+SF_TIME],DX
						MOV		FS:[DI+SF_DATE],AX

						; XOR		AX,AX
						; CALLF		CS:[0094H]	; Meaning unknown

CLOSE_SF_DONT_SET_DATETIME:


						DEC		WORD PTR FS:[DI+SF_REFCOUNT]
						; The original MSDOS.SYS decrements refcount, and if it becomes
						; zero it temporarily store 0FFFFh.  But, I don't know why it is
						; necessary.


						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_BLOCK_NOT_WRITTEN+SF_DEVFLAG_IS_CHARDEV
						JNE		CLOSE_SF_NOERROR



						; There was a WRITE.
						LGS		BP,FS:[DI+SF_DRIVER_POINTER]	; It's a BLOCK device, therefore, GS:BP is a DPB.
						MOV		ESI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						MOV		AL,GS:[BP+DPB_UNIT_CODE]
						MOV		AH,GS:[BP+DPB_MEDIA_DESC_TYPE]
						CALL	DEVCALL_MEDIACHECK
						MOV		BH,AH	; BH is return code from Media Check 1=unchanged, 0=unknown, -1=changed.
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		CLOSE_SF_ERROR
						MOV		AX,DOSERR_NOT_SAME_DRIVE		; Is this the right code?
						; There is a possibility that the disk was removed for short time and then put back in.
						; To support those case, if the disk was changed, force-read the directory sector and
						; check if the directory entry still exists.
						AND		BH,BH
						JS		CLOSE_SF_DISK_CHANGE
						; Apparently Floppy Disk returns Changed/Unchanged unknown (in here BH=0)
						; if Volume Label and Media Type matches even when disk was not changed.
						; So, this point I can only say disk changed for sure if BH<0.


						; Supposed to be already done in fopen.
						MOV		BYTE PTR GS:[BP+DPB_ACCESS_FLAG],DPB_ACCESS_FLAG_ACCESSED


						CALL	GET_DIRENT_POINTER
						; DS:SI is directory entry.
						; DS:DX is the buffer information header.
						ADD		DI,SF_FILENAME
						; DS:SI is file name in the directory entry.
						PUSH	FS
						POP		ES
						CALL	COMPARE_FILENAME_EXACT	; CX destroyed, DF=0
						MOV		AX,DOSERR_FILE_NOT_FOUND;
						JNE		CLOSE_SF_ERROR
						SUB		DI,SF_FILENAME
						;DS:SI is directory entry again.


						; If at least one of Hidden, System, or Directory flag is turned off (1 in DIRENT, but 0 in SF_ENTRY) somehow,
						; return DOSERR_FILE_NOT_FOUND;
						; Shouldn't it be flag changed?  Not turned off?
						MOV		AL,FS:[DI+SF_ATTR]
						NOT		AL
						AND		AL,DS:[SI+DIRENT_ATTR]
						AND		AL,DIRENT_ATTR_HIDDEN+DIRENT_ATTR_SYSTEM+DIRENT_ATTR_DIRECTORY
						MOV		AX,DOSERR_FILE_NOT_FOUND;
						JNE		CLOSE_SF_ERROR


						; Still DS:DX is the buffer information header of the directory.
						OR		BYTE PTR DS:[SI+DIRENT_ATTR],DIRENT_ATTR_ARCHIVE
						MOV		EBX,DWORD PTR FS:[DI+SF_TIME]	; TIME and DATE
						MOV		DWORD PTR DS:[SI+DIRENT_TIME],EBX
						MOV		EBX,DWORD PTR FS:[DI+SF_FILE_SIZE]
						MOV		DWORD PTR DS:[SI+DIRENT_FILE_SIZE],EBX
						MOV		BX,WORD PTR FS:[DI+SF_FIRST_CLUSTER_NUM]
						MOV		WORD PTR DS:[SI+DIRENT_FIRST_CLUSTER],BX

						MOV		SI,DX
						; Now DS:SI is the buffer information header of the directory.
						OR		BYTE PTR DS:[SI+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN


						; Now flush all pending written buffer.
						MOV		AL,GS:[BP+DPB_DRIVE_CODE]
						PUSH	FS	; Was missing and added 2021/03/29.  I don't know why subsequent DEVCALL_CLOSE_SF was working.
						PUSH	DI
						CALL	FLUSH_BUFFERS_DRIVE
						POP		DI
						POP		FS
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		CLOSE_SF_ERROR



CLOSE_SF_NOERROR:
						CALL	DEVCALL_CLOSE_SF
						MOV		AX,DOSERR_NO_ERROR
						RET

CLOSE_SF_DISK_CHANGE:
						MOV		DWORD PTR DS:[PREVIOUS_DISK_LABEL],ESI
CLOSE_SF_ERROR:
						STC
						RET

CLOSE_SF				ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX=File Handle (JFN)
;   BL=Mode (0:SEEK_SET 1:SEEK_CUR 2:SEEK_END)
;   EDX=Signed Offset
; Registers destroyed.
FSEEK_BY_HANDLE:
						PUSH	BX
						CALL	GET_SF_ENTRY_FROM_JFN
						POP		BX
						JC		FSEEK_FILE_NOT_FOUND
						; FS:DI is SF_ENTRY
						CALL	FSEEK
						RET
FSEEK_FILE_NOT_FOUND:
						MOV		AX,DOSERR_FILE_NOT_FOUND
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   FS:DI=SF_ENTRY
;   BL=Mode (0:SEEK_SET 1:SEEK_CUR 2:SEEK_END)
;   EDX=Signed Offset
; Output
;   EDX=New File Position
; Registers destroyed.
FSEEK:
						OR		BL,BL
						JE		FSEEK_SET
						DEC		BL
						JE		FSEEK_CUR
						DEC		BL
						JNE		FSEEK_INVALID_FUNC
;FSEEK_END:
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						JE		FSEEK_END_NORMAL

						MOV		AX,FS:[DI+SF_MODE]
						AND		AL,0F0h
						CMP		AL,030h
						JE		FSEEK_END_REDIRECT
						CMP		AL,040h
						JE		FSEEK_END_REDIRECT

FSEEK_END_NORMAL:
						ADD		EDX,FS:[DI+SF_FILE_SIZE]
						MOV		FS:[DI+SF_FILE_POINTER],EDX
						CLC
						RET

FSEEK_END_REDIRECT:
						; For some reason INT 2FH has SEEK_FROM_END, but not SEEK_FROM_SET and SEEK_FROM_CUR.
						; I don't know what history behind it.
						; If INT2FFile && (mode&0xF0)!=40h && (mode&0xF0)!=30h
						SHLD	ECX,EDX,16
						PUSH	FS
						POP		ES
						MOV		AX,INT2FH_SEEK_FROM_END
						INT		2Fh

						SHL		EDX,16
						MOV		DX,AX
						RET

FSEEK_SET:
						MOV		FS:[DI+SF_FILE_POINTER],EDX
						CLC
						RET

FSEEK_CUR:
						ADD		EDX,FS:[DI+SF_FILE_POINTER]
						MOV		FS:[DI+SF_FILE_POINTER],EDX
						CLC
						RET

FSEEK_INVALID_FUNC:
						MOV		AX,DOSERR_INVALID_FUNC
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input:
;   AX=File Handle (JFN)... What does JFN stand for?
; Return:
;   EBX=File Size
;   FS:DI=SF_TABLE
; ES,DX,and AX preserved.  Other no guarantee.
GET_FILE_SIZE:
						PUSH	AX
						CALL	GET_SF_ENTRY_FROM_JFN
						POP		AX
						JC		GET_FILE_SIZE_ERROR
						MOV		EBX,FS:[DI+SF_FILE_SIZE]
GET_FILE_SIZE_ERROR:
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;FREAD
;  If from BLOCK device, it does not care 0d0a or 0d.  It just do binary-read.
;// 1679:00006630
;FREAD_FROM_JFN(length,buf,jfn) // Return number of bytes read.
;{
;	bytesRead=0;
;
;	sf=get_sf_from_jfn(jfn);
;	if(sf==invalid || machineId!=sf.machineId)
;	{
;		return lastError=DOSERR_INVALID_HANDLE,bytesRead=0;
;	}
;   return FREAD(sf);
;}
; Input
;     AX     JFN
;     ECX    Bytes to read (CAUTION! Hiword Valid! Can read more than 64KB!  Mask ECX if not intended!)
;     EDX    Data Pointer (Hiword is SEG, and Loword is OFFSET)
; Return
;     ECX    Number of bytes read
;     CF=0   Successful  AX destroyed.
;     CF=1   AX is error code
; Pretty much every registers are destroyed.
; DS Destroyed from GET_NEXT_CLUSTER
FREAD_FROM_JFN:
						CALL	GET_SF_ENTRY_FROM_JFN
						JC		FREAD_FROM_JFN_ERROR

						; FS:DI is SF_ENTRY
						; I don't think JFN is relevant once I have FS_ENTRY.

						MOV		BX,CS:[MACHINE_NUMBER]
						CMP		BX,FS:[DI+SF_MACHINE_NUMBER]
						JNE		FREAD_FROM_JFN_ERROR

						CALL	FREAD
						RET
FREAD_FROM_JFN_ERROR:
						MOV		AX,DOSERR_INVALID_HANDLE
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;FREAD(length,buf,sf)
;{
;	DMAPtr=buf; // Needed for INT 2FH device.
;
;	// 1679:000037EB
;	if(sf.mode==WriteMode)  // WriteMode=1
;	{
;		return lastError=DOSERR_ACCESS_DENIED,bytesRead=0;
;	}
;
;	bufEnd=buf+length;
;	bytesInfoFile=0;
;	bytesIntoSector=0;
;	sectorsIntoFile=0;
;	sectorsIntoCluster=0;
;	clustersIntoFile=0;
;	if(0==(sf.devflags&(SF_DEVFLAG_REDIRECTED|SF_DEVFLAG_CHARDEV)))
;	{
;		dpb=sf.driver_pointer;
;		bytesIntoFile=sf.file_pointer;
;		bytesIntoSector=bytesInfoFile%dpb.bytesPerSector;
;		sectorsIntoFile=bytesInfoFile/dpb.bytesPerSector;
;		sectorsIntoCluster=sectorsIntoFile&dpb.clusterMask;
;		clustersIntoFile=sectorsIntoFile/dpb.clusterShift;
;	}
;
;	if(0!=(sf.devFlags&SF_DEVFLAG_REDIRECTED)
;	{
;		// Don't forget FS->ES
;		return INT2FH(AH=1108H);
;	}
;
;	if(0==(sf.devFlags&SF_DEVFLAG_IS_CHARDEV))
;	{
;		// Block Device
;		bytesAvailable=sf.file_size-sf.file_pointer;
;		if(bytesAvailable<=0)
;		{
;			goto EOF;
;		}
;		bytesToRead=min(bytesRequested,bytesAvailable);
;		pointerAfterLastByte=sf.file_pointer+bytesToRead; // For this fread
;
;		currentSector=sf.file_pointer/dpb.bytesPerSector;
;		lastSector=(pointerAfterLastByte-1)/dpb.bytesPerSector;
;		bytesFromCurrentSector=sf.file_position%dpb.bytesPerSector;
;		bytesFromLastSector=pointerAfterLastByte%dpb.bytesPerSector
;		numWholeReadSector=(pointerAfterLastByte-bytesFromLastSector-sf.file_pointer)/dpb.bytesPerSector;
;		if(currentSector==lastSector)
;		{
;			bytesFromLastSector=0;
;			numWholeReadSector=0;
;		}
;		if(currentCluster=SeekToCurrentCluster(sf,dpb)) // SeekToCurrentCluster 1679:4A75h
;		{
;			DoRead();
;			sf.file_pointer+=bytesRead;
;		}
;		else
;		{
;			return lastError=DOSERR_NO_ERROR,bytesRead=0;
;		}
;	}
;	else
;	{
;		// Char Device
;		if(EOF on input or NUL device)
;		{
;			bytesRead=0;
;			lastError=DOSERR_NO_ERROR;
;			return bytesRead;
;		}
;		if(Binary)
;		{
;			Just Regular Read.
;			// Not fully understood the error handling.
;		}
;		if(Not Binary and Not Cons In)
;		{
;			while(bytesRead<requestedBytes)
;			{
;				CheckForCtrlC();
;				c=ReadOneByte();
;				if(NothingReturned) // Returned number of bytes is 0
;				{
;					lastError=DOSERR_NO_ERROR;
;					return bytesRead;
;				}
;				push_back(c)
;				if(c==3/*CtrlC*/ || error)
;				{
;					return lastError=DOSERR_NO_ERROR,bytesRead=0;
;				}
;				if(c==0dh/*return*/ || c==1ah/*EOF*/)
;				{
;					break;
;				}
;			}
;		}
;		else
;		{
;			// Not fully understood.  Especially meaning of [0022h]
;		}
;	}
;
;	// Regular Block or Char Device
;	// 1679:0000380E
;
;	return lastError=DOSERR_NO_ERROR,bytesRead;
;
;EOF:
;	// 1679:3EC4
;}
;Input
;  FS:DI  SF_ENTRY
;  ECX    Bytes to read (CAUTION! Hiword Valid! Can read more than 64KB!  Mask ECX if not intended!)
;  EDX    Data Pointer (Hiword is SEG, and Loword is OFFSET)
; Return
;     ECX    Number of bytes read
;     CF=0   Successful  AX destroyed.
;     CF=1   AX is error code
; Pretty much every registers are destroyed.
; DS Destroyed from GET_NEXT_CLUSTER
FREAD					PROC

						MOV		AX,DOSERR_ACCESS_DENIED;
						MOV		BX,FS:[DI+SF_MODE]
						AND		BX,0Fh
						CMP		BX,SF_MODE_WRITE	; Needs to be Read or Read/Write
						JE		FREAD_ERROR_END

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_REDIRECTED
						JE		FREAD_NOT_REDIRECTED
;FREAD_REDIRECTED:
						SEGOFF2LINEAR_EDX
						MOV		CS:[FILE_READ_WRITE_POINTER],EDX
						MOV		CS:[FILE_BYTES_TO_READ_WRITE],ECX
						MOV		DWORD PTR CS:[FILE_BYTES_DID_READ_WRITE],0

						PUSH	FS
						POP		ES ; ES:DI is SF_ENTRY
FREAD_REDIRECTED_LOOP:
						MOV		ECX,CS:[FILE_BYTES_TO_READ_WRITE]
						MAKESMALLER_UNSIGNED	ECX,0F000h

						MOV		AX,INT2FH_FREAD
						MOV		EDX,CS:[FILE_READ_WRITE_POINTER]
						LINEAR2SEGOFF_EDX
						MOV		DWORD PTR CS:[DMA_BUFFER_PTR],EDX
						PUSH	ES
						PUSH	DI	; Just in case
						INT		2FH
						POP		DI
						POP		ES
						JC		FREAD_REDIRECTED_ERROR

						MOVZX	ECX,CX	; Just in case
						JCXZ	FREAD_REDIRECTED_EOF

						ADD		CS:[FILE_BYTES_DID_READ_WRITE],ECX
						ADD		CS:[FILE_READ_WRITE_POINTER],ECX
						SUB		CS:[FILE_BYTES_TO_READ_WRITE],ECX
						JA		FREAD_REDIRECTED_LOOP
FREAD_REDIRECTED_EOF:
						CLC
FREAD_REDIRECTED_ERROR:
						MOV		ECX,CS:[FILE_BYTES_DID_READ_WRITE]
						RET


FREAD_NOT_REDIRECTED:
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						JNE		FREAD_FROM_CHARDEV



;FREAD_FROM_BLOCKDEV:
						MOV		WORD PTR CS:[FILE_READ_WRITE_POINTER],DX
						MOV		WORD PTR CS:[FILE_READ_WRITE_POINTER+2],0
						SHR		EDX,16
						SHL		EDX,4
						ADD		CS:[FILE_READ_WRITE_POINTER],EDX

						MOV		EBX,FS:[DI+SF_FILE_SIZE]
						SUB		EBX,FS:[DI+SF_FILE_POINTER]
						JBE		FREAD_EOF	; Nothing to read

						; EBX is available bytes for read.
						; MOVZX	ECX,CX
						CMP		ECX,EBX
						JBE		FREAD_BLOCKDEV_HAVE_BYTES_TO_READ
						MOV		ECX,EBX
FREAD_BLOCKDEV_HAVE_BYTES_TO_READ:
						; ECX is actual bytes to read.
						MOV		CS:[FILE_BYTES_TO_READ_WRITE],ECX


						CALL	FILE_PREP_RW_BLOCKDEV
						; GS:BP is DPB.
						; Parameters populated.
						; EAX,ECX,EDX Destroyed.


						; This section is almost same as FWRITE >>

						; Need to get to the first sector.
						; If the current pointer is after the known location, move forward,
						; or get from zero.
						MOV		ECX,CS:[FILE_CLUSTERS_INTO_FILE] ; Want to support 32-bit FAT eventually....
						CALL	GET_CLUSTERS_INTO_FILE
						MOV		AX,DOSERR_INVALID_HANDLE	; Original DOS fires INT 24H.  I just make it a regular read error.
						JB		FREAD_ERROR_END

						;   CF=0   DX=Cluster CXth cluster of the file
						CMP		DX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JAE		FREAD_EOF					; I think it's not supposed to happen, but... let it go.


						; DX is also written in FS:[DI+SF_CUR_ABS_CLUSTER_NUM]
						; Good to go.

						;   GS:BP  Drive Parameter Block
						;   DX     Cluster
						CALL	CLUSTER_TO_SECTOR
						; EBX is data sector
						; EAX,CL are destroyed
						; Sector is 16-bit in DPB.  What about a large hard drive? -> Sector must be relative to UNIT's first sector.

						; Add sectors into cluster to get the exact sector.
						ADD		BX,CS:[FILE_SECTORS_INTO_CLUSTER]
						MOV		CS:[FILE_CURRENT_SECTOR],EBX

						; Read hanging bytes from the first sector
						TEST	WORD PTR CS:[FILE_BYTES_INTO_SECTOR],0ffffh
						JE		FREAD_CLUSTER_BOUNDARY



						PUSH	DI
						PUSH	EBX
						; There are hanging bytes from the first sector
						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						XOR		AL,AL
						MOV		DX,BX
						CALL	GETBUFFER_REGULAR
						;   DS:DI  Buffer
						;   AX     Destroyed
						;   DX     Destroyed
						;   Hiword EDI  Destroyed
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FREAD_ERROR_END

						MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						MOV		BX,CS:[FILE_BYTES_INTO_SECTOR]
						SUB		CX,BX

						MAKESMALLER_UNSIGNED	ECX,CS:[FILE_BYTES_TO_READ_WRITE]

						MOV		EAX,ECX  ; Save in EAX
						LEA		SI,[DI+IO_BUF_INFO_size+BX]
						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						SHR		EDI,4
						MOV		ES,DI
						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						AND		DI,0fh
						CALL	UTIL_REP_MOVS	; DS:[SI]->ES:[DI], CX bytes

						POP		EBX
						POP		DI

						; EAX number of bytes transferred
						; EBX current sector


						; Move pointers forward
						ADD		FS:[DI+SF_FILE_POINTER],EAX
						ADD		CS:[FILE_READ_WRITE_POINTER],EAX
						ADD		CS:[FILE_BYTES_DID_READ_WRITE],EAX
						SUB		CS:[FILE_BYTES_TO_READ_WRITE],EAX
						MOV		ECX,EAX
						JBE		FREAD_END	; Done with the requested bytes.



						INC		EBX							; Sector forward
						MOV		CS:[FILE_CURRENT_SECTOR],EBX
						SUB		BX,GS:[BP+DPB_FIRST_DATA_SECTOR]
						TEST	BL,GS:[BP+DPB_CLUSTER_MASK]

						JNE		FREAD_CLUSTER_BOUNDARY
						; Jump if sectors left in the cluster
						; Don't jump if the hanging bytes were taken from the last bytes of the cluster.



FREAD_CLUSTER_LOOP:
						; Move to the next cluster, if exists.
						; Input
						;   GS:BP  Drive Parameter Block
						;   BX     Cluster
						MOV		BX,FS:[DI+SF_CUR_ABS_CLUSTER_NUM]
						PUSH	DI
						CALL	GET_NEXT_CLUSTER
						POP		DI
						;   CF=0   DX=Next Cluster
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FREAD_ERROR_END

						CMP		DX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JAE		FREAD_ERROR_END

						; Yes, it did move.
						INC		WORD PTR FS:[DI+SF_CUR_REL_CLUSTER_NUM]
						MOV		FS:[DI+SF_CUR_ABS_CLUSTER_NUM],DX
						MOV		WORD PTR CS:[FILE_SECTORS_INTO_CLUSTER],0

						; Recalculate the sector
						CALL	CLUSTER_TO_SECTOR
						; EBX is recalculated sector.
						MOV		CS:[FILE_CURRENT_SECTOR],EBX


FREAD_CLUSTER_BOUNDARY:
						MOV		EAX,CS:[FILE_BYTES_TO_READ_WRITE]
						XOR		EDX,EDX
						MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						DIV		ECX
						; EAX is sectors to read whole.


						; Calculate number of sectors left in the cluster.
						; SectorsPerCluster-(CurrentSector-DpbFirstDataSector)&DpbClusterMask
						MOV		ECX,CS:[FILE_CURRENT_SECTOR]
						SUB		CX,GS:[BP+DPB_FIRST_DATA_SECTOR]
						NEG		CX
						; If CX=0, CX must become DPB_CLUSTER_MASK+1
						DEC		CX  ; 0->FF    1->0  2->1  3->2  4->3 ...
						AND		CL,GS:[BP+DPB_CLUSTER_MASK] ; CL is sectors into cluster
						INC		CX  ; FF->100  0->1  1->2  2->3  3->4 ...
						MOVZX	ECX,CL
						; ECX is number of sectors left in the cluster.

						MAKESMALLER_UNSIGNED	ECX,EAX

						; ECX is number of sectors to read from this cluster

						JECXZ	FREAD_BREAK_CLUSTER_LOOP


						PUSH	DI
						MOV		AL,GS:[BP+DPB_UNIT_CODE]
						MOV		AH,GS:[BP+DPB_MEDIA_DESC_TYPE]
						MOV		ESI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						MOV		EDX,CS:[FILE_CURRENT_SECTOR]
						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						LINEAR2SEGOFF_EDI
						; Input
						;   AL     Unit
						;   AH     Media Desc
						;   CX     Length in bytes?
						;   DX     LBA
						;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
						;   EDI    Data Buffer (Hiword=SEG, Loword=OFFSET)
						CALL	DEVCALL_READ_SECTOR
						; Return
						;   CF=0   AX=Length read
						;   CF=1   AX=Status Code (If statusCode &0x8000)
						POP		DI
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FREAD_ERROR_END


						; ECX sectors read.
						ADD		CS:[FILE_CURRENT_SECTOR],ECX


						MOVZX	EAX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						MUL		ECX
						; EAX is bytes read.


						; Move pointers forward
						ADD		FS:[DI+SF_FILE_POINTER],EAX
						ADD		CS:[FILE_READ_WRITE_POINTER],EAX
						ADD		CS:[FILE_BYTES_DID_READ_WRITE],EAX
						SUB		CS:[FILE_BYTES_TO_READ_WRITE],EAX
						MOV		ECX,CS:[FILE_BYTES_DID_READ_WRITE]
						JBE		FREAD_END	; Done with the requested bytes.

						; Two possibilities
						; (1) Come to the end of the cluster
						; (2) Stopped middle of the cluster because needed bytes is less than a sector.
						; If (1), needs to move to the next cluster regardless of the remaining bytes.
						; If (2), sectors must be stopping in the middle, and the remaining bytes must be less than a sector.
						MOV		CX,WORD PTR CS:[FILE_CURRENT_SECTOR]
						SUB		CX,GS:[BP+DPB_FIRST_DATA_SECTOR]
						AND		CL,GS:[BP+DPB_CLUSTER_MASK]
						JE		FREAD_CLUSTER_LOOP



FREAD_BREAK_CLUSTER_LOOP:
						MOV		ECX,CS:[FILE_BYTES_TO_READ_WRITE]	; Still trailing hanging bytes?
						AND		ECX,ECX
						JE		FREAD_END ; JECXZ out of range

						PUSH	DI

						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						XOR		AL,AL
						MOV		EDX,CS:[FILE_CURRENT_SECTOR]
						CALL	GETBUFFER_REGULAR
						;   DS:DI  Buffer
						;   AX     Destroyed
						;   DX     Destroyed
						;   Hiword EDI  Destroyed
						MOV		AX,DOSERR_ACCESS_DENIED

						LEA		SI,[DI+IO_BUF_INFO_size]	; LEA doesn't affect flags unlike 6809.
						POP		DI

						JC		FREAD_ERROR_END

						MOV		AX,DI ; Save SF_ENTRY in AX

						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						SHR		EDI,4
						MOV		ES,DI
						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						AND		DI,0fh
						MOV		CX,WORD PTR CS:[FILE_BYTES_TO_READ_WRITE]
						CALL	UTIL_REP_MOVS	; DS:[SI]->ES:[DI], CX bytes

						MOV		DI,AX ; Restore DI

						MOV		EAX,CS:[FILE_BYTES_TO_READ_WRITE]

						ADD		FS:[DI+SF_FILE_POINTER],EAX
						ADD		CS:[FILE_READ_WRITE_POINTER],EAX
						ADD		CS:[FILE_BYTES_DID_READ_WRITE],EAX
						SUB		CS:[FILE_BYTES_TO_READ_WRITE],EAX

						JMP		FREAD_END

						; This section is almost same as FWRITE <<



FREAD_FROM_CHARDEV:
						;  FS:DI  SF_ENTRY
						;  ECX    Bytes to read (CAUTION! Hiword Valid! Can read more than 64KB!  Mask ECX if not intended!)
						;  EDX    Data Pointer (Hiword is SEG, and Loword is OFFSET)
						CMP		ECX,010000h
						JA		FREAD_FROM_CHARDEV	; Not supported yet.

						XOR		EAX,EAX
						MOV		CS:[FILE_BYTES_DID_READ_WRITE],EAX

FREAD_FROM_CHARDEV_LOOP:
						PUSH	ECX
						PUSH	EDX
						PUSH	DI
						PUSH	FS

						MOV		ESI,FS:[DI+SF_DRIVER_POINTER]
						XOR		AX,AX
						MOV		EDI,EDX
						XOR		DX,DX
						;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
						;   AL     Unit
						;   AH     Media Desc
						;   EDI    Data Buffer (Hiword=SEG, Loword=OFFSET)
						;   DX     LBA
						;   CX     Length in bytes? (Prob number of sectors)
						MOV		ECX,1
						CALL	DEVCALL_READ_SECTOR
						;   CF=0   AX=Length read
						;   CF=1   AX=Status Code

						POP		FS
						POP		DI
						POP		EDX
						POP		ECX

						JC		FREAD_ERROR_END

						PUSH	DS
						ROL		EDX,16
						MOV		DS,DX
						ROL		EDX,16
						MOV		SI,DX
						LODSB
						POP		DS

						INC		DWORD PTR CS:[FILE_BYTES_DID_READ_WRITE]
						INC		DX

						CMP		AL,0DH  ; If ENTER key, return.
						JE		FREAD_END_ENTER_KEY
						CMP		AL,0AH  ; If ENTER key, return.
						JE		FREAD_END

						LOOP	FREAD_FROM_CHARDEV_LOOP


FREAD_END:
						MOV		ECX,CS:[FILE_BYTES_DID_READ_WRITE]
						CLC
						RET

FREAD_END_ENTER_KEY:
						; Need to add 0Ah after 0Dh.  WTF!
						CMP		ECX,1
						JBE		FREAD_END

						MOV		DI,DX
						ROL		EDX,16
						MOV		ES,DX
						MOV		AL,0Ah
						STOSB
						INC		DWORD PTR CS:[FILE_BYTES_DID_READ_WRITE]

						JMP		FREAD_END

FREAD_EOF:
						XOR		CX,CX
						CLC
						RET

FREAD_ERROR_END:
						XOR		CX,CX
						STC
						RET
FREAD					ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;FWRITE_TO_JFN(length,buf,jfn)
;{
;	bytesWritten=0;
;
;	sf=get_sf_from_jfn(jfn);
;	if(sf==invalid || machineId!=sf.machineId)
;	{
;		return bytesWritten=0,lastError=DOSERR_INVALID_HANDLE;
;	}
;	return FWRITE(length,buf,sf)
;}

; Input
;     AX     JFN
;     CX     Bytes to read
;     EDX    Data Pointer (Hiword is SEG, and Loword is OFFSET)
; Return
;     ECX    Number of bytes read
;     CF=0   Successful  AX destroyed.
;     CF=1   AX is error code
; Pretty much every registers are destroyed.
; DS Destroyed from GET_NEXT_CLUSTER
FWRITE_TO_JFN:
						CALL	GET_SF_ENTRY_FROM_JFN
						JC		FWRITE_TO_JFN_ERROR

						; FS:DI is SF_ENTRY
						; I don't think JFN is relevant once I have FS_ENTRY.

						MOV		BX,CS:[MACHINE_NUMBER]
						CMP		BX,FS:[DI+SF_MACHINE_NUMBER]
						JNE		FWRITE_TO_JFN_ERROR

						CALL	FWRITE
						RET
FWRITE_TO_JFN_ERROR:
						MOV		AX,DOSERR_INVALID_HANDLE
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;FWRITE(length,buf,sf)
;{
;	DMAPtr=buf;	// Needed for INT 2FH device.
;
;	// 1679:000037EB
;	if(sf.mode==ReadMode)  // WriteMode=1
;	{
;		lastError=DOSERR_ACCESS_DENIED;
;		return 0;
;	}
;
;	if(0!=(sf.devFlags&SF_DEVFLAG_REDIRECTED)
;	{
;		// Don't forget FS->ES
;		// Don't forget DMAPtr
;		return INT2FH(AH=1109H);
;	}
;
;	Calculate Clusters into file, bytes into sector, sectors into cluster, etc.
;
;	if(CHARDEV)
;	{
;		if(in ASCII mode)
;		{
;			while(*writePtr!=EOF(0x1A))
;			{
;				WriteOneByteToDevice
;			}
;		}
;		else //if(in BINARY mode)
;		{
;			WriteAllBytesToDevice
;		}
;	}
;	else
;	{
;		Do write.  Tricky part is when the next cluster is null, need to append one.
;	}
;}
; Input
;     FS:DI  SF_ENTRY
;     CX     Bytes to write
;     EDX    Data Pointer (Hiword is SEG, and Loword is OFFSET)
; Return
;     ECX    Number of bytes read
;     CF=0   Successful  AX destroyed.
;     CF=1   AX is error code
; Pretty much every registers are destroyed.
; DS Destroyed from GET_NEXT_CLUSTER
FWRITE:
						MOV		DWORD PTR CS:[FILE_BYTES_DID_READ_WRITE],0	; In case ECX==0.
						MOVZX	ECX,CX
						OR		CX,CX
						JNE		FWRITE_NOT_RESIZE

						; http://www.ctyme.com/intr/rb-2791.htm
						; CX=0 will truncate or extend the file to the current file position.
						; I don't support extend, but Towns OS V2.1 L31 installer uses truncation.
						; Also I don't release clusters if some becoms unused.
						MOV		ECX,FS:[DI+SF_FILE_POINTER]
						CMP		ECX,FS:[DI+SF_FILE_SIZE]
						JA		FWRITE_EXTEND_NOT_SUPPORTED

						MOV		FS:[DI+SF_FILE_SIZE],ECX
						AND		WORD PTR FS:[DI+SF_DEVFLAGS],0ffffh-SF_DEVFLAG_BLOCK_NOT_WRITTEN
						JMP		FWRITE_END

FWRITE_EXTEND_NOT_SUPPORTED:	JMP		FWRITE_EXTEND_NOT_SUPPORTED

FWRITE_NOT_RESIZE:
						MOV		CS:[FILE_BYTES_TO_READ_WRITE],ECX

						MOV		AX,DOSERR_ACCESS_DENIED;
						MOV		BX,FS:[DI+SF_MODE]
						AND		BX,0Fh
						CMP		BX,SF_MODE_READ	; Needs to be Write or Read/Write
						JE		FWRITE_ERROR_END

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_REDIRECTED
						JE		FWRITE_NOT_REDIRECTED
;FWRITE_REDIRECTED:
						PUSH	FS
						POP		ES ; ES:DI is SF_ENTRY
						MOV		AX,INT2FH_FWRITE
						MOV		DWORD PTR CS:[DMA_BUFFER_PTR],EDX
						INT		2FH
						RET


FWRITE_NOT_REDIRECTED:
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						JNE		FWRITE_TO_CHARDEV


						;;;;;;;; BLOCKDEV ;;;;;;;;


;FWRITE_TO_BLOCKDEV:
						LGS		BP,FS:[DI+SF_DRIVER_POINTER] ; It is a BLOCKDEV, therefore it is DPB.

						MOV		WORD PTR CS:[FILE_READ_WRITE_POINTER],DX
						MOV		WORD PTR CS:[FILE_READ_WRITE_POINTER+2],0
						SHR		EDX,16
						SHL		EDX,4
						ADD		CS:[FILE_READ_WRITE_POINTER],EDX

						CALL	FILE_PREP_RW_BLOCKDEV
						; GS:BP is DPB.
						; Parameters populated.
						; EAX,ECX,EDX Destroyed.



						; Get Clusters>>
						;
						; Major difference between FREAD and FWRITE is
						; FWRITE may increase the file size.
						; Which means I may need to append a new cluster
						; to the end.
						; I can do it incrementally, or upfront.
						; If I do it incrementally, I will end up swinging
						; disk head back and forth.  Will be extremely
						; poor performance.
						; I should do it up front.
						; Then, I need to know how many clusters that the
						; current file has, and how many clusters are needed.
						MOV		EAX,FS:[DI+SF_FILE_POINTER]
						ADD		EAX,CS:[FILE_BYTES_TO_READ_WRITE]
						CMP		EAX,FS:[DI+SF_FILE_SIZE]
						JBE		FWRITE_NO_GROWTH_IN_SIZE ; No growth. Not need new clusters.

						CALL	FILE_SIZE_TO_CLUSTER_SIZE ; ECX,EDX destroyed. EBX preserved
						MOV		EBX,EAX	; EBX=Clusters needed for file for FWRITE
						MOV		EAX,FS:[DI+SF_FILE_SIZE]
						CALL	FILE_SIZE_TO_CLUSTER_SIZE ; EAX is current cluster count of this file.
						CMP		EBX,EAX
						JBE		FWRITE_NO_GROWTH_IN_SIZE ; Jump if Required<=Current

						MOV		ECX,EBX
						SUB		ECX,EAX
						PUSH	EAX
						CALL	ALLOCATE_CLUSTER_CHAIN
						POP		EAX
						JNC		FWRITE_DISK_IS_NOT_FULL
						MOV		AX,DOSERR_DISK_FULL
						JMP		FWRITE_ERROR_END
FWRITE_DISK_IS_NOT_FULL:
						; Cluster EAX-1 is where cluster chain should be appended

						; EBX is the first of the allocated cluster chain.
						CMP		WORD PTR FS:[DI+SF_FIRST_CLUSTER_NUM],0
						JE		FWRITE_IS_FIRST_BYTE
						MOV		CX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						CMP		CX,WORD PTR FS:[DI+SF_FIRST_CLUSTER_NUM] ; I don't know if this check is necessary.
						JAE		FWRITE_APPEND_CLUSTER
FWRITE_IS_FIRST_BYTE:
						MOV		FS:[DI+SF_FIRST_CLUSTER_NUM],BX
						MOV		WORD PTR FS:[DI+SF_CUR_REL_CLUSTER_NUM],0
						MOV		WORD PTR FS:[DI+SF_CUR_ABS_CLUSTER_NUM],BX
						JMP		FWRITE_WRITE_FAT
FWRITE_APPEND_CLUSTER:
						; Append cluster not supported yet.
						; Need to get to the last cluster.
						; EAX still is number of clusters for the current file size.
						; Then, EAX-1 must be the cluster count to get to the last cluster.
						DEC		EAX
						MOV		ECX,EAX
						PUSH	BX
						CALL	GET_CLUSTERS_INTO_FILE
						POP		BX
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FWRITE_ERROR_END

						XCHG	DX,BX
						; DX=last cluster of file.
						; BX=Head of the new cluster chain.
						PUSH	DI
						CALL	WRITE_CLUSTER
						POP		DI

FWRITE_WRITE_FAT:
						PUSH	DI
						MOV		AL,GS:[BP+DPB_DRIVE_CODE]
						CALL	FLUSH_BUFFERS_DRIVE_FAT
						POP		DI
						JC		FWRITE_DEVERROR_END
FWRITE_NO_GROWTH_IN_SIZE:
						; Get Clusters<<
						; At this time, the file has sufficient clusters.


						AND		WORD PTR FS:[DI+SF_DEVFLAGS],0ffffh-SF_DEVFLAG_BLOCK_NOT_WRITTEN


						; This section is almost same as FREAD >>

						; Need to get to the first sector.
						; If the current pointer is after the known location, move forward,
						; or get from zero.
						MOV		ECX,CS:[FILE_CLUSTERS_INTO_FILE] ; Want to support 32-bit FAT eventually....
						CALL	GET_CLUSTERS_INTO_FILE
						MOV		AX,DOSERR_INVALID_HANDLE	; Original DOS fires INT 24H.  I just make it a regular read error.
						JB		FWRITE_ERROR_END

						;   CF=0   DX=Cluster CXth cluster of the file
						CMP		DX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JA		FWRITE_ERROR_END			; I think it's not supposed to happen, but... let it go.


						; DX is also written in FS:[DI+SF_CUR_ABS_CLUSTER_NUM]
						; Good to go.

						;   GS:BP  Drive Parameter Block
						;   DX     Cluster
						CALL	CLUSTER_TO_SECTOR
						; EBX is data sector
						; EAX,CL are destroyed
						; Sector is 16-bit in DPB.  What about a large hard drive? -> Sector must be relative to UNIT's first sector.

						; Add sectors into cluster to get the exact sector.
						ADD		BX,CS:[FILE_SECTORS_INTO_CLUSTER]
						MOV		CS:[FILE_CURRENT_SECTOR],EBX

						; Read hanging bytes from the first sector
						TEST	WORD PTR CS:[FILE_BYTES_INTO_SECTOR],0ffffh
						JE		FWRITE_CLUSTER_BOUNDARY



						PUSH	DI
						PUSH	EBX
						; There are hanging bytes from the first sector
						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						XOR		AL,AL
						MOV		DX,BX
						CALL	GETBUFFER_REGULAR
						;   DS:DI  Buffer
						;   AX     Destroyed
						;   DX     Destroyed
						;   Hiword EDI  Destroyed
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FWRITE_ERROR_END

						MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						MOV		BX,CS:[FILE_BYTES_INTO_SECTOR]
						SUB		CX,BX

						MAKESMALLER_UNSIGNED	ECX,CS:[FILE_BYTES_TO_READ_WRITE]

						OR		BYTE PTR DS:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN

						PUSH	DI

						MOV		EAX,ECX  ; Save in EAX
						LEA		SI,[DI+IO_BUF_INFO_size+BX]
						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						SHR		EDI,4
						MOV		ES,DI
						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						AND		DI,0fh
						XCHG_DSSI_ESDI
						CALL	UTIL_REP_MOVS	; DS:[SI]->ES:[DI], CX bytes, AX,BX preserved.

						POP		SI	; I think SI is free this time.  Let DS:SI be the buffer header.

						; If one sector is done, it should flush.
						; How can I tell if it is done?
						; Have just written AX (copied from CX) bytes from BX bytes into the sector.
						; Pointer in sector is BX+AX.
						; If it is greater or equal to the sector size, one sector is done.
						ADD		BX,AX
						CMP		BX,GS:[BP+DPB_BYTES_PER_SECTOR]
						JB		FWRITE_FIRST_HANGING_SECTOR_NOT_FILLED

						; Sector done.  Write it.
						; ES and DS swapped in the above XCHG_DSSI_ESDI
						PUSH	ES
						POP		DS
						PUSH	EAX
						; Input DS:SI  Buffer Pointer
						CALL	WRITE_BACK_BUFFER
						POP		EAX

FWRITE_FIRST_HANGING_SECTOR_NOT_FILLED:
						POP		EBX
						POP		DI

						; EAX number of bytes transferred
						; EBX current sector


						; Move pointers forward
						ADD		FS:[DI+SF_FILE_POINTER],EAX
						ADD		CS:[FILE_READ_WRITE_POINTER],EAX
						ADD		CS:[FILE_BYTES_DID_READ_WRITE],EAX
						SUB		CS:[FILE_BYTES_TO_READ_WRITE],EAX
						MOV		ECX,EAX
						JBE		FWRITE_UPDATE_FILE_SIZE	; Done with the requested bytes.


						INC		EBX							; Sector forward
						MOV		CS:[FILE_CURRENT_SECTOR],EBX
						SUB		BX,GS:[BP+DPB_FIRST_DATA_SECTOR]
						TEST	BL,GS:[BP+DPB_CLUSTER_MASK]

						JNE		FWRITE_CLUSTER_BOUNDARY
						; Jump if sectors left in the cluster
						; Don't jump if the hanging bytes were taken from the last bytes of the cluster.



FWRITE_CLUSTER_LOOP:
						; Move to the next cluster, if exists.
						; Input
						;   GS:BP  Drive Parameter Block
						;   BX     Cluster
						MOV		BX,FS:[DI+SF_CUR_ABS_CLUSTER_NUM]
						PUSH	DI
						CALL	GET_NEXT_CLUSTER
						POP		DI
						;   CF=0   DX=Next Cluster
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FWRITE_ERROR_END

						CMP		DX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JAE		FWRITE_ERROR_END

						; Yes, it did move.
						INC		WORD PTR FS:[DI+SF_CUR_REL_CLUSTER_NUM]
						MOV		FS:[DI+SF_CUR_ABS_CLUSTER_NUM],DX
						MOV		WORD PTR CS:[FILE_SECTORS_INTO_CLUSTER],0

						; Recalculate the sector
						CALL	CLUSTER_TO_SECTOR
						; EBX is recalculated sector.
						MOV		CS:[FILE_CURRENT_SECTOR],EBX


FWRITE_CLUSTER_BOUNDARY:
						MOV		EAX,CS:[FILE_BYTES_TO_READ_WRITE]
						XOR		EDX,EDX
						MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						DIV		ECX
						; EAX is sectors to read whole.


						; Calculate number of sectors left in the cluster.
						; SectorsPerCluster-(CurrentSector-DpbFirstDataSector)&DpbClusterMask
						MOV		ECX,CS:[FILE_CURRENT_SECTOR]
						SUB		CX,GS:[BP+DPB_FIRST_DATA_SECTOR]
						NEG		CX
						; If CX=0, CX must become DPB_CLUSTER_MASK+1
						DEC		CX  ; 0->FF    1->0  2->1  3->2  4->3 ...
						AND		CL,GS:[BP+DPB_CLUSTER_MASK] ; CL is sectors into cluster
						INC		CX  ; FF->100  0->1  1->2  2->3  3->4 ...
						MOVZX	ECX,CL
						; ECX is number of sectors left in the cluster.

						MAKESMALLER_UNSIGNED	ECX,EAX

						; ECX is number of sectors to read from this cluster

						JECXZ	FWRITE_BREAK_CLUSTER_LOOP


						PUSH	DI
						MOV		AL,GS:[BP+DPB_UNIT_CODE]
						MOV		AH,GS:[BP+DPB_MEDIA_DESC_TYPE]
						MOV		ESI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						MOV		EDX,CS:[FILE_CURRENT_SECTOR]
						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						LINEAR2SEGOFF_EDI
						; Input
						;   AL     Unit
						;   AH     Media Desc
						;   CX     Length in bytes?
						;   DX     LBA
						;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
						;   EDI    Data Buffer (Hiword=SEG, Loword=OFFSET)
						CALL	DEVCALL_WRITE
						; Return
						;   CF=0   AX=Length read
						;   CF=1   AX=Status Code (If statusCode &0x8000)
						POP		DI
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FWRITE_ERROR_END


						; ECX sectors read.
						ADD		CS:[FILE_CURRENT_SECTOR],ECX


						MOVZX	EAX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						MUL		ECX
						; EAX is bytes read.


						; Move pointers forward
						ADD		FS:[DI+SF_FILE_POINTER],EAX
						ADD		CS:[FILE_READ_WRITE_POINTER],EAX
						ADD		CS:[FILE_BYTES_DID_READ_WRITE],EAX
						SUB		CS:[FILE_BYTES_TO_READ_WRITE],EAX
						MOV		ECX,CS:[FILE_BYTES_DID_READ_WRITE]
						JBE		FWRITE_UPDATE_FILE_SIZE	; Done with the requested bytes.

						; Two possibilities
						; (1) Come to the end of the cluster
						; (2) Stopped middle of the cluster because needed bytes is less than a sector.
						; If (1), needs to move to the next cluster regardless of the remaining bytes.
						; If (2), sectors must be stopping in the middle, and the remaining bytes must be less than a sector.
						MOV		CX,WORD PTR CS:[FILE_CURRENT_SECTOR]
						SUB		CX,GS:[BP+DPB_FIRST_DATA_SECTOR]
						AND		CL,GS:[BP+DPB_CLUSTER_MASK]
						JE		FWRITE_CLUSTER_LOOP



FWRITE_BREAK_CLUSTER_LOOP:
						MOV		ECX,CS:[FILE_BYTES_TO_READ_WRITE]	; Still trailing hanging bytes?
						AND		ECX,ECX
						JE		FWRITE_END	; Short jump out of range for JECXZ

						PUSH	DI

						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						XOR		AL,AL
						MOV		EDX,CS:[FILE_CURRENT_SECTOR]
						CALL	GETBUFFER_REGULAR
						;   DS:DI  Buffer
						;   AX     Destroyed
						;   DX     Destroyed
						;   Hiword EDI  Destroyed
						MOV		AX,DOSERR_ACCESS_DENIED

						OR		BYTE PTR DS:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN
						LEA		SI,[DI+IO_BUF_INFO_size]	; LEA doesn't affect flags unlike 6809.
						POP		DI

						JC		FWRITE_ERROR_END

						MOV		AX,DI ; Save SF_ENTRY in AX

						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						SHR		EDI,4
						MOV		ES,DI
						MOV		EDI,CS:[FILE_READ_WRITE_POINTER]
						AND		DI,0fh
						MOV		CX,WORD PTR CS:[FILE_BYTES_TO_READ_WRITE]
						XCHG_DSSI_ESDI
						CALL	UTIL_REP_MOVS	; DS:[SI]->ES:[DI], CX bytes

						MOV		DI,AX ; Restore DI

						MOV		EAX,CS:[FILE_BYTES_TO_READ_WRITE] ; This amount hanging, and just was taken care.

						ADD		FS:[DI+SF_FILE_POINTER],EAX
						ADD		CS:[FILE_READ_WRITE_POINTER],EAX
						ADD		CS:[FILE_BYTES_DID_READ_WRITE],EAX
						SUB		CS:[FILE_BYTES_TO_READ_WRITE],EAX


FWRITE_UPDATE_FILE_SIZE:
						MOV		EAX,FS:[DI+SF_FILE_POINTER]
						MAKEGREATER_UNSIGNED EAX,FS:[DI+SF_FILE_SIZE]
						MOV		FS:[DI+SF_FILE_SIZE],EAX

						JMP		FWRITE_END
						; This section is almost same as FREAD <<


						;;;;;;;; CHARDEV ;;;;;;;;


FWRITE_TO_CHARDEV:
						; It is CHARDEV.  Therefore, SF_DRIVER_POINTER gives device driver.
						MOV		ESI,FS:[DI+SF_DRIVER_POINTER]
						MOV		EBX,EDX
						ROR		EBX,16
						MOV		DS,BX
						ROL		EBX,16
						XOR		EDX,EDX

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_CHAR_BINARY
						JNE		FWRITE_TO_CHARDEV_BINARY
;FWRITE_TO_CHARDEV_ASCII:

FWRITE_TO_CHARDEV_ASCII_LOOP:
						CMP		BYTE PTR DS:[BX],ASCII_EOF
						JE		FWRITE_CHARDEV_ASCII_BREAK

						PUSH	CX		; Save counter
						PUSH	DX		; Save bytes written

						MOV		AX,0	; CHARDEV doesn't care
						MOV		CX,1	; 1 byte
						MOV		DX,0	; CHARDEV doesn't care
						; ESI already set to driver.
						PUSH	EDI		; Save SF_ENTRY
						MOV		EDI,EBX
						CALL	DEVCALL_WRITE

						POP		EDI
						POP		DX
						POP		CX

						XCHG	ECX,EDX
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FWRITE_ERROR_END
						XCHG	ECX,EDX

						INC		DWORD PTR FS:[DI+SF_FILE_POINTER]
						INC		EDX		; Count how many chars written.
						INC		BX
						LOOP	FWRITE_TO_CHARDEV_ASCII_LOOP

FWRITE_CHARDEV_ASCII_BREAK:
						MOV		CS:[FILE_BYTES_DID_READ_WRITE],EDX
						JMP		FWRITE_END



FWRITE_TO_CHARDEV_BINARY:
						MOV		AX,0	; CHARDEV doesn't care
						; CX is already bytes to write
						MOV		DX,0	; CHARDEV doesn't care
						; ESI already set to driver.
						PUSH	EDI		; Save SF_ENTRY
						MOV		EDI,EBX
						CALL	DEVCALL_WRITE
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FWRITE_ERROR_END
						POP		EDI

						MOVZX	ECX,AX
						ADD		DWORD PTR FS:[DI+SF_FILE_POINTER],ECX
						MOV		CS:[FILE_BYTES_DID_READ_WRITE],ECX



FWRITE_END:
						MOV		ECX,CS:[FILE_BYTES_DID_READ_WRITE]

						; MEMO TO MYSELF:
						;   Apprently I must not update SF_FILE_SIZE for CHARDEV.
						;   SF_FILE_SIZE field may have a different meaning for CHARDEV or
						;   it simply needs to be zero.

						CLC
						RET

FWRITE_DEVERROR_END:
						CALL	DEVERR_TO_DOSERR
FWRITE_ERROR_END:
						MOV		ECX,CS:[FILE_BYTES_DID_READ_WRITE]
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX=File Handle(JFN)
; Output
;   CF=0  File is a regular file.
;   CF=1  File is a CHARDEV or file is not open.
; AX is preserved.
CHECK_FILE_IS_CHARDEV:
						PUSH	AX
						CALL	GET_SF_ENTRY_FROM_JFN
						POP		AX
						JC		CHECK_FILE_IS_CHARDEV_EXIT

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						CLC
						JE		CHECK_FILE_IS_CHARDEV_EXIT
						STC
CHECK_FILE_IS_CHARDEV_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI   File name
;   AL      Mode 0:Read 1:Write 2:Read/Write
; Return
;   CF=0  Success  AX=JFN
FOPEN:
						CALL	FOPEN_FCREATE_PREP
						JB		FOPEN_ERROR

						; Have JFN, SFN, and SF_ENTRY pointer.
						; Saved file name
						CMP		WORD PTR CS:[FILENAME_BUFFER+1],05C3Ah ; ':\'
						JNE		FOPEN_CHARDEV
; FOPEN_NOT_CHARDEV:
;   Can be INT 2F device or BLOCK device.
						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	GET_ALth_CDS_IN_DSSI	; Not supposed to fail if above MAKE_FULLPATH succeeded.
						TEST	WORD PTR DS:[SI+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		FOPEN_BLOCKDEV

; FOPEN_INT2FDEV:
						LES		DI,CS:[CUR_SF_ENTRY] ; ES:DI is SF_ENTRY to be filled.

						MOVZX	AX,BYTE PTR CS:[FILE_OPENMODE]
						AND		AX,07Fh	; Forget about sharing.
						MOV		ES:[DI+SF_MODE],AX

						; File Name in CS:[FN1p] (0360h)
						PUSH	AX			; Open Mode in Stack
						MOV		AX,INT2FH_OPEN
						INT		2FH
						POP		BX	; AX may contain error code.  ADD SP,2 will change CF (most likely clear).
						JAE		FOPEN_SUCCESS	; If success, be happy.
						JMP		FOPEN_UNRESERVE_THEN_ERR


FOPEN_BLOCKDEV:
						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	MEDIACHECK_READYCDS		; CF=1 Error  CF=0 AL=(0:No Change  1:Disk Changed)
						JC		FOPEN_UNRESERVE_THEN_ERR
						OR		AL,AL
						JE		FOPEN_BLOCKDEV_CDS_IS_READY
						LDS		SI,CS:[FILE_INPUT_FILENAME]
						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						JC		FOPEN_UNRESERVE_THEN_ERR
FOPEN_BLOCKDEV_CDS_IS_READY:
						CALL	OPEN_DISK_FILE
						JNC		FOPEN_SUCCESS

						CALL	TOWNS_FOPEN_RETRY		; C:\MSCDEX.EXE -> C:\SHSUCDX.COM
						JC		FOPEN_UNRESERVE_THEN_ERR
						CALL	OPEN_DISK_FILE
						JC		FOPEN_UNRESERVE_THEN_ERR

						JMP		FOPEN_SUCCESS

FOPEN_CHARDEV:
						CALL	OPEN_CHARDEV
						JC		FOPEN_UNRESERVE_THEN_ERR


FOPEN_SUCCESS:
						LFS		DI,CS:[CUR_SF_ENTRY]
						MOV		WORD PTR FS:[DI+SF_REFCOUNT],1

						; Original MSDOS.SYS sets SF_DEVFLAG_NO_INHERIT if the incoming open mode (AL)
						; bit 7 is set.  See CS:67E7.  This CX will be finally ORed to the flags.
						; I don't support network file sharing, but unless I set this flag
						; DOS Extender messes up with the reference count.
						MOVZX	AX,BYTE PTR CS:[FILE_OPENMODE]
						SHR		AL,7
						SHL		AX,SF_DEVFLAG_NO_INHERIT_SHIFT
						OR		WORD PTR FS:[DI+SF_DEVFLAGS],AX

						MOVZX	AX,BYTE PTR CS:[FILE_CUR_JFN]
						CLC
						RET

FOPEN_UNRESERVE_THEN_ERR:
						MOVZX	BX,BYTE PTR CS:[FILE_CUR_JFN]
						CALL	UNRESERVE_JFN
FOPEN_ERROR:
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI   File name
;   AL      Mode 0:Read 1:Write 2:Read/Write
; Return
;   CF=0  Success
;   Set
;     CS:[FILE_INPUT_FILENAME]
;     CS:[FILE_OPENMODE]
;     CS:[FILE_CUR_JFN] and JFN reserved
;     CS:[FILE_CUR_SFN] available SFN
;     CS:[CUR_SF_ENTRY] available SF_ENTRY
;     CS:[FILENAME_BUFFER] Fully-Qualified Filename
;  CF=1  Fail.  AX=DOSERR
FOPEN_FCREATE_PREP:
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME],SI
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME+2],DS
						MOV		BYTE PTR CS:[FILE_OPENMODE],AL

						CALL	GET_AVAILABLE_JFN		; BX=Available JFN of current PDB
						MOV		AX,DOSERR_TOO_MANY_OPEN_FILES
						JB		FOPENPREP_ERROR

						MOV		CS:[FILE_CUR_JFN],BL

						CALL	GET_AVAILABLE_SF_ENTRY	; FS:DI=Available SF_ENTRY, DX=SFN
						MOV		AX,DOSERR_TOO_MANY_OPEN_FILES
						JB		FOPENPREP_ERROR

						MOV		BYTE PTR CS:[FILE_CUR_SFN],DL
						MOV		WORD PTR CS:[CUR_SF_ENTRY],DI
						MOV		WORD PTR CS:[CUR_SF_ENTRY_SEG],FS

						MOVZX	BX,BYTE PTR CS:[FILE_CUR_JFN]
						; DX is still SFN
						CALL	RESERVE_JFN

						LDS		SI,CS:[FILE_INPUT_FILENAME]
						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						; Let it take return from MAKE_FULLPATH_CRUNCH_LESSERWC
						RET

FOPENPREP_ERROR:
						STC
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CS:CUR_SF_ENTRY
;   CS:FILENAME_BUFFER  Set to Fully-Qualified File Name
;   CS:FILE_INPUT_FILENAME
;   CS:FILE_CUR_SFN
;   CS:FILE_CUR_JFN
;   CS:FILE_OPENMODE
; Output
;   CUR_SF_ENTRY Populated.
OPEN_DISK_FILE:
						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	GET_ALth_CDS_IN_DSSI
						MOV		AX,DOSERR_INVALID_DRIVE
						JC		OPEN_DISK_FILE_ERR

						LGS		BP,DS:[SI+CDS_DRIVE_PARAM_BLOCK]
						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3
						XOR		EAX,EAX
						MOV		CX,0ffffh-DIRENT_ATTR_VOLLABEL
						CALL	FETCH_DIR
						JC		OPEN_DISK_FILE_NOT_FOUND

						; INT 21H AH=3DH is open EXISTING file.
						;  If not found, just return file not found.
;OPEN_DISK_FILE_EXISTS:
						; ES:DI is DIRENT
						; ES:BX is BUFFER HEADER
						; AX is file attribute
						; CS:[DIR_CURRENT_SECTOR] is current sector
						; CS:[DIR_BYTES_INTO_SECTOR] is bytes into sector

						MOV		DL,CS:[FILE_OPENMODE]
						AND		DL,7

						TEST	AX,DIRENT_ATTR_DIRECTORY
						JNE		OPEN_DISK_FILE_NOT_FOUND

						CMP		DL,SF_MODE_READ
						JE		OPEN_DISK_FILE_EXISTS_READ

						; If write or random-access mode, and if the file is read only?
						TEST	AX,DIRENT_ATTR_READONLY
						JNE		OPEN_DISK_FILE_INVALID_ACCESS

OPEN_DISK_FILE_EXISTS_READ:
						; Make SF_ENTRY from DIRENT
						; ES:DI is DIRENT
						; ES:BX is BUFFER HEADER

						XCHGSTACK	ES,DS
						MOV		SI,DI		; DS:SI is DIRENT
						LFS		DI,CS:[CUR_SF_ENTRY]
						MOV		AL,CS:[FILE_OPENMODE]
						AND		AL,7Fh
						MOV		EBX,DWORD PTR CS:[DIR_CURRENT_SECTOR]
						MOV		DX,CS:[DIR_BYTES_INTO_SECTOR]
						CALL	MAKE_SF_ENTRY_FROM_DIRENT

						CLC
						RET

OPEN_DISK_FILE_ERR:
						TSUGARU_DEBUG_BREAK	0
						STC
						RET

OPEN_DISK_FILE_NOT_FOUND:
						MOV		AX,DOSERR_FILE_NOT_FOUND
						STC
						RET

OPEN_DISK_FILE_INVALID_ACCESS:
						MOV		AX,DOSERR_INVALID_ACCESS
						STC
						RET

OPEN_DISK_FILE_ACCESS_DENIED:
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CS:CUR_SF_ENTRY
;   CS:FILENAME_BUFFER  Set to Fully-Qualified File Name
;   CS:FILE_INPUT_FILENAME
;   CS:FILE_CUR_SFN
;   CS:FILE_CUR_JFN
;   CS:FILE_OPENMODE
; See 1679:000049BB
OPEN_CHARDEV:
						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3
						CALL	MATCH_CHARDEV_DSSI
						JC		OPEN_CHARDEV_ERROR
						; ES:DI=SYSDEV

						MOV		BX,DI
						; ES:BX=SYSDEV

						LFS		DI,CS:[CUR_SF_ENTRY]
						MOVZX	AX,BYTE PTR CS:[FILE_OPENMODE]
						MOV		FS:[DI+SF_MODE],AX

						MOV		BYTE PTR FS:[DI+SF_ATTR],00h

						MOVZX	AX,BYTE PTR ES:[BX+SYSDEV_DEVFLAGS]
						OR		AL,0C0h	; (SF_DEVFLAG_CHAR_NOT_EOF|SF_DEVFLAG_IS_CHARDEV)
						AND		AL,0DFh	; ~SF_DEVFLAG_CHAR_BINARY  Probably it is right (CS:4414)
						MOV		FS:[DI+SF_DEVFLAGS],AX

						MOV		WORD PTR FS:[DI+SF_DRIVER_POINTER],BX
						MOV		WORD PTR FS:[DI+SF_DRIVER_POINTER+2],ES

						XOR		EAX,EAX
						MOV		FS:[DI+SF_FIRST_CLUSTER_NUM],AX
						MOV		DWORD PTR FS:[DI+SF_TIME],EAX ; Also covers SF_DATE
						MOV		FS:[DI+SF_FILE_POINTER],EAX ; Also covers SF_DATE
						MOV		DWORD PTR FS:[DI+SF_CUR_ABS_CLUSTER_NUM],EAX ; Also covers REL_CLUSTER
						MOV		FS:[DI+SF_DIR_ENT_SECTOR],AX
						MOV		FS:[DI+SF_DIR_ENT_POS_IN_SECTOR],AL

						MOV		FS:[DI+SF_NEXT_SHARED_SFT],EAX
						MOV		FS:[DI+SF_SHARE_FT_OFFSET],AX

						MOV		AX,CS:[MACHINE_NUMBER]
						MOV		FS:[DI+SF_MACHINE_NUMBER],AX
						MOV		AX,CS:[CurrentPDB]
						MOV		FS:[DI+SF_PSP_OWNER],AX

						MOV		EAX,DWORD PTR ES:[BX+SYSDEV_NAME]
						MOV		DWORD PTR FS:[DI+SF_FILENAME],EAX
						MOV		EAX,DWORD PTR ES:[BX+SYSDEV_NAME+4]
						MOV		DWORD PTR FS:[DI+SF_FILENAME+4],EAX

						MOV		AX,2020h
						MOV		WORD PTR FS:[DI+SF_FILENAME+8],AX
						MOV		BYTE PTR FS:[DI+SF_FILENAME+10],AL

						CLC
						RET

OPEN_CHARDEV_ERROR:
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI   File name
;   CL      File attribute
; Return
;   CF=0  Success  AX=JFN
FCREATE:
						MOV		CS:[FILE_CREATE_ATTRIB],CL

						CALL	FOPEN_FCREATE_PREP
						JB		FCREATE_ERROR

						CMP		WORD PTR CS:[FILENAME_BUFFER+1],05C3Ah ; ':\'
						MOV		AX,DOSERR_ACCESS_DENIED
						JE		FCREATE_DISK_FILE

						; Observation from Afterburner II
						; If it tries to create "NUL", it just opens.
						MOV		BYTE PTR CS:[FILE_OPENMODE],SF_MODE_READ_WRITE
						CALL	OPEN_CHARDEV
						JC		FCREATE_ERROR
						JMP		FCREATE_SUCCESS


FCREATE_DISK_FILE:
						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	GET_ALth_CDS_IN_DSSI	; Not supposed to fail if above MAKE_FULLPATH succeeded.
						TEST	WORD PTR DS:[SI+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		FCREATE_BLOCKDEV

; FCREATE_INT2F:
						; This may not be necessary, but
						; http://www.ctyme.com/intr/rb-4328.htm tells
						; SDA CDS pointer needs to be set.
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],SI
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],DS

						; In fact, MSCDEX will anyway return error.
						; Hibyte is 0 for normal create, 1 for new file.
						; I think I just take 0.
						MOVZX	CX,BYTE PTR CS:[FILE_CREATE_ATTRIB]
						PUSH	CX

						LES		DI,CS:[CUR_SF_ENTRY]

						MOV		AX,INT2FH_FCREATE
						INT		2FH

						POP		WORD PTR CS:[FILE_TRASH]

						JNC		FCREATE_SUCCESS
						JMP		FCREATE_UNRESERVE_THEN_ERR

FCREATE_BLOCKDEV:
						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	MEDIACHECK_READYCDS		; CF=1 Error  CF=0 AL=(0:No Change  1:Disk Changed)
						JC		FCREATE_UNRESERVE_THEN_ERR
						OR		AL,AL
						JE		FCREATE_BLOCKDEV_CDS_IS_READY
						LDS		SI,CS:[FILE_INPUT_FILENAME]
						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						JC		FCREATE_UNRESERVE_THEN_ERR


FCREATE_BLOCKDEV_CDS_IS_READY:
						CALL	CREATE_DISK_FILE
						JC		FCREATE_UNRESERVE_THEN_ERR

FCREATE_SUCCESS:
						LFS		DI,CS:[CUR_SF_ENTRY]
						MOV		WORD PTR FS:[DI],1
						MOVZX	AX,CS:[FILE_CUR_JFN]
						CLC
						RET

FCREATE_UNRESERVE_THEN_ERR:
						MOVZX	BX,BYTE PTR CS:[FILE_CUR_JFN]
						CALL	UNRESERVE_JFN
FCREATE_ERROR:
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI=Filename
;   CL=File Attribute (Can create a directory for internal use.)
; Return
;   CF=0 AX=File Handle
;   CF=1 AX=Error Code
FCREATE_IF_NOT_EXIST:
						PUSH	DS
						PUSH	SI
						PUSH	CX
						PUSH	DWORD PTR CS:[DMA_BUFFER_PTR]

						; Input
						;   DS:SI File Template
						;   CX Attribute Mask (CH=0)
						;   CS:[DMA_BUFFER_PTR] Pointer to store FINDSTRUCT
						MOV		CX,0FFFFh-DIRENT_ATTR_VOLLABEL
						MOV		WORD PTR CS:[DMA_BUFFER_PTR],OFFSET TEMP_FINDSTRUCT
						MOV		WORD PTR CS:[DMA_BUFFER_PTR+2],CS
						CALL	FIND_FIRST
						; Output
						;   CF=0 Success
						;   CF=1 Error AX=Error Code DOSERR_FILE_NOT_FOUND,DOSERR_DIR_NOT_FOUND, or DOSERR_NO_MORE_FILES

						POP		DWORD PTR CS:[DMA_BUFFER_PTR]
						POP		CX
						POP		SI
						POP		DS
						JNC		FCREATE_IF_NOT_EXIST_ALREADY_EXISTS

						CALL	FCREATE
						RET

FCREATE_IF_NOT_EXIST_ALREADY_EXISTS:
						; MOV		BYTE PTR CS:[ERROR_CLASS],
						; MOV		BYTE PTR CS:[ERROR_LOCUS],
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



CREATE_DISK_FILE:
						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	GET_ALth_CDS_IN_DSSI
						JC		CREATE_DISK_FILE_INVALID_DRIVE

						LGS		BP,DS:[SI+CDS_DRIVE_PARAM_BLOCK]
						PUSH	CS
						POP		DS


						MOV		SI,OFFSET FILENAME_BUFFER
						CALL	SEEK_LAST_BACKSLASH
						CMP		BYTE PTR DS:[DI],'\'
						JNE		CREATE_DISK_FILE_INVALID_FILE_NAME
						LEA		SI,[DI+1]
						CALL	CHECK_NEW_FILENAME_CHARS
						JC		CREATE_DISK_FILE_INVALID_FILE_NAME


						MOV		SI,OFFSET FILENAME_BUFFER+3
						XOR		EAX,EAX
						MOV		CX,0ffffh-DIRENT_ATTR_VOLLABEL
						CALL	FETCH_DIR
						JC		CREATE_DISK_FILE_NOT_EXIST
;CREATE_DISK_FILE_EXIST:
						TEST	AX,(DIRENT_ATTR_DIRECTORY+DIRENT_ATTR_READONLY+DIRENT_ATTR_VOLLABEL)
						JNE		CREATE_DISK_FILE_INVALID_ACCESS

						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER

						; To do:
						; Update DIRENT
						; Mark Buffer Dirty
						; Make SF_ENTRY from DIRENT (Then I can forget about DIRENT)
						; Free clusters

						; Update DIRENT
						PUSh	WORD PTR ES:[DI+DIRENT_FIRST_CLUSTER] ; Remember first cluster
						MOV		WORD PTR ES:[DI+DIRENT_FIRST_CLUSTER],0
						MOV		DWORD PTR ES:[DI+DIRENT_FILE_SIZE],0
						; Mark Buffer Dirty
						OR		BYTE PTR ES:[BX+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN


						; Check Drive Not Ready or Disk Write Protected
						PUSH	GS
						PUSH	BP
						PUSH	DS
						PUSH	DI
						PUSH	BX
						PUSH	DX

						PUSH	ES
						POP		DS
						MOV		SI,BX
						CALL	BUFFER_TESTWRITE

						POP		DX
						POP		BX
						POP		DI
						POP		DS
						POP		BP
						POP		GS

						JC		CREATE_DISK_FILE_ERR


						PUSH	ES
						POP		DS
						MOV		SI,DI
						LFS		DI,CS:[CUR_SF_ENTRY]
						MOV		AL,SF_MODE_READ_WRITE
						; No reading from a new file, so I thought, but looks like it needs to be READ_WRITE
						; Towns OS Installer creates a file, and fully expecting it is readable.
						MOV		DX,SI
						SUB		DX,BX
						SUB		DX,IO_BUF_INFO_size
						MOVZX	EBX,WORD PTR DS:[BX+IO_BUF_SECTOR_NUM]
						; Input
						;   DS:SI  DIRENT
						;   FS:DI  SF_ENTRY
						;   GS:BP  DPB
						;   AL     Open Mode
						;   BX     DIRENT Sector
						;   DX     DIRENT Position in Sector in bytes.
						; Not for CHARDEV
						CALL	MAKE_SF_ENTRY_FROM_DIRENT
						AND		WORD PTR FS:[DI+SF_DEVFLAGS],0ffffh-SF_DEVFLAG_BLOCK_NOT_WRITTEN

						POP		BX
						CALL	FREE_CLUSTER_CHAIN
						MOV		WORD PTR GS:[BP+DPB_NUM_FREE_CLUSTERS],0ffffh

						CLC
						RET



CREATE_DISK_FILE_NOT_EXIST:
						; FILE_NOT_FOUND or NO_MORE_FILES is OK.
						; DIR_NOT_FOUND is not.
						CMP		AX,DOSERR_DIR_NOT_FOUND
						JE		CREATE_DISK_FILE_DIR_NOT_FOUND

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER
						CALL	SEEK_LAST_BACKSLASH  ; AX destroyed, DS:DI is last backslash.
						CMP		BYTE PTR DS:[DI],'\'
						JNE		CREATE_DISK_FILE_ACCESS_DENIED
						CMP		BYTE PTR DS:[DI+1],0
						JE		CREATE_DISK_FILE_ACCESS_DENIED ; Original MSDOS.SYS returns DOSERR_ACCESS_DENIED for attempt to open "C:\"

						; GS:BP  DPB
						; EAX    First Cluster of the Directory (0=Root)
						MOV		EAX,DWORD PTR CS:[DIR_CLUSTER0]
						CALL	ALLOC_DIRENT
						JC		CREATE_DISK_DIRECTORY_FULL

						;   CF=0   Success.  DS:SI=DIRENT,  DS:BX=BUFFER HEADER

						OR		BYTE PTR DS:[BX+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN

						MOV		EAX,DWORD PTR CS:[TEMPORARY_DIRENT]
						MOV		DWORD PTR DS:[SI+DIRENT_FILENAME],EAX	; MASM Bug. Unless explicitly specify DWORD PTR, it takes as WORD PTR.
						MOV		EAX,DWORD PTR CS:[TEMPORARY_DIRENT+4]
						MOV		DWORD PTR DS:[SI+DIRENT_FILENAME+4],EAX	; MASM Bug. Unless explicitly specify DWORD PTR, it takes as WORD PTR.
						MOV		EAX,DWORD PTR CS:[TEMPORARY_DIRENT+7]
						MOV		DWORD PTR DS:[SI+DIRENT_FILENAME+7],EAX	; MASM Bug. Unless explicitly specify DWORD PTR, it takes as WORD PTR.

						MOV		AL,CS:[FILE_CREATE_ATTRIB]
						MOV		DS:[SI+DIRENT_ATTR],AL

						PUSH	DS
						PUSH	SI
						PUSH	BX
						CALL	READ_CLOCK_FOR_DIRENT
						POP		BX
						POP		SI
						POP		DS
						MOV		DS:[SI+DIRENT_TIME],DX
						MOV		DS:[SI+DIRENT_DATE],AX

						XOR		EAX,EAX
						MOV		DWORD PTR DS:[SI+0Ch],EAX
						MOV		DWORD PTR DS:[SI+10h],EAX
						MOV		WORD PTR DS:[SI+14h],AX
						MOV		WORD PTR DS:[SI+DIRENT_FIRST_CLUSTER],AX
						MOV		DWORD PTR DS:[SI+DIRENT_FILE_SIZE],EAX

						MOVZX	EDX,SI
						SUB		DX,BX
						SUB		DX,IO_BUF_INFO_size	; DX is bytes into sector.


						; Check Drive Not Ready or Disk Write Protected
						PUSH	GS
						PUSH	BP
						PUSH	DS
						PUSH	SI
						PUSH	BX
						PUSH	DX

						MOV		SI,BX
						CALL	BUFFER_TESTWRITE

						POP		DX
						POP		BX
						POP		SI
						POP		DS
						POP		BP
						POP		GS

						JC		CREATE_DISK_FILE_ERR


						LFS		DI,CS:[CUR_SF_ENTRY]
						MOV		AL,SF_MODE_READ_WRITE
						; No reading from a new file, so I thought, but looks like it needs to be READ_WRITE
						; Towns OS Installer creates a file, and fully expecting it is readable.
						MOV		BX,DS:[BX+IO_BUF_SECTOR_NUM]
						; Make SF_ENTRY from DIRENT
						;   DS:SI  DIRENT
						;   FS:DI  SF_ENTRY
						;   GS:BP  DPB
						;   AL     Open Mode
						;   BX     DIRENT Sector
						;   DX     DIRENT Position in Sector in bytes.
						CALL	MAKE_SF_ENTRY_FROM_DIRENT

						CLC
						RET

CREATE_DISK_FILE_ERR:
						STC
						RET


CREATE_DISK_DIRECTORY_FULL:
						MOV		AX,DOSERR_NO_MORE_FILES
						STC
						RET

CREATE_DISK_FILE_INVALID_DRIVE:
						MOV		AX,DOSERR_INVALID_DRIVE
						STC
						RET

CREATE_DISK_FILE_INVALID_FILE_NAME:
						MOV		AX,DOSERR_DIR_NOT_FOUND	; Is it right error code for invalid char?
						STC
						RET

CREATE_DISK_FILE_ACCESS_DENIED:
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET

CREATE_DISK_FILE_INVALID_ACCESS:
						MOV		AX,DOSERR_INVALID_ACCESS
						STC
						RET

CREATE_DISK_FILE_DIR_NOT_FOUND:
						MOV		AX,DOSERR_DIR_NOT_FOUND
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI=Filename
FDELETE:
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME],SI
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME+2],DS

						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						JC		FDELETE_EXIT

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER
						CALL	CHECK_WILDCARD_PRESENCE_CSTR
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JC		FDELETE_EXIT

						CMP		WORD PTR CS:[FILENAME_BUFFER+1],02F3Ah ; ':\'
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JE		FDELETE_EXIT

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	GET_DRIVE_CDS
						MOV		AX,DOSERR_INVALID_DRIVE
						JC		FDELETE_EXIT

						; Output
						;   CF=0  DS:BX=CDS      AX Destroyed
						;   CF=1  Drive invalid  AX=DOSERR_INVALID_DRIVE   DS,BX Destroyed
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		FDELETE_NOT_REDIRECTED

						MOV		AX,INT2FH_DELETE
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1],OFFSET FILENAME_BUFFER_PTR1
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1+2],CS
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],BX
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],DS
						PUSH	CS
						POP		DS
						; SS=DS=CS
						; SDA File Name Buffer Pointer 1=Full-Path Name
						INT		2FH
						JMP		FDELETE_EXIT


FDELETE_NOT_REDIRECTED:
						PUSH	DS
						PUSH	BX
						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	MEDIACHECK_READYCDS		; CF=1 Error  CF=0 AL=(0:No Change  1:Disk Changed)
						POP		BX
						POP		DS
						MOV		AX,DOSERR_ACCESS_DENIED

						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]
						XOR		EAX,EAX
						MOV		CX,0FFh-DIRENT_ATTR_VOLLABEL
						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3

						; Input
						;   GS:BP  DPB
						;   DS:SI  Starting pointer in the fully-qualified file name.
						;          If the file name is:
						;            C:\COMMAND.COM
						;               ^SI must point this.
						;   EAX    Starting cluster (0->Root Dir)
						;   CX     Attribute Filter, High-Byte ignored.
						CALL	FETCH_DIR
						; Return
						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
						;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
						;   Lastly scanned directory cluster can be found in DIR_variables

						MOV		CX,AX
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JC		FDELETE_EXIT

						MOV		AX,DOSERR_ACCESS_DENIED
						TEST	CX,DIRENT_ATTR_READONLY+DIRENT_ATTR_VOLLABEL+DIRENT_ATTR_DIRECTORY
						STC
						JNE		FDELETE_EXIT

						MOV		BYTE PTR ES:[DI+DIRENT_FILENAME],DELETED_FILE_FIRST_BYTE
						OR		BYTE PTR ES:[BX+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN

						MOV		WORD PTR GS:[BP+DPB_NUM_FREE_CLUSTERS],0ffffh

						MOV		BX,ES:[DI+DIRENT_FIRST_CLUSTER]
						CALL	FREE_CLUSTER_CHAIN
						; Don't look back.

						CLC

FDELETE_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



MKDIR_DIRENT_TEMPLATE	DB	".          "
						DB	DIRENT_ATTR_READONLY+DIRENT_ATTR_DIRECTORY
						DB	10 dup(0)
MKDIR_DIRENT_TMPL_TIME0	DW	0
MKDIR_DIRENT_TMPL_DATE0	DW	0
MKDIR_DIRENT_TMPL_CLST0	DW	0
						DD	0

						DB	"..         "
						DB	DIRENT_ATTR_READONLY+DIRENT_ATTR_DIRECTORY
						DB	10 dup(0)
MKDIR_DIRENT_TMPL_TIME1	DW	0
MKDIR_DIRENT_TMPL_DATE1	DW	0
MKDIR_DIRENT_TMPL_CLST1	DW	0
						DD	0



; Input
;   DS:SI=FIlename
; Return
;   CF=0 Success
;   CF=1 AX=Error Code
MKDIR:
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME],SI
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME+2],DS

						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						JC		MKDIR_EXIT

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	MEDIACHECK_READYCDS		; CF=1 Error  CF=0 AL=(0:No Change  1:Disk Changed)
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		MKDIR_EXIT

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	GET_DRIVE_CDS
						MOV		AX,DOSERR_INVALID_DRIVE
						JC		MKDIR_EXIT

						; Output
						;   CF=0  DS:BX=CDS      AX Destroyed
						;   CF=1  Drive invalid  AX=DOSERR_INVALID_DRIVE   DS,BX Destroyed
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		MKDIR_NOT_REDIRECTED

;MKDIR_REDIRECTED:
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1],OFFSET FILENAME_BUFFER
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1+2],CS
						MOV		AX,INT2FH_MKDIR
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],BX
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],DS
						INT		2FH
						RET

MKDIR_NOT_REDIRECTED:
						LGS		BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3
						XOR		EAX,EAX
						MOV		CX,0FFFFh-DIRENT_ATTR_VOLLABEL
						;   GS:BP  DPB
						;   DS:SI  Starting pointer in the fully-qualified file name.
						;          If the file name is:
						;            C:\COMMAND.COM
						;               ^SI must point this.
						;   EAX    Starting cluster (0->Root Dir)
						;   CX     Attribute Filter, High-Byte ignored.
						CALL	FETCH_DIR
						; Return
						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
						;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
						;   Lastly scanned directory cluster can be found in DIR_variables
						; Don't expect registers are preserved.

						JNC		MKDIR_ACCESS_DENIED	; If it already exists, cannot create a directory.

						MOV		EBX,DWORD PTR CS:[DIR_CLUSTER0]	; This will be for ".."
						MOV		CS:[MKDIR_DIRENT_TMPL_CLST1],BX

						CALL	READ_CLOCK_FOR_DIRENT
						MOV		CS:[MKDIR_DIRENT_TMPL_TIME0],DX
						MOV		CS:[MKDIR_DIRENT_TMPL_DATE0],AX
						MOV		CS:[MKDIR_DIRENT_TMPL_TIME1],DX
						MOV		CS:[MKDIR_DIRENT_TMPL_DATE1],AX


						; Input
						;   DX     Cluster to start search
						;   GS:BP  DPB
						XOR		DX,DX
						CALL	FIND_FREE_CLUSTER
						; Output
						;   CF=0   EDX=Free cluster
						;   CF=1   EDX Destroyed
						MOV		AX,DOSERR_DISK_FULL
						JC		MKDIR_EXIT

						;   CF=0   Save cluster in MKDIR_DIRENT_TMPL_CLST0
						MOV		CS:[MKDIR_DIRENT_TMPL_CLST0],DX

						CALL	CLUSTER_TO_SECTOR	; EDX in EBX out

						; EBX=Sector

						MOVZX	ECX,BYTE PTR GS:[BP+DPB_CLUSTER_MASK]
						INC		ECX
						OR		ECX,80000000h
MKDIR_INIT_SECTOR_LOOP:
						PUSH	ECX
						PUSH	EBX

						; Input
						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						;          AL!=0 Don't read sector (Just make an available buffer)
						MOV		EDX,EBX
						XOR		AL,AL
						CALL	GETBUFFER_REGULAR
						; Output
						;   CF=0   DS:DI=Buffer
						;   CF=1   Error
						;   AX     Destroyed
						;   DX     Destroyed
						;   Hiword EDI  Destroyed
						OR		BYTE PTR DS:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN+IO_BUF_FLAG_IS_DIR

						MOV		CX,GS:[BP+DPB_BYTES_PER_SECTOR]
						XOR		AL,AL
						ADD		DI,IO_BUF_INFO_size
						PUSH	DS
						POP		ES

						PUSH	DI
						REP STOSB
						POP		DI

						POP		EBX	; Was missing and added 2021/03/31
						POP		ECX	; Was missing and added 2021/03/31
						TEST	ECX,80000000h
						PUSH	ECX	; Was missing and added 2021/03/31
						PUSH	EBX	; Was missing and added 2021/03/31
						JE		MKDIR_INIT_SECTOR_NEXT

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET MKDIR_DIRENT_TEMPLATE
						MOV		CX,64
						REP MOVSB

						; There still is a possibility of disk write protected.
						; It's a good time to check.
						PUSH	ES
						POP		DS
						LEA		SI,[DI-(64+IO_BUF_INFO_size)]
						CALL	BUFFER_TESTWRITE
						JC		MKDIR_DISK_ERROR

MKDIR_INIT_SECTOR_NEXT:
						POP		EBX
						POP		ECX
						AND		ECX,7FFFFFFFh
						INC		EBX
						LOOP	MKDIR_INIT_SECTOR_LOOP


						_LDS	SI,CS:[FILE_INPUT_FILENAME]
						MOV		CX,DIRENT_ATTR_DIRECTORY
						PUSH	GS	; Just in case, I think GS:BP is saved.
						PUSH	BP
						CALL	FCREATE_IF_NOT_EXIST
						POP		BP
						POP		GS
						JC		MKDIR_EXIT

						; Now reserve the cluster.
						PUSH	AX
						CALL	GET_TAIL_CLUSTER_THRESHOLD	; DX is terminator cluster.
						MOV		BX,CS:[MKDIR_DIRENT_TMPL_CLST0]
						CALL	WRITE_CLUSTER
						CALL	DEC_AVAIL_CLUSTER_COUNT
						POP		AX


						PUSH	AX
						CALL	GET_SF_ENTRY_FROM_JFN
						; FS:DI=SF_ENTRY
						MOV		BX,CS:[MKDIR_DIRENT_TMPL_CLST0]
						MOV		FS:[DI+SF_FIRST_CLUSTER_NUM],BX
						AND		WORD PTR FS:[DI+SF_DEVFLAGS],0ffffh-SF_DEVFLAG_BLOCK_NOT_WRITTEN
						POP		AX

						CALL	FCLOSE

MKDIR_EXIT:
						RET

MKDIR_DISK_ERROR:
						POP		EBX
						POP		ECX
						STC
						RET

MKDIR_DIR_NOT_FOUND:
						MOV		AX,DOSERR_DIR_NOT_FOUND
						STC
						RET

MKDIR_ACCESS_DENIED:
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  DS:SI=Filename
;Output
;  CF=0 Success
;  CF=1 AX=DOS Error Code
RMDIR:
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME],SI
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME+2],DS

						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						JC		RMDIR_EXIT

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	MEDIACHECK_READYCDS		; CF=1 Error  CF=0 AL=(0:No Change  1:Disk Changed)
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		RMDIR_EXIT

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	GET_DRIVE_CDS
						MOV		AX,DOSERR_INVALID_DRIVE
						JC		RMDIR_EXIT

						; Output
						;   CF=0  DS:BX=CDS      AX Destroyed
						;   CF=1  Drive invalid  AX=DOSERR_INVALID_DRIVE   DS,BX Destroyed
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		RMDIR_NOT_REDIRECTED

;RMDIR_REDIRECTED:
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1],OFFSET FILENAME_BUFFER
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1+2],CS
						MOV		AX,INT2FH_RMDIR
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],BX
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],DS
						INT		2FH
						RET

RMDIR_NOT_REDIRECTED:
						LGS		BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3
						XOR		EAX,EAX
						MOV		CX,DIRENT_ATTR_DIRECTORY
						;   GS:BP  DPB
						;   DS:SI  Starting pointer in the fully-qualified file name.
						;          If the file name is:
						;            C:\COMMAND.COM
						;               ^SI must point this.
						;   EAX    Starting cluster (0->Root Dir)
						;   CX     Attribute Filter, High-Byte ignored.
						CALL	FETCH_DIR
						; Return
						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
						;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
						;   Lastly scanned directory cluster can be found in DIR_variables
						JC		RMDIR_ACCESS_DENIED

						TEST	AX,DIRENT_ATTR_DIRECTORY
						JE		RMDIR_ACCESS_DENIED


						MOVZX	EBX,WORD PTR ES:[DI+DIRENT_FIRST_CLUSTER]
RMDIR_CLUSTER_LOOP:
						PUSH	EBX
						XCHG	EDX,EBX	; EDX=Cluster for the dir
						CALL	CLUSTER_TO_SECTOR
						; EBX=Sector
						MOVZX	CX,BYTE PTR GS:[BP+DPB_CLUSTER_MASK]
						INC		CX
						; CX=Number of Sectors
RMDIR_SECTOR_LOOP:
						PUSH	EBX
						PUSh	CX
						; Input
						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						;          AL!=0 Don't read sector (Just make an available buffer)
						MOV		EDX,EBX
						XOR		AL,AL
						CALL	GETBUFFER_REGULAR
						; Output
						;   CF=0   DS:DI=Buffer
						;   CF=1   Error
						;   AX     Destroyed
						;   DX     Destroyed
						;   Hiword EDI  Destroyed
						JC		RMDIR_SECTOR_READ_ERROR
						OR		BYTE PTR DS:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_DIR

						ADD		DI,IO_BUF_INFO_size
						MOV		CX,GS:[BP+DPB_BYTES_PER_SECTOR]
						SHR		CX,DIRENT_SHIFT
RMDIR_DIRENT_LOOP:
						CMP		BYTE PTR DS:[DI],0
						JE		RMDIR_DIRENT_NEXT
						CMP		BYTE PTR DS:[DI],DELETED_FILE_FIRST_BYTE
						JE		RMDIR_DIRENT_NEXT

						; If not, only acceptable are "." and ".."
						CMP		DWORD PTR [DI+4],20202020h
						JNE		RMDIR_DIR_NOT_EMPTY
						CMP		DWORD PTR [DI+7],20202020h
						JNE		RMDIR_DIR_NOT_EMPTY

						CMP		DWORD PTR [DI],2020202Eh	; ".   "
						JE		RMDIR_DIRENT_NEXT
						CMP		DWORD PTR [DI],20202E2Eh	; "..  "
						JE		RMDIR_DIRENT_NEXT
						JMP		RMDIR_DIR_NOT_EMPTY
RMDIR_DIRENT_NEXT:
						ADD		DI,DIRECTORY_ENTRY_size
						LOOP	RMDIR_DIRENT_LOOP

						POP		CX
						POP		EBX
						INC		EBX
						LOOP	RMDIR_SECTOR_LOOP

						POP		EBX

						; Input
						;   GS:BP  Drive Parameter Block
						;   BX     Cluster
						CALL	GET_NEXT_CLUSTER
						; Output
						;   CF=0   DX=Next Cluster
						;   CF=1   DX Destroyed
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		RMDIR_EXIT

						MOV		EBX,EDX
						CMP		BX,GS:[DPB_MAX_CLUSTER_NUM]
						JBE		RMDIR_CLUSTER_LOOP


						; Cluster is empty.
						; Need to re-fetch the DIRENT.  Buffer may be flushed.

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3
						XOR		EAX,EAX
						MOV		CX,DIRENT_ATTR_DIRECTORY
						;   GS:BP  DPB
						;   DS:SI  Starting pointer in the fully-qualified file name.
						;          If the file name is:
						;            C:\COMMAND.COM
						;               ^SI must point this.
						;   EAX    Starting cluster (0->Root Dir)
						;   CX     Attribute Filter, High-Byte ignored.
						CALL	FETCH_DIR
						; Return
						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
						;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
						;   Lastly scanned directory cluster can be found in DIR_variables
						; Don't expect registers are preserved.

						JC		RMDIR_ACCESS_DENIED	; Supposed to be succeed, but just in case.

						MOV		BYTE PTR ES:[DI],DELETED_FILE_FIRST_BYTE
						OR		BYTE PTR ES:[BX+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN

						MOVZX	EBX,WORD PTR ES:[DI+DIRENT_FIRST_CLUSTER]
						CALL	FREE_CLUSTER_CHAIN
						; Don't look back...

						CLC

RMDIR_EXIT:
						RET

RMDIR_DIR_NOT_EMPTY:
						ADD		SP,10	; EBX,EBX,CX
						MOV		AX,DOSERR_ACCESS_DENIED	; Is it the right error code?
						STC
						RET

RMDIR_SECTOR_READ_ERROR:
						ADD		SP,10	; EBX,EBX,CX
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET

RMDIR_ACCESS_DENIED:
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  BL=0 -> IOCTL_GET_DEVINFO
;  BL=1 -> IOCTL_SET_DEVINFO
;  BL=2 -> IOCTL_READ
;  BL=9 -> IOCTL_CHECK_REMOTE_DRIVE AL=Drive (0=A:) -> DX=Device Attribute Word
;Output
;  BL destroyed.
;  Registers destroyed from IOCTL functions.
IOCTL:
						OR		BL,BL				;0
						JE		IOCTL_GET_DEVINFO
						DEC		BL					;1
						JE		IOCTL_SET_DEVINFO
						DEC		BL					;2
						JE		IOCTL_READ_CHARDEV
						DEC		BL					;3
						DEC		BL					;4
						DEC		BL					;5
						DEC		BL					;6
						DEC		BL					;7
						DEC		BL					;8
						JE		IOCTL_CHECK_DRIVE_REMOVABLE
						DEC		BL					;9
						JE		IOCTL_CHECK_REMOTE_DRIVE
						MOV		AX,DOSERR_INVALID_FUNC
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX  File Handle (JFN)
; Output
;   CF=0  DL=Lobyte of SF_DEVFLAGS
;     If disk file DH=00h
;     If CHARDEV   DH=Hibyte of SYSDEV_DEVFLAGS  
;   CF=1  Error  AX=Error Code
; AX,BX Destroyed from GET_SF_ENTRY_FROM_JFN
IOCTL_GET_DEVINFO:
						PUSH	FS
						PUSH	DI

						CALL	GET_SF_ENTRY_FROM_JFN
						MOV		AX,DOSERR_INVALID_HANDLE
						JC		IOCTL_GET_DEVINFO_EXIT

						MOV		DX,FS:[DI+SF_DEVFLAGS]
						TEST	DX,SF_DEVFLAG_IS_CHARDEV
						JNE		IOCTL_GET_DEVINFO_EXIT_CHARDEV
						XOR		DH,DH
						JMP		IOCTL_GET_DEVINFO_NOERR

IOCTL_GET_DEVINFO_EXIT_CHARDEV:
						LFS		DI,FS:[DI+SF_DRIVER_POINTER]	; It's CHARDEV. FS:DI is SYSDEV
						MOV		DH,BYTE PTR FS:[DI+SYSDEV_DEVFLAGS+1]

IOCTL_GET_DEVINFO_NOERR:
						CLC
IOCTL_GET_DEVINFO_EXIT:
						POP		DI
						POP		FS
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  AX=File Handle(JFN)
;  DX=Device Information.  DH must be zero.
;Return
;  CF=0 Success
;  CF=1 AX=Error Code
; AX,BX Destroyed from GET_SF_ENTRY_FROM_JFN
IOCTL_SET_DEVINFO:
						PUSH	FS
						PUSH	DI

						OR		DH,DH
						STC
						MOV		AX,DOSERR_INVALID_DATA
						JNE		IOCTL_SET_DEVINFO_EXIT

						CALL	GET_SF_ENTRY_FROM_JFN
						MOV		AX,DOSERR_INVALID_HANDLE
						JC		IOCTL_SET_DEVINFO_EXIT

						MOV		BYTE PTR FS:[DI+SF_DEVFLAGS],DL

IOCTL_SET_DEVINFO_EXIT:
						POP		DI
						POP		FS
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  AX=File Handle(JFN)
;  CX=Bytes to read
;  DS:DX=Data Buffer
;Return
;  CF=0 Success
;  CF=1 AX=Error Code
; AX,BX Destroyed from GET_SF_ENTRY_FROM_JFN
; DX Preserved
IOCTL_READ_CHARDEV:
						PUSH	FS
						PUSH	DI
						PUSH	DX

						PUSh	DS
						PUSH	CX
						CALL	GET_SF_ENTRY_FROM_JFN
						POP		CX
						POP		DS
						MOV		AX,DOSERR_INVALID_HANDLE
						JC		IOCTL_READ_CHARDEV_EXIT

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						STC
						MOV		AX,DOSERR_INVALID_FUNC
						JE		IOCTL_READ_CHARDEV_EXIT

						; Input
						;   AX     Zero (May be needed)
						;   CX     Length in bytes
						;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
						;   EDI    Data Buffer (Hiword=SEG, Loword=OFFSET)
						XOR		AX,AX	; Just in case
						MOV		ESI,FS:[DI+SF_DRIVER_POINTER] ; It's CHARDEV it is SYSDEV
						; I can forget FS:DI
						MOV		DI,DS
						SHL		EDI,16
						MOV		DI,DX
						CALL	DEVCALL_IOCTL_READ
						JNC		IOCTL_READ_CHARDEV_EXIT

						CALL	DEVERR_TO_DOSERR

IOCTL_READ_CHARDEV_EXIT:
						POP		DX
						POP		DI
						POP		FS
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AL=Drive (0=Current, 1=A:) -> If remote drive DX=0800h, if local DX=SYSDEV_DEVFLAGS
; Observation from MSDOS V3.1: If the drive is valid, returns AX=0300h.
IOCTL_CHECK_REMOTE_DRIVE:
						MOVZX	AX,AL
						CALL	FCBDRIVE_TO_SANE_DRIVE
						CALL	GET_DRIVE_CDS
						JC		IOCTL_CHECK_REMOTE_INVALID_DRIVE

						;   CF=0  DS:BX=CDS      AX Destroyed
						XOR		DX,DX
						MOV		AX,0300h
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		IOCTL_CHECK_REMOTE_NOT_REMOTE

						MOV		DX,01000h	; Bit12=Remote Drive
						CLC
						RET

IOCTL_CHECK_REMOTE_NOT_REMOTE:
						LGS		BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]
						LES		DI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						MOV		DX,ES:[DI+SYSDEV_DEVFLAGS]
						CLC		; Should be redundant
						RET

IOCTL_CHECK_REMOTE_INVALID_DRIVE:
						MOV		AX,DOSERR_INVALID_DRIVE
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



IOCTL_CHECK_DRIVE_REMOVABLE:
						MOVZX	AX,AL
						CALL	FCBDRIVE_TO_SANE_DRIVE
						CALL	GET_DRIVE_CDS
						JC		IOCTL_CHECK_REMOTE_INVALID_DRIVE

						;   CF=0  DS:BX=CDS      AX Destroyed
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		IOCTL_CHECK_DRV_RMVBL_NOT_REDIR
;IOCTL_CHECK_DRV_RMVBL_REDIR
						; How can I check if the redirected drive is removable?
						JMP		IOCTL_CHECK_DRV_RMVBL_INVALID_DRIVE

IOCTL_CHECK_DRV_RMVBL_NOT_REDIR:
						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]
						_LES	DI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						TEST	WORD PTR ES:[DI+SYSDEV_DEVFLAGS],SYSDEV_DEVFLAG_OPEN_CLOSE_SUPPORTED
						SETNZ	AL
						XOR		AH,AH
						CLC
						RET


IOCTL_CHECK_DRV_RMVBL_INVALID_DRIVE:
						MOV		AX,DOSERR_INVALID_DRIVE
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Registered destroyed.
CLOSE_ALL_FILES_FOR_CURPDB:
						MOV		AX,INT2FH_CLOSE_ALL_FILES_CURRENTPSP
						INT		2Fh

						MOV		AX,0
CLOSE_FILES_FOR_CURPDB_LOOP:
						PUSH	AX
						CALL	FCLOSE
						POP		AX
						INC		AX
						MOV		DS,[CurrentPDB]
						CMP		AX,DS:[PSP_FILE_TABLE_SIZE]
						JB		CLOSE_FILES_FOR_CURPDB_LOOP

						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




CLOSE_ALL_FCB_FOR_CURPDB:
						; Need to close FCB for currentpdb
						; See 1679:00003480
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX=File Handle
; Output
;   CF=0 AX=New File Handle
;   CF=1 AX=DOS Error Code
; Destroys FS:DI, DS:SI, CX
DUPLICATE_FILE_HANDLE:
						CALL	GET_SFN_FROM_JFN
						JNC		DUPLICATE_FHANDLE_HAVE_SFN
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JMP		DUPLICATE_FHANDLE_EXIT

DUPLICATE_FHANDLE_HAVE_SFN:
						; AX=SFN
						PUSH	AX
						CALL	GET_SF_ENTRY_FROM_SFN
						POP		AX
						JNC		DUPLICATE_FHANDLE_HAVE_SF_ENTRY
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JMP		DUPLICATE_FHANDLE_EXIT

DUPLICATE_FHANDLE_HAVE_SF_ENTRY:
						; FS:DI=SF_ENTRY

						PUSH	FS
						PUSH	DI
						CALL	GET_AVAILABLE_JFN		; BX=Available JFN of current PDB
						; Preserves EAX
						POP		DI
						POP		FS
						JNC		DUPLICATE_FILE_HANDLE_HAVE_NEWJFN
						MOV		AX,DOSERR_TOO_MANY_OPEN_FILES
						JMP		DUPLICATE_FHANDLE_EXIT

DUPLICATE_FILE_HANDLE_HAVE_NEWJFN:
						; BX=Available File Handle (JFN)

						;   BX  JFN (New File Handle)
						;   DL  SFN
						MOV		DL,AL
						CALL	RESERVE_JFN	; Destroys GS.  Everythign else preserved

						; Don't need SFN any more.

						MOV		AX,BX
						INC		WORD PTR FS:[DI+SF_REFCOUNT]
						CLC

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_REDIRECTED
						JNE		DUPLICATE_FHANDLE_EXIT ; If redirected, it's done.
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						JE		DUPLICATE_FHANDLE_EXIT ; If BLOCKDEV, it's done.

						LDS		SI,FS:[DI+SF_DRIVER_POINTER]
						TEST	WORD PTR DS:[SI+SYSDEV_DEVFLAGS],SYSDEV_DEVFLAG_OPEN_CLOSE_SUPPORTED
						JE		DUPLICATE_FHANDLE_EXIT ; If Open/Close/Removable unsupported, it's done.

						PUSH	AX

						;	AL  DEVREQ Command
						;   CH  Unit
						;   DS:SI  Device Driver Pointer
						MOV		AL,DEVREQ_CMD_OPEN
						MOV		CH,0
						CALL	DEVCALL_OPEN_OR_CLOSE
						; Don't look back...

						POP		AX

DUPLICATE_FHANDLE_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX=File Handle to Duplicate
;   CX=File Handle that also points to File pointed by AX
; Output
;   Close CX, and copy SFN of AX to CX.
FORCE_DUPLICATE_FILE_HANDLE:
						CMP		AX,CX
						JE		FORCE_DUP_FHANDLE_EXIT

						PUSH	CX
						PUSH	AX
						MOV		AX,CX
						CALL	FCLOSE
						POP		AX

						CALL	GET_SFN_SFENTRY_FROM_JFN
						JC		FORCE_DUP_FHANDLE_EXIT

						; AX=SFN
						; FS:DI=SF_ENTRY

						POP		BX

						;   BX  JFN (Destination File Handle)
						;   DL  SFN
						MOV		DL,AL
						CALL	RESERVE_JFN	; Destroys GS.  Everythign else preserved

						; Don't need SFN any more.

						MOV		AX,BX
						INC		WORD PTR FS:[DI+SF_REFCOUNT]
						CLC

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_REDIRECTED
						JNE		FORCE_DUP_FHANDLE_EXIT ; If redirected, it's done.
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						JE		FORCE_DUP_FHANDLE_EXIT ; If BLOCKDEV, it's done.

						LDS		SI,FS:[DI+SF_DRIVER_POINTER]
						TEST	WORD PTR DS:[SI+SYSDEV_DEVFLAGS],SYSDEV_DEVFLAG_OPEN_CLOSE_SUPPORTED
						JE		FORCE_DUP_FHANDLE_EXIT ; If Open/Close/Removable unsupported, it's done.

						PUSH	AX

						;	AL  DEVREQ Command
						;   CH  Unit
						;   DS:SI  Device Driver Pointer
						MOV		AL,DEVREQ_CMD_OPEN
						MOV		CH,0
						CALL	DEVCALL_OPEN_OR_CLOSE
						; Don't look back...

						POP		AX


FORCE_DUP_FHANDLE_EXIT:
						RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI=C-String Filename
; Return
;   CF=0 CX=File Attribute
;   CF=1 AX=DOSERR
GET_FILE_ATTRIB:
						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						JC		SET_GET_FILE_ATTRIB_DIR_NOT_FOUND

						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	GET_DRIVE_CDS
						JC		SET_GET_FILE_ATTRIB_INVALID_DRIVE

						PUSH	DS

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER
						CALL	CHECK_WILDCARD_PRESENCE_CSTR
						JC		SET_GET_FILE_ATTRIB_DIR_NOT_FOUND

						POP		DS



						; DS:BX is CDS
						; INT 2FH demands CDS pointer to be in CS:[CURRENT_CDS_STRUCT]
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],BX
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],CS

						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1],OFFSET FILENAME_BUFFER
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1+2],CS

						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		GET_FILE_ATTRIB_NOT_REDIRECTED

;GET_FILE_ATTRIB_REDIRECTED:
						MOV		BYTE PTR CS:[SATTR],DIRENT_ATTR_HIDDEN+DIRENT_ATTR_SYSTEM+DIRENT_ATTR_DIRECTORY
						MOV		AX,INT2FH_GET_FILE_ATTRIB
						INT		2Fh
						MOV		CX,AX
						RET


GET_FILE_ATTRIB_NOT_REDIRECTED:
						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3
						XOR		EAX,EAX

						MOV		CX,DIRENT_ATTR_HIDDEN+DIRENT_ATTR_SYSTEM+DIRENT_ATTR_DIRECTORY

						; Input
						;   GS:BP  DPB
						;   DS:SI  Starting pointer in the fully-qualified file name.
						;          If the file name is:
						;            C:\COMMAND.COM
						;               ^SI must point this.
						;   EAX    Starting cluster (0->Root Dir)
						;   CX     Attribute Filter, High-Byte ignored.
						CALL	FETCH_DIR
						; Return
						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
						;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
						;   Lastly scanned directory cluster can be found in DIR_variables
						; Don't expect registers are preserved.

						MOV		CX,AX  ; CX is file attribute if CF=0, or dos error code if CF=1, in which case I don't care.
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; CHMOD
; Input
;   CX=File Attribute
;   DS:SI=C-String Filename
; Return
;   CF=1 AX=DOSERR
SET_FILE_ATTRIB:
						MOV		CS:[SATTR],CL

						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						JC		SET_GET_FILE_ATTRIB_DIR_NOT_FOUND

						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	GET_DRIVE_CDS
						JC		SET_GET_FILE_ATTRIB_INVALID_DRIVE

						; DS:BX is CDS
						; INT 2FH demands CDS pointer to be in CS:[CURRENT_CDS_STRUCT]
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],BX
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],DS

						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1],OFFSET FILENAME_BUFFER
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1+2],CS

						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		SET_FILE_ATTRIB_NOT_REDIRECTED

;SET_FILE_ATTRIB_REDIRECTED:
						MOVZX	AX,BYTE PTR CS:[SATTR]
						PUSH	AX
						MOV		AX,INT2FH_SET_FILE_ATTRIB
						INT		2Fh
						POP		BX	; BX carries no information at this time.
						RET


SET_FILE_ATTRIB_NOT_REDIRECTED:
						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3
						XOR		EAX,EAX

						; I need DIRENT_ARCHIVE flag so that Towns OS V2.1 L51 installer will find IO.SYS
						; I don't know if it is the correct way or FETCH_DIR should do differently.
						MOV		CX,DIRENT_ATTR_HIDDEN+DIRENT_ATTR_SYSTEM+DIRENT_ATTR_DIRECTORY+DIRENT_ATTR_ARCHIVE

						; Input
						;   GS:BP  DPB
						;   DS:SI  Starting pointer in the fully-qualified file name.
						;          If the file name is:
						;            C:\COMMAND.COM
						;               ^SI must point this.
						;   EAX    Starting cluster (0->Root Dir)
						;   CX     Attribute Filter, High-Byte ignored.
						; Breaks CS:[SATTR]
						PUSH	WORD PTR CS:[SATTR]
						CALL	FETCH_DIR
						POP		WORD PTR CS:[SATTR]
						; Return
						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
						;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
						;   Lastly scanned directory cluster can be found in DIR_variables
						; Don't expect registers are preserved.
						JC		SET_FILE_ATTRIB_EXIT

						; DIRECTORY and VOLLABEL flags must not change.
						; Apparently if attempted to change DIRECTORY or VOLLABEL flag,
						; it just ignore the change rather than returning an error.
						; Otherwise Towns OS V2.1 L51 installer stops.
						; Towns OS V2.1 L51 installer wants to make IO.SYS hidden, system, DIRECTORY, and archive.
						MOV		CL,AL	; Save current attrib in CL.
						AND		CL,DIRENT_ATTR_DIRECTORY+DIRENT_ATTR_VOLLABEL

						MOV		AL,CS:[SATTR]
						AND		AL,0FFh-(DIRENT_ATTR_DIRECTORY+DIRENT_ATTR_VOLLABEL)

						OR		CL,AL
						MOV		ES:[DI+DIRENT_ATTR],CL
						OR		BYTE PTR ES:[BX+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN


						; Towns OS V1.1 L30 installer calls CHMOD between FOPEN and FCLOSE.
						; So, the implication is I need to also match open SF_ENTRY and also update the mode.
						PUSH	CX
						MOVZX	EDX,WORD PTR ES:[BX+IO_BUF_SECTOR_NUM]
						MOV		AX,DI
						SUB		AX,BX
						SUB		AX,IO_BUF_INFO_size
						SHR		AX,DIRENT_SHIFT
						ROL		EBP,16
						MOV		BP,GS
						ROL		EBP,16
						; EDX=Directory Sector
						; AX=Position in Directory Sector
						; EBP=DPB
						CALL	MATCH_SF_ENTRY_DIRENT_SECTOR
						; CF=0  FS:DI=SF_ENTRY
						; CF=1  No match
						POP		CX
						JC		SET_FILE_ATTRIB_NOERR
						MOV		FS:[DI+SF_ATTR],CL
SET_FILE_ATTRIB_NOERR:
						CLC

SET_FILE_ATTRIB_EXIT:
						RET

SET_GET_FILE_ATTRIB_ACCESS_DENIED:
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET

SET_GET_FILE_ATTRIB_INVALID_DRIVE:
						MOV		AX,DOSERR_INVALID_DRIVE
						STC
						RET

SET_GET_FILE_ATTRIB_DIR_NOT_FOUND:
						MOV		AX,DOSERR_DIR_NOT_FOUND
						STC
						RET

SET_GET_FILE_ATTRIB_INVALID_FUNC:
						MOV		AX,DOSERR_INVALID_FUNC
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX File Handle
; Return
;   CX=File Time
;   DX=File Date
GET_FILE_TIME_STAMP:
						CALL	GET_SF_ENTRY_FROM_JFN
						MOV		AX,DOSERR_INVALID_HANDLE
						JC		GET_FILE_TIME_STAMP_EXIT
						; FS:DI is SF_ENTRY
						MOV		CX,FS:[DI+SF_TIME]
						MOV		DX,FS:[DI+SF_DATE]
GET_FILE_TIME_STAMP_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX File Handle
; Return
;   CX=File Time
;   DX=File Date
SET_FILE_TIME_STAMP:
						CALL	GET_SF_ENTRY_FROM_JFN
						MOV		AX,DOSERR_INVALID_HANDLE
						JC		SET_FILE_TIME_STAMP_EXIT
						; FS:DI is SF_ENTRY
						MOV		FS:[DI+SF_TIME],CX
						MOV		FS:[DI+SF_DATE],DX
						AND		WORD PTR FS:[DI+5],0ffffh-SF_DEVFLAG_BLOCK_NOT_WRITTEN	; Mark as written.
						OR		WORD PTR FS:[DI+5],SF_DEVFLAG_BLOCK_TIME_SET			; So that FCLOSE won't overwrite.
SET_FILE_TIME_STAMP_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;  DS:SI=Input file name
;  ES:DI=True name
TRUENAME:
						PUSH	ES
						PUSH	DI
						CALL	MAKE_FULLPATH_CRUNCH
						POP		DI
						POP		ES
						JC		TRUENAME_EXIT

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER
						CALL	STRCPY

TRUENAME_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI=From
;   ES:DI=To
FRENAME:
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME],SI
						MOV		WORD PTR CS:[FILE_INPUT_FILENAME+2],DS
						MOV		WORD PTR CS:[FILE_FILENAME_2],DI
						MOV		WORD PTR CS:[FILE_FILENAME_2+2],ES

						; Check From-Filename
						CALL	CHECK_WILDCARD_PRESENCE_CSTR
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JC		FRENAME_EXIT

						; Check To-Filename
						_LDS	SI,CS:[FILE_FILENAME_2]
						CALL	CHECK_WILDCARD_PRESENCE_CSTR
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JC		FRENAME_EXIT

						_LDS	SI,CS:[FILE_FILENAME_2]
						CALL	MAKE_FULLPATH_CRUNCH	; No wildcard

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						MOV		BYTE PTR CS:[FILE_DRIVE],AL

						MOV		AX,CS
						MOV		DS,AX
						MOV		ES,AX
						MOV		CX,FILENAME_BUFFER_LEN/4
						MOV		SI,OFFSET FILENAME_BUFFER
						MOV		DI,OFFSET FILENAME_BUFFER_SECOND
						REP MOVSD

						MOV		SI,OFFSET FILENAME_BUFFER_SECOND
						CALL	SEEK_LAST_BACKSLASH  ; AX destroyed, DS:DI is last backslash.
						CMP		BYTE PTR DS:[DI],0
						JE		FRENAME_ACCESS_DENIED	; Does dos have an error code for bad file name?
						CMP		WORD PTR DS:[DI],'/'
						JE		FRENAME_ACCESS_DENIED	; Does dos have an error code for bad file name?
						CMP		WORD PTR DS:[DI],'\'
						JE		FRENAME_ACCESS_DENIED	; Does dos have an error code for bad file name?

						; Check File Name Chars
						LEA		SI,[DI+1]
						CALL	CHECK_NEW_FILENAME_CHARS
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JC		FRENAME_EXIT


						_LDS	SI,CS:[FILE_INPUT_FILENAME]
						CALL	MAKE_FULLPATH_CRUNCH	; No wildcard

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CMP		AL,BYTE PTR CS:[FILE_DRIVE]
						JNE		FRENAME_DIFFERENT_DRIVE

						CALL	MEDIACHECK_READYCDS		; CF=1 Error  CF=0 AL=(0:No Change  1:Disk Changed)
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		FRENAME_EXIT


						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	GET_DRIVE_CDS
						JC		FRENAME_INVALID_DRIVE

						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		FRENAME_NOT_REDIRECTED
;FRENAME_REDIRECTED:
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],BX
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],DS

						MOV		AX,INT2F_RENAME
						INT		2Fh

						RET


FRENAME_NOT_REDIRECTED:
						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]

						; Input
						;   GS:BP  DPB
						;   DS:SI  Starting pointer in the fully-qualified file name.
						;          If the file name is:
						;            C:\COMMAND.COM
						;               ^SI must point this.
						;   EAX    Starting cluster (0->Root Dir)
						;   CX     Attribute Filter, High-Byte ignored.
						; Return
						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
						;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
						;   Lastly scanned directory cluster can be found in DIR_variables
						; Don't expect registers are preserved.
						PUSh	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER
						ADD		SI,3	; Again, not to worry about "\\Q.A." if it is, it is INT 2F drive.
						XOR		EAX,EAX
						MOV		CX,0ffffh-DIRENT_ATTR_VOLLABEL
						CALL	FETCH_DIR
						MOV		CS:[SAVE_FILE_ATTR],AL
						JC		FRENAME_FILE_NOT_FOUND

						; I know it should be able to move a directory.
						; Can I move SYSTEM and READONLY files?
						; I make them movable for the time being.
						; TEST	AL,DIRENT_ATTR_SYSTEM+DIRENT_ATTR_READONLY
						; JNE	FRENAME_ACCESS_DENIED

						MOVZX	EAX,WORD PTR ES:[BX+IO_BUF_SECTOR_NUM]
						MOV		DWORD PTR CS:[FILE_RENAME_SRC_DIR_SECTOR],EAX
						MOV		AX,DI
						SUB		AX,BX
						SUB		AX,IO_BUF_INFO_size
						MOV		CS:[FILE_RENAME_SRC_DIR_OFFSET],AX

						MOV		EAX,DWORD PTR CS:[DIR_CLUSTER0]
						MOV		DWORD PTR CS:[FILE_RENAME_SRC_DIR_CLUSTER],EAX


						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER_SECOND
						ADD		SI,3	; Again, not to worry about "\\Q.A." if it is, it is INT 2F drive.
						XOR		EAX,EAX
						MOV		CX,0ffffh-DIRENT_ATTR_VOLLABEL
						CALL	FETCH_DIR
						JNC		FRENAME_ACCESS_DENIED	; In this case, file already exists.

						MOV		EAX,DWORD PTR CS:[DIR_CLUSTER0]
						CMP		EAX,DWORD PTR CS:[FILE_RENAME_SRC_DIR_CLUSTER]
						JNE		FRENAME_DIFFERENT_DIR


FRENAME_SAME_DIR:
						; Rename within the same directory.
						; In this case, just overwrite the 11-byte filename of the DIRENT

						; Input
						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						;          AL!=0 Don't read sector (Just make an available buffer)
						MOV		EDX,CS:[FILE_RENAME_SRC_DIR_SECTOR]
						XOR		AL,AL
						CALL	GETBUFFER_REGULAR
						JC		FRENAME_ACCESS_DENIED
						; Output
						;   CF=0   DS:DI=Buffer
						;   CF=1   Error
						;   AX     Destroyed
						;   DX     Destroyed
						;   Hiword EDI  Destroyed

						PUSH	DS

						POP		ES
						OR		BYTE PTR ES:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_DIR+IO_BUF_FLAG_WRITTEN
						ADD		DI,IO_BUF_INFO_size+DIRENT_FILENAME
						ADD		DI,CS:[FILE_RENAME_SRC_DIR_OFFSET]

						PUSH	DI
						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER_SECOND
						CALL	SEEK_LAST_BACKSLASH  ; AX destroyed, DS:DI is last backslash.
						LEA		SI,[DI+1]			; Already checked it is not empty.
						POP		DI

						; Input
						;   DS:SI  Source File name
						;   ES:DI  Destination 11-byte file name.
						; Destroys EAX,CX
						CALL	MAKE_11BYTE_FILENAME

						MOV		AL,GS:[BP+DPB_DRIVE_CODE]
						CALL	FLUSH_BUFFERS_DRIVE_FAT

						CLC
						RET


FRENAME_DIFFERENT_DIR:
						MOV		CL,CS:[SAVE_FILE_ATTR]
						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER_SECOND
						PUSH	GS
						PUSH	BP
						CALL	FCREATE_IF_NOT_EXIST
						POP		BP
						POP		GS
						JC		FRENAME_EXIT

						PUSH	AX
						PUSH	GS
						PUSH	BP
						CALL	GET_SF_ENTRY_FROM_JFN	; Not supposed to fail.
						POP		BP
						POP		GS

						; I can skip the following two.
						; POP		AX	; Recover File Handle
						; PUSH	AX	; Save File Handle

						PUSH	FS	; Save SF_ENTRY
						PUSH	DI

						MOV		EDX,CS:[FILE_RENAME_SRC_DIR_SECTOR]
						XOR		AL,AL	; Actually Read
						CALL	GETBUFFER_REGULAR
						MOV		SI,DI	; DS:DI is the sector buffer
						POP		DI
						POP		FS		; Recover SF_ENTRY
						POP		AX		; Recover File Handle
						JC		FRENAME_ACCESS_DENIED_AFTER_FCREATE

						PUSH	AX		; Save File Handle

						OR		BYTE PTR DS:[SI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_DIR+IO_BUF_FLAG_WRITTEN
						ADD		SI,IO_BUF_INFO_size+DIRENT_FILENAME
						ADD		SI,CS:[FILE_RENAME_SRC_DIR_OFFSET]
						MOV		BYTE PTR DS:[SI+DIRENT_FILENAME],DELETED_FILE_FIRST_BYTE

						; Attribute is supposed to be already copied.
						; File name is already given to FCREATE_IF_NOT_EXIST
						MOV		EAX,DWORD PTR DS:[SI+DIRENT_TIME]
						MOV		DWORD PTR FS:[DI+SF_TIME],EAX
						MOV		EAX,DS:[SI+DIRENT_FILE_SIZE]
						MOV		FS:[DI+SF_FILE_SIZE],EAX
						MOV		AX,DS:[SI+DIRENT_FIRST_CLUSTER]
						MOV		FS:[DI+SF_FIRST_CLUSTER_NUM],AX
						AND		WORD PTR FS:[DI+SF_DEVFLAGS],0ffffh-SF_DEVFLAG_BLOCK_NOT_WRITTEN

						POP		AX		; Recover File Handle
						CALL	FCLOSE

FRENAME_EXIT:
						RET

FRENAME_ACCESS_DENIED_AFTER_FCREATE:
						CALL	FCLOSE
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET

FRENAME_INVALID_DRIVE:
						MOV		AX,DOSERR_INVALID_DRIVE
						STC
						RET

FRENAME_ACCESS_DENIED:
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET

FRENAME_FILE_NOT_FOUND:
						MOV		AX,DOSERR_FILE_NOT_FOUND
						STC
						RET

FRENAME_DIFFERENT_DRIVE:
						MOV		AX,DOSERR_ACCESS_DENIED
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



FCB_MESSAGE				DB		"FCB access not supported."
						DB		0Dh,0Ah,0

FCB_NOT_SUPPORTED:
						MOV		SI,OFFSET FCB_MESSAGE
						PUSH	CS
						POP		DS

						; Have I written PUTS already?
FCB_NOT_SUPPORTED_LOOP:
						LODSB
						OR		AL,AL
						JE		FCB_NOT_SUPPORTED_BREAK

						PUSH	DS
						PUSH	SI
						CALL	PUTC
						POP		SI
						POP		DS
						JMP		FCB_NOT_SUPPORTED_LOOP

FCB_NOT_SUPPORTED_BREAK:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; DS:SI
;   Extended FCB
; Always return STC with DOSERR_INVALID_FUNC
WRITE_VOLUME_LABEL:
						PUSH	DS
						PUSH	SI

						CMP		BYTE PTR DS:[SI],0FFh	; Extended FCB?
						JNE		WRITE_VOLUME_LABEL_EXIT

						MOV		AL,BYTE PTR DS:[SI+7]	; Insane Drive Code
						CALL	FCBDRIVE_TO_SANE_DRIVE

						XOR		AH,AH
						CALL	GET_DRIVE_CDS
						JC		WRITE_VOLUME_LABEL_EXIT

						;   CF=0  DS:BX=CDS      AX Destroyed
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JNE		WRITE_VOLUME_LABEL_EXIT	; Can't set volume label of the redirected drive.

						; Then, it must be a BLOCKDEV
						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]

						MOVZX	EDX,WORD PTR GS:[BP+DPB_FIRST_DIR_SECTOR]
						XOR		AL,AL
						CALL	GETBUFFER_REGULAR
						JC		WRITE_VOLUME_LABEL_EXIT

						; DS:DI is the first dir sector buffer.
						; If
						;  (1) The first directory entry is open, or
						;  (2) The first directory entry is a volume label
						; write a volume-label info to the first entry of the root dir.

						LEA		BX,[DI+IO_BUF_INFO_size]
						CMP		BYTE PTR DS:[BX+DIRENT_FILENAME],0
						JE		WRITE_VOLUME_LABEL_DO_IT
						CMP		BYTE PTR DS:[BX+DIRENT_FILENAME],DELETED_FILE_FIRST_BYTE
						JE		WRITE_VOLUME_LABEL_DO_IT
						TEST	BYTE PTR DS:[BX+DIRENT_ATTR],DIRENT_ATTR_VOLLABEL
						JNE		WRITE_VOLUME_LABEL_EXIT

WRITE_VOLUME_LABEL_DO_IT:
						PUSH	DS
						POP		ES
						; Now ES:DI is the sector buffer, ES:BX is the first DIRENT.
						XCHG	DI,BX
						; Now ES:BX is the sector buffer, ES:DI is the first DIRENT.

						POP		SI
						POP		DS
						PUSH	DS
						PUSH	SI

						ADD		SI,8
						MOV		CX,11
						REP MOVSB

						MOV		CX,DIRECTORY_ENTRY_size-11
						XOR		AL,AL
						REP STOSB

						SUB		DI,DIRECTORY_ENTRY_size

						CALL	READ_CLOCK_FOR_DIRENT
						MOV		ES:[DI+DIRENT_TIME],DX
						MOV		ES:[DI+DIRENT_DATE],AX
						MOV		BYTE PTR ES:[DI+DIRENT_ATTR],DIRENT_ATTR_VOLLABEL+DIRENT_ATTR_ARCHIVE
						OR		BYTE PTR ES:[BX+IO_BUF_FLAGS],IO_BUF_FLAG_WRITTEN+IO_BUF_FLAG_IS_DIR

						PUSH	ES
						POP		DS
						MOV		SI,BX
						CALL	WRITE_BACK_AND_MARK_UNUSED

WRITE_VOLUME_LABEL_EXIT:
						STC
						MOV		AX,DOSERR_INVALID_FUNC
						POP		SI
						POP		DS
						RET
