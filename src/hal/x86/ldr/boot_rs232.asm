;BSD 2-Clause License
;
;Copyright (c) 2024, DarkAutomata
;
;Redistribution and use in source and binary forms, with or without
;modification, are permitted provided that the following conditions are met:
;
;1. Redistributions of source code must retain the above copyright notice, this
;   list of conditions and the following disclaimer.
;
;2. Redistributions in binary form must reproduce the above copyright notice,
;   this list of conditions and the following disclaimer in the documentation
;   and/or other materials provided with the distribution.
;
;THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
;FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
;CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
;OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

; RS232 boot assembly support routines.

; An MBR boot sector to load and debug the boot code.

%define RELOC_DST           0x0600
%define RELOC_SRC           0x7C00
%define RELOC_SIZE          256     ; 256 WORDs = 512 bytes.

%define COM1_PORT           0x03F8

; Data Register
%define COM1_REG_DATA       (COM1_PORT + 0)
; Interrupt Enable Register
%define COM1_REG_IER        (COM1_PORT + 1)
; DLAB+ Clock Divisor Low
%define COM1_REG_DLAB_0     (COM1_PORT + 0)
; DLAB+ Clock Divisor High
%define COM1_REG_DLAB_1     (COM1_PORT + 1)
; FIFO Config Register
%define COM1_REG_FCR        (COM1_PORT + 2)
%define COM1_REG_FCR_EN     0x01
%define COM1_REG_FCR_CLR_RX     0x02
%define COM1_REG_FCR_CLR_TX     0x04  
%define COM1_REG_FCR_DMA_SEL    0x08

; Line Control Register
%define COM1_REG_LCR        (COM1_PORT + 3)
%define COM1_REG_LCR_DLAB   0x80
%define COM1_REG_LCR_SNDBK  0x40
%define COM1_REG_LCR_STCKYB 0x20
%define COM1_REG_LCR_8N1    0x03

; Line Status Register
%define COM1_REG_LSR        (COM1_PORT + 5)
%define COM1_REG_LSR_DRDY   0x01
%define COM1_REG_LSR_E_OVR  0x02
%define COM1_REG_LSR_E_PAR  0x04
%define COM1_REG_LSR_E_FRM  0x08
%define COM1_REG_LSR_I_BRK  0x10
%define COM1_REG_LSR_S_ETX  0x20
%define COM1_REG_LSR_s_EDH  0x40
%define COM1_REG_LSR_E_FFO  0x80

; Modem Status Register
%define COM1_REG_MSR        (COM1_PORT + 6)
; Scratch Register
%define COM1_REG_SCRATCH    (COM1_PORT + 7)

%define BOOT_DATA_BASE      0x0A00
%define BOOT_STACK_BASE     0x7BF0

struc BOOT_DATA
    .DriveNumber:   resw    1       ; The BIOS provided drive number.
endstruc

struc MBR_PART_ENTRY
    .Status:        resb    1
    .StartCHS:      resb    3
    .PartType:      resb    1
    .EndCHS:        resb    3
    .StartLBA:      resd    1
    .SectCount:     resd    1

    .size:
endstruc

%macro OUTB 2
    mov     dx, %1
    mov     al, %2
    out     dx, al
%endmacro

%macro INB 1
    mov     dx, %1
    inb     al, dx
%endmacro

section .code
org RELOC_DST
bits 16


; Initially running at 0x7C00.
init:
    ; Clear interrupts while relocating code to 0x0600.
    cli

    ; Clear ax and then load into all the segment registers to set known
    ; state.
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    
    ; Use rep movsw to copy the 512 bytes to 0x0600.
    mov     di, RELOC_DST
    mov     si, RELOC_SRC
    mov     cx, RELOC_SIZE
    rep movsw

    ; At this point the code is copied to the destination. Update CS+IP via a
    ; jmp to new code.
    jmp 0:boot

boot:
    ; Save the drive number from the BIOS.
    mov     [BOOT_DATA_BASE + BOOT_DATA.DriveNumber], dl
    
    ; Setup the stack pointer.
    mov     ax, BOOT_STACK_BASE
    mov     sp, ax
    
    ; Enable interrupts.
    sti
    
    ; Configure COM1 for 8N1 @ 115200 baud, then wait for boot upload.
    ; Disable interrupts.
    OUTB    COM1_REG_IER, 0
    ; Set DLAB mode.
    OUTB    COM1_REG_LCR, (\
            COM1_REG_LCR_DLAB | \
            COM1_REG_LCR_8N1)
    
    ; Divisor = 1, 115200 baud.
    OUTB    COM1_REG_DLAB_0, 1
    OUTB    COM1_REG_DLAB_1, 0 
    
    ; Clear DLAB, set 8N1.
    OUTB    COM1_REG_LCR, (\
        COM1_REG_LCR_8N1 | \
        COM1_REG_LCR_8N1)

    ; Enable and clear FIFOs for TX and RX. Set them to 1 byte.
    OUTB    COM1_REG_FCR, (\
            COM1_REG_FCR_EN | \
            COM1_REG_FCR_CLR_RX | \
            COM1_REG_FCR_CLR_TX)

    ; Attempt to send connect packet.
    mov     bx, protHdr
    mov     cx, [protHdr_Size]
    mov     dx, COM1_REG_DATA
    call    sendBytes
    
    ; Read the boot image payload.
    mov     dx, $
    jmp     failure
    
; sendByte:
;   ah = Byte to send.
;   dx = Port Address.
sendByte:
    push    dx
    mov     dx, COM1_REG_LSR
    
sendByte_GetStatus:
    in      al, dx
    test    al, COM1_REG_LSR_S_ETX
    jz      sendByte_GetStatus
    
    ; Prepare to send bte.
    mov     al, ah
    
    ; Restore send address.
    pop     dx
    out     dx, al
    
    ret

; sendBytes:
;   bx = Location pointer.
;   cx = Byte Count.
;   dx = Port address.
sendBytes:
    ; Return when count is 0.
    test    cx, cx
    jz      sendBytes_exit
    
    mov     ah, [bx]
    call    sendByte
    
    dec     cx
    
sendBytes_exit:
    ret

; Define failure target.
failure:
    ; Loop on failure.
    jmp     $

; Define protocol data.
; The header expected before every message.
protHdr:
    db      'E', 'x', 'O', 's'
protHdr_Size:
    dw      ($ - protHdr)

; Pad until partitio table.
times 0x1BE-($-$$) nop

; Partition Table Entries
MBR_Part_0:
    istruc MBR_PART_ENTRY
        at MBR_PART_ENTRY.Status,      db  0x80
        at MBR_PART_ENTRY.StartCHS,    db  0x00, 0x00, 0x00
        at MBR_PART_ENTRY.PartType,    db  0x00
        at MBR_PART_ENTRY.EndCHS,      db  0x00, 0x00, 0x00
        at MBR_PART_ENTRY.StartLBA,    dd  0x00000100
        at MBR_PART_ENTRY.SectCount,   dd  0x00000100
    iend
MBR_Part_123:
    times 0x30 db 0

; Boot Signature
db  0x55, 0xAA

