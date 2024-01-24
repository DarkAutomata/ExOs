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
%define COM_REG_DATA_IDX    0
; Interrupt Enable Register
%define COM_REG_IER_IDX     1
; DLAB+ Clock Divisor Low
%define COM_REG_DLAB_0_IDX  0
; DLAB+ Clock Divisor High
%define COM_REG_DLAB_1_IDX  1
; FIFO Config Register
%define COM_REG_FCR_IDX     2
%define COM_REG_FCR_EN      0x01
%define COM_REG_FCR_CLR_RX  0x02
%define COM_REG_FCR_CLR_TX  0x04  
%define COM_REG_FCR_DMA_SEL 0x08

; Line Control Register
%define COM_REG_LCR_IDX     3
%define COM_REG_LCR_DLAB    0x80
%define COM_REG_LCR_SNDBK   0x40
%define COM_REG_LCR_STCKYB  0x20
%define COM_REG_LCR_8N1     0x03

; Line Status Register
%define COM_REG_LSR_IDX     5
%define COM_REG_LSR_DRDY    0x01        ; Data Ready.
%define COM_REG_LSR_E_OVR   0x02        ; Overrun Error.
%define COM_REG_LSR_E_PAR   0x04        ; Parity Error.
%define COM_REG_LSR_E_FRM   0x08        ; Framing Error.
%define COM_REG_LSR_I_BRK   0x10        ; Break Indicator.
%define COM_REG_LSR_S_TXH   0x20        ; Transmitter Holding Indicator.
%define COM_REG_LSR_s_EDH   0x40        ; Transmitter Empty Indicator.
%define COM_REG_LSR_E_FFO   0x80        ; FIFO Error.

; Modem Status Register
%define COM_REG_MSR_IDX     6
; Scratch Register
%define COM_REG_SCRATCH_IDX     7

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
    
    ; Configure COM for 8N1 @ 115200 baud, then wait for boot upload.
    ; Disable interrupts.
    mov     dx, COM_REG_IER_IDX
    mov     al, 0
    call    outByte
    
    ; Set DLAB mode.
    mov     dx, COM_REG_LCR_IDX
    mov     al, (\
                COM_REG_LCR_DLAB | \
                COM_REG_LCR_8N1)
    call    outByte
    
    ; Divisor = 1, 115200 baud.
    mov     dx, COM_REG_DLAB_0_IDX
    mov     al, 1
    call    outByte
    
    mov     dx, COM_REG_DLAB_1_IDX
    mov     al, 0
    call    outByte
    
    ; Clear DLAB, set 8N1.
    mov     dx, COM_REG_LCR_IDX
    mov     al, COM_REG_LCR_8N1
    call    outByte
    
    ; Enable and clear FIFOs for TX and RX. Set them to 1 byte.
    mov     dx, COM_REG_FCR_IDX
    mov     al, (\
                COM_REG_FCR_EN | \
                COM_REG_FCR_CLR_RX | \
                COM_REG_FCR_CLR_TX)
    call    outByte

    ; Attempt to send connect packet.
    mov     bx, protHdr
    call    sendBytes
    
readBootImage:
    ; Read the boot image payload.
    call    syncRemote
    
    jmp     readBootImage

inByte:
    add     dx, [comAddress]
    in      al, dx
    ret

outByte:
    add     dx, [comAddress]
    out     dx, al
    ret

; syncRemote
;   Broadcasts protocol header and listens for response on 5 second intervals
;   until connection.
syncRemote:
    mov     dx, strStatusPending
    call    printString
    
    mov     bx, protHdr
    call    sendBytes
    
    ; Loop looking for incoming data.
    mov     cx, 1000

syncRemote_ReadLoop:
    ; First decrement and test.
    dec     cx
    jz      syncRemote      ; Jump back to sending the header.
    
    ; Read status register and test against data ready.
    mov     dx, COM_REG_LSR_IDX
    call    inByte
    
    test    al, COM_REG_LSR_DRDY
    jz      syncRemote_ReadLoop
    
    mov     dx, strStatusReading
    call    printString
    
    ; Read image.
    jmp $

; sendByte:
;   ah = Byte to send.
sendByte:
    push    cx
    
    mov     dx, COM_REG_LSR_IDX
    add     dx, [comAddress]
    
    mov     cx, 1000
    
sendByte_GetStatus:
    dec     cx
    jz      sendByte_Exit
    
    in      al, dx
    test    al, COM_REG_LSR_S_TXH
    jz      sendByte_GetStatus
    
    ; Prepare to send bte.
    mov     al, ah
    out     dx, al

sendByte_Exit:
    pop     cx
    ret

; sendBytes:
;   bx = Location pointer.
sendBytes:
    ; Return when send value is 0.
    mov     ah, [bx]
    inc     bx
    test    ah, ah
    jz      sendBytes_Exit
    
    call    sendByte
    jmp     sendBytes
    
sendBytes_Exit:
    ret

printString:
    push    ax
    push    bx
    
    mov     bx, dx

printString_Loop:
    mov     al, [bx]
    test    al, al
    jz      printString_Exit
    
    inc     dx
    mov     ah, 0x0E
    int     0x10
    
    jmp     printString_Loop
    
printString_Exit:
    pop     bx
    pop     ax
    ret

; Define failure target.
failure:
    ; Loop on failure.
    jmp     $

; Define protocol data.
; The header expected before every message.
protHdr:
    db      'E', 'x', 'O', 's', 0

strStatusPending:
    db      '.', 0

strStatusReading:
    db      '=', 0

comAddress:
    dw      COM1_PORT

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

