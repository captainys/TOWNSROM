


; Input
;   AL  Drive 0=A:
; Output
;   CF=0  No Error  AL=(0:No Change in CWD  1:Changed CWD to Root)   GS:BP is DPB for the drive.
;   CF=1  Device Error  AX=Return Code from Device Driver
;   ESI   Destroyed
; 1679:5394
;
;	if(DPB hasn't been accessed)
;	{
;		RebuildDPB
;		DiscardBuffers
;		ResetCDS
;		return AL=1,CF=0
;	}
;	MediaCheck()
;	if(Error)
;	   return CF=1
;	if(MediaChangeByte<0) // Changed
;	{
;		RebuildDPB
;		DiscardBuffers
;		ResetCDS
;		return AL=1,CF=0
;	}
;	else if(0<MediaChangeByte) // No change
;	{
;		return AL=0,CF=0
;	}
;	else // Unknown
;	{
;		if(There is no pending Write-Back buffer)
;		{
;			RebuildDPB
;		}
;		return AL=0,CF=0;
;	}
MEDIACHECK_READYCDS:
						CALL	GET_DRIVE_CDS
						MOV		AX,DOSERR_INVALID_DRIVE
						JB		MEDIACHECK_READYCDS_ERROR

						LGS		BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]	; GS:BP=DPB

						CMP		BYTE PTR GS:[BP+DPB_ACCESS_FLAG],DPB_ACCESS_FLAG_UNACCESSED
						JE		MEDIACHECK_READYCDS_MEDIA_CHANGED

						; Input
						;   AL     Unit
						;   AH     Media Descriptor
						;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
						MOV		AL,GS:[BP+DPB_UNIT_CODE]
						MOV		AH,GS:[BP+DPB_MEDIA_DESC_TYPE]
						MOV		ESI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						CALL	DEVCALL_MEDIACHECK
						; Return
						;   CF=1 AX=Status Code  If error ((status code&0x8000)!=0)
						;   CF=0 AH=[REQ+REQ_MEDIACHECK_CODE_RETURN] (1=unchanged, 0=unknown, -1=changed), AL Destroyed

						JB		MEDIACHECK_READYCDS_ERROR

						CMP		AH,1
						JE		MEDIACHECK_READYCDS_NOCHANGE ; Unchanged.  Nothing to do.

						OR		AH,AH
						JS		MEDIACHECK_READYCDS_MEDIA_CHANGED


						; Media-Status Unknown
						; If the media-change status is unknown Proc 1679:540C checks if at least one
						; written sector buffer for the drive, and let it go if there is one.  I don't
						; I don't understand the logic, but if it works, I let mine do the same.
;MEDIACHECK_MEDIA_CHANGE_UNKNOWN:
						MOV		AL,GS:[BP+DPB_DRIVE_CODE]
						CALL	CHECK_WRITTEN_BUFFER_FOR_DRIVE	; CF=0->Exists  CF=1->Doesn't exist
						JAE		MEDIACHECK_READYCDS_NOCHANGE

						CALL	REBUILD_DPB
						JNC		MEDIACHECK_READYCDS_NOCHANGE
						OR		AL,AL
						JNE		MEDIACHECK_BUILD_DPB_FAILED
						JMP		MEDIACHECK_READYCDS_NOCHANGE


						; Media Changed.  Need to Reset things.
						; No brainer.  Discard buffers (too late), rebuild DPB, reset CWD.
MEDIACHECK_READYCDS_MEDIA_CHANGED:
						; Temporarily mark DPB as UNACCESSED
						MOV		DWORD PTR CS:[PREVIOUS_DISK_LABEL],ESI
						MOV		BYTE PTR GS:[BP+DPB_ACCESS_FLAG],DPB_ACCESS_FLAG_UNACCESSED

						; If media changed, there is a danger that the cached sectors will be
						; written back to the new disk, which will destroy the FAT and/or DIR.
						; So, it makes sense to make sure all buffers for the disk are discarded.
						; There is a possibility that the user pulled the disk, and inserted it
						; again.  But, there is no way of knowing if the new disk is the exact
						; disk that was in the drive, unless I have an entire copy of the disk
						; in the memory, which is impossible.  Well, may not be impossible, but
						; impractical.
						MOV		AL,GS:[BP+DPB_DRIVE_CODE]
						CALL	DISCARD_BUFFER_FOR_DRIVE

						CALL	REBUILD_DPB
						JNC		MEDIACHECK_READYCDS_DPB_REBUILT	; DPB didn't have to be re-built
						OR		AL,AL
						JNE		MEDIACHECK_BUILD_DPB_FAILED

MEDIACHECK_READYCDS_DPB_REBUILT:
						MOV		AL,GS:[BP+DPB_DRIVE_CODE]
						CALL	SET_CDS_TO_ROOT

						; JMP		MEDIACHECK_READYCDS_CHANGE  Let it fall down to 

MEDIACHECK_READYCDS_CHANGE:
						MOV		AL,1
						CLC
						RET

MEDIACHECK_READYCDS_NOCHANGE:
						XOR		AL,AL
						CLC
						RET

MEDIACHECK_READYCDS_ERROR:
						CALL	DEVERR_TO_DOSERR
						STC
						RET

MEDIACHECK_BUILD_DPB_FAILED:
						MOV		AX,DOSERR_BAD_FORMAT
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL=Drive (0=ADrive)
; Output
;   CF=0  DS:BX=CDS      AX Destroyed
;   CF=1  Drive invalid  AX=DOSERR_INVALID_DRIVE   DS,BX Destroyed
; DX preserved.
; As you can see, I wrote this function after forgetting that I had already written
; GET_ALth_CDS_IN_DSSI, which returns DS:SI  :-P
GET_DRIVE_CDS:
						MOV		BL,AL

						; Drive Number needs to be less than CS:[NUM_CDS]
						CMP		BL,CS:[NUM_CDS]
						JAE		GET_DRIVE_CDS_ERROR

						MOV		AL,CURRENT_DIR_STRUCT_size
						MUL		BL
						LDS		BX,CS:[FIRST_CDS_PTR]
						ADD		BX,AX

						; VALID flag must be set.
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_VALID
						JE		GET_DRIVE_CDS_ERROR

						CLC
						RET

GET_DRIVE_CDS_ERROR:
						MOV		AX,DOSERR_INVALID_DRIVE
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  DPB
; Return
;   CF=0   DPB didn't have to be rebuilt (Same Media Desc)
;   CF=1   AL=0     DPB rebuilt.
;          AL=0FFh  Tried to rebuild DPB, but failed due to broken BPB.
REBUILD_DPB:
						; Re-build DPB.
						; DOS has a weird requirement for calling BUILD_BPB device-driver call.
						; It requires a buffer filled with the first FAT sector, if
						; SYSDEV_DEVFLAG_MEDIA_DESC_IN_FAT_REQUIRED flag is not set.
						; If it is set, just get an available buffer.
						LDS		SI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						TEST	WORD PTR DS:[SI+SYSDEV_DEVFLAGS],SYSDEV_DEVFLAG_MEDIA_DESC_IN_FAT_REQUIRED
						JE		REBUILD_DPB_GET_FAT_SECTOR

						CALL	FIND_AVAILABLE_BUFFER
						JNC		REBUILD_DPB_HAVE_BUFFER
						CALL	MAKE_AVAILABLE_BUFFER
						JMP		REBUILD_DPB_HAVE_BUFFER


REBUILD_DPB_GET_FAT_SECTOR:
						MOV		DX,GS:[BP+DPB_FIRST_FAT_SECTOR]	; LBA
						XOR		AL,AL	; Read Sector
						CALL	GETBUFFER_FAT
						MOV		SI,DI	; Agh!  Why did I make it return DS:DI!  All other buffer funcs return DS:SI.

REBUILD_DPB_HAVE_BUFFER:
						; At this time, DS:SI is the buffer header to be used by the RebuildBPB

						MOV		DI,DS
						SHL		EDI,16
						MOV		DI,SI

						MOV		BYTE PTR GS:[BP+DPB_ACCESS_FLAG],DPB_ACCESS_FLAG_UNACCESSED  ; Temporary

						MOV		ESI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						MOV		AL,GS:[BP+DPB_UNIT_CODE]
						MOV		AH,GS:[BP+DPB_MEDIA_DESC_TYPE]
						; Input
						;   AL    Unit
						;   AH    Last known MediaDesc
						;   EDI   Buffer Header used for BuildBPB (Hiword=SEG, Loword=OFFSET)
						;   ESI   Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
						CALL	DEVCALL_BUILDBPB
						; Return
						;   CF=0  EAX    Built BPB (Hiword is SEG, Loword is OFFSET)
						;   CF=1  AX     Status Code
						JC		REBUILD_DPB_NOT_REBUILT

						; Mark DPB as Accessed
						MOV		BYTE PTR GS:[BP+DPB_ACCESS_FLAG],DPB_ACCESS_FLAG_ACCESSED

						; Discard the buffer (I don't need ESI=SYSDEV any more)
						MOV		SI,DI
						ROR		EDI,16
						MOV		DS,DI
						ROL		EDI,16
						CALL	DISCARD_BUFFER

						MOV		SI,AX
						ROR		EAX,16
						MOV		DS,AX	; DS:SI is BPB

						MOV		BL,GS:[BP+DPB_MEDIA_DESC_TYPE]
						CMP		BL,DS:[SI+BPB_MEDIA_DESC_TYPE]
						JE		REBUILD_DPB_NOT_REBUILT

						PUSH	GS
						POP		ES		; ES:BP is DPB
						; Input:
						;    DS:SI  Source BPB (BIOS Parameter Block)
						;    ES:BP  DPB to create
						CALL	SETDPB
						;    BX,CX,DX destroyed
						MOV		WORD PTR GS:[BP+DPB_LAST_CLUSTER_ALLOC],0
						MOV		AL,0	; Means no error
						JNC		REBUILD_DPB_WAS_REBUILT_OR_ERR
						MOV		AL,0FFh ; Means broken BPB

REBUILD_DPB_WAS_REBUILT_OR_ERR:
						STC
						RET

REBUILD_DPB_NOT_REBUILT:
						CLC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL  Drive
SET_CDS_TO_ROOT:
						PUSH	AX
						CALL	GET_DRIVE_CDS
						POP		AX
						JB		SET_CDS_TO_ROOT_RET

						ADD		AL,'A'
						MOVZX	EAX,AL
						OR		EAX,005C3A00h
						MOV		DWORD PTR DS:[BX+CDS_CURDIR],EAX	; 'A:\'
						MOV		WORD PTR DS:[BX+CDS_CURDIR_ROOTLEN],2	; Length for 'A' and ':'
						MOV		WORD PTR DS:[BX+CDS_CURDIR_CLUSTER],0	; Root
SET_CDS_TO_ROOT_RET:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



FCBDRIVE_TO_SANE_DRIVE:
						DEC		AL
						JNS		FCBDRIVE_TO_SANE_DRIVE_DONE
						MOV		AL,CS:[CURRENT_DRIVE]
FCBDRIVE_TO_SANE_DRIVE_DONE:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; Input:
;   AL=Drive 0 is A:
; Output
;   CF is undetermined.
;   BH=00 Available FF Unavailable
;   AX Destroyed
;   ES,DI Destroyed
IS_DRIVE_AVAILABLE:
						CMP		AL,CS:[NUM_CDS]
						JAE		DRIVE_IS_UNAVAILABLE

						MOV		AH,CURRENT_DIR_STRUCT_size
						MUL		AH
						LES		DI,CS:[FIRST_CDS_PTR]
						ADD		DI,AX
						TEST	WORD PTR ES:[DI+CDS_DRIVE_TYPE],CDS_TYPE_VALID
						JE		DRIVE_IS_UNAVAILABLE
						XOR		BH,BH
						RET
DRIVE_IS_UNAVAILABLE:
						MOV		BH,0FFh
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL=Drive  0=ADrive
; Output
;   AX=Sectors Per Cluster or 0ffffh if Invalid Drive
;   BX=Number of Free Clusters
;   CX=Bytes per Sector
;   DX=Total Clusters on Drive
;   CS:[MEDIA_DESC_BYTE(530h)] Media Desc
;
; MS-DOS V3.0 does:
; (1) If Redirected, use INT 2Fh.
; (2) Media Check
; (3) Test-read cluster #2 (First usable cluster)
; (4) If cached free clusters is less than max cluster num, use it.
; (5) Count free clusters, and then cache it.
;
;What's confuisng is how to interpret max cluster num.  I am still vague about if it is
;maximum cluster number or the number of clusters.  In the modern programming, it is no brainer,
;you shouldn't store maximum usable indes.  You should keep the number of clusters.
;But, it is MS-DOS V3.1.  Pre-stone-age programming.  It was from even before human kind learned
;goto should only be used for breaking the loop, never jump back out of the scope.
;Therefore, it can well be the maximum cluster number, which is the number of clusters minus one.
;
;Always first two clusters are wasted in FAT.  Therefore, if zero usable cluster, max cluster num must be 1.
;In that case, if the cached number of free-clusters is 1, cache is invalid.  Then, the above
;comparison (less than) makes sense, and probably DPB_MAX_CLUSTER_NUM is the maximum cluster number.
GET_FREE_DISK_SPACE:
						PUSH	AX
						CALL	GET_DRIVE_CDS
						POP		AX
						JC		GET_FREE_DISK_SPACE_INVALID

						;   CF=0  DS:BX=CDS      AX Destroyed
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		GET_FREE_DISK_SPACE_NOT_REDIRECTED
;GET_FREE_DISK_SPACE_REDIRECTED:
						PUSH	DS
						POP		ES
						MOV		DI,BX
						MOV		AX,INT2FH_GET_DISK_INFO
						INT		2Fh
						; Return
						;  AL=Sectors per Cluster
						;  AH=Media Desc
						;  BX=Total Clusters on Disk
						;  CX=Bytes per Sector
						;  DX=Number of Free Clusters
						JC		GET_FREE_DISK_SPACE_INVALID
						MOV		CS:[MEDIA_DESC_BYTE],AH
						XOR		AH,AH ; Make AX Sectors per Cluster
						XCHG	BX,DX
						RET


GET_FREE_DISK_SPACE_NOT_REDIRECTED:
						; AL is still the drive.
						PUSH	AX
						CALL	MEDIACHECK_READYCDS		; CF=1 Error  CF=0 AL=(0:No Change  1:Disk Changed)
						POP		AX
						JC		GET_FREE_DISK_SPACE_INVALID

						; AL is still the drive.
						CALL	GET_DRIVE_CDS
						;   CF=0  DS:BX=CDS      AX Destroyed

						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]
						CALL	CHECK_DPB_INTEGRITY
						JC		GET_FREE_DISK_SPACE_INVALID


						MOV		BL,GS:[BP+DPB_MEDIA_DESC_TYPE]
						MOV		CS:[MEDIA_DESC_BYTE],BL

						MOV		EBX,FAT_FIRST_CLUSTER
						CALL	GET_NEXT_CLUSTER
						JC		GET_FREE_DISK_SPACE_INVALID

						MOVZX	ECX,WORD PTR GS:[BP+DPB_NUM_FREE_CLUSTERS]
						CMP		CX,0ffffh
						JE		GET_FREE_DISK_SPACE_FLORIDA2000
						CMP		CX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JB		GET_FREE_DISK_SPACE_ECX_IS_FREECOUNT

GET_FREE_DISK_SPACE_FLORIDA2000:	; I mean, recount.
						MOV		EBX,FAT_FIRST_CLUSTER
						MOV		ECX,0

GET_FREE_DISK_SPACE_LOOP:
						PUSH	ECX
						; Input
						;   GS:BP  Drive Parameter Block
						;   BX     Cluster
						CALL	GET_NEXT_CLUSTER
						; Output
						;   CF=0   DX=Next Cluster
						;   CF=1   DX Destroyed
						; EBX, Hiword of EDX Preserved
						; DS,EDI  Destroyed
						; EAX,ECX Destroyed
						POP		ECX
						JC		GET_FREE_DISK_SPACE_INVALID

						XOR		EAX,EAX
						SUB		DX,1	; If DX==0(Free) CF=1
						RCL		EAX,1	; CF->EAX
						ADD		ECX,EAX

						INC		EBX
						CMP		BX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JBE		GET_FREE_DISK_SPACE_LOOP

GET_FREE_DISK_SPACE_ECX_IS_FREECOUNT:
						MOV		GS:[BP+DPB_NUM_FREE_CLUSTERS],CX

						MOV		EBX,ECX
						MOVZX	AX,BYTE PTR GS:[BP+DPB_CLUSTER_MASK]
						INC		AX	; CLUSTER_MASK+1=Sectors per Cluster
						MOV		CX,GS:[BP+DPB_BYTES_PER_SECTOR]
						MOV		DX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						DEC		DX

						; MS-DOS V3.1 returns the total usable clusters in DX, not the number of clusters
						; including the first two wasted.  In fact, two cluster numbers (0,1) are wasted,
						; but no sector is wasted after all.
						;
						; DPB_MAX_CLUSTER_NUM-1 is the total usable clusters.

						RET

GET_FREE_DISK_SPACE_INVALID:
						MOV		AX,0ffffh
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP=DPB
; Output
;   CF=0  Probably Valid
;   CF=1  AX=DOSERR_INVALID_DRIVE
; I don't know if it is a correct method, but an indication that the DPB is not usable
; is bytes per sector is zero.
;
; Also (1<<CLUSTER_SHIFT)!=(CLUSTER_MASK+1)
;
; It happens if a drive letter is assigned to a hard disk drive, but the hard disk partition
; for the drive doesn't exist.
CHECK_DPB_INTEGRITY:
					CMP		WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR],0
					JE		CHECK_DPB_INTEGRITY_BAD

					PUSH	CX

					MOV		CH,1
					MOV		CL,GS:[BP+DPB_CLUSTER_SHIFT]
					SHL		CH,CL

					MOV		CL,GS:[BP+DPB_CLUSTER_MASK]
					INC		CL

					CMP		CH,CL

					POP		CX

					JNE		CHECK_DPB_INTEGRITY_BAD

					CLC		; Reduncant because if last CMP is 0, CF is also zero.
					RET



CHECK_DPB_INTEGRITY_BAD:
					MOV		AX,DOSERR_INVALID_DRIVE
					STC
					RET
