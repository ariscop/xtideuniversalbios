; Project name	:	XTIDE Universal BIOS
; Description	:	Reading and jumping to boot sector.

;
; XTIDE Universal BIOS and Associated Tools
; Copyright (C) 2009-2010 by Tomi Tilli, 2011-2012 by XTIDE Universal BIOS Team.
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; Visit http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
;

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; BootSector_TryToLoadFromDriveDL_AndBoot
;	Parameters:
;		DL:		Drive to boot from (translated, 00h or 80h)
;		DS:		RAMVARS segment
;	Returns:
;		ES:BX:	Ptr to boot sector (if successful)
;		CF:		Set if boot sector loaded successfully
;				Cleared if failed to load boot sector
;	Corrupts registers:
;		AX, CX, DH, SI, DI, (DL if failed to read boot sector)
;--------------------------------------------------------------------
BootSector_TryToLoadFromDriveDL_AndBoot:
	call	DetectPrint_TryToBootFromDL
	call	LoadFirstSectorFromDriveDL
%ifndef USE_386
	jc		SHORT .FailedToLoadFirstSector
%else
	jc		DetectPrint_FailedToLoadFirstSector
%endif

	test	dl, dl
	jns		SHORT .AlwaysBootFromFloppyDriveForBooterGames
	cmp		WORD [es:bx+510], 0AA55h		; Valid boot sector?
	jne		SHORT .FirstHardDiskSectorNotBootable
.AlwaysBootFromFloppyDriveForBooterGames:
	stc
	jmp		SHORT JumpToBootSector_or_RomBoot

%ifndef USE_386
.FailedToLoadFirstSector:
	jmp		DetectPrint_FailedToLoadFirstSector
%endif

.FirstHardDiskSectorNotBootable:
	mov		si, g_szBootSectorNotFound
	jmp		DetectPrint_NullTerminatedStringFromCSSIandSetCF

%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
  %ifdef MODULE_DRIVEXLATE
    %if TryToBoot_FallThroughTo_BootSector_TryToLoadFromDriveDL_AndBoot <> BootSector_TryToLoadFromDriveDL_AndBoot
	  %error "TryToBoot_FallThroughTo_BootSector_TryToLoadFromDriveDL_AndBoot <> BootSector_TryToLoadFromDriveDL_AndBoot, BootSector must come immediately after int19h.asm"
    %endif
  %endif
%endif

;--------------------------------------------------------------------
; LoadFirstSectorFromDriveDL
;	Parameters:
;		DL:		Drive to boot from (translated, 00h or 80h)
;	Returns:
;		AH:		INT 13h error code
;		ES:BX:	Ptr to boot sector (if successful)
;		CF:		Cleared if read successful
;				Set if any error
;	Corrupts registers:
;		AL, CX, DH, DI
;--------------------------------------------------------------------
LoadFirstSectorFromDriveDL:
	LOAD_BDA_SEGMENT_TO	es, bx				; ES:BX now points to...
	mov		bx, BOOTVARS.rgbBootSect		; ...boot sector location
	mov		di, BOOT_READ_RETRY_TIMES		; Initialize retry counter

.ReadRetryLoop:
	mov		ax, 0201h						; Read 1 sector
	mov		cx, 1							; Cylinder 0, Sector 1
	xor		dh, dh							; Head 0
	int		BIOS_DISK_INTERRUPT_13h
	jc		SHORT .FailedToLoadFirstSector
.Return:
	ret

.FailedToLoadFirstSector:
	dec		di								; Decrement retry counter (preserve CF)
	jz		SHORT .Return					; Loop while retries left

	; Reset drive and retry
	xor		ax, ax							; AH=00h, Disk Controller Reset
	test	dl, dl							; Floppy drive?
	eCMOVS	ah, RESET_HARD_DISK				; AH=0Dh, Reset Hard Disk (Alternate reset)
	int		BIOS_DISK_INTERRUPT_13h
	jmp		SHORT .ReadRetryLoop

