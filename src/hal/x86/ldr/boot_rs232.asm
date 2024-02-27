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
%define COM_REG_LSR_S_TXE   0x40        ; Transmitter Empty Indicator.
%define COM_REG_LSR_E_FFO   0x80        ; FIFO Error.

; Modem Status Register
%define COM_REG_MSR_IDX     6
; Scratch Register
%define COM_REG_SCRATCH_IDX     7

%define BOOT_DATA_BASE      0x0A00

%define BOOT_STACK_SEG      0x1000
%define BOOT_STACK_BASE     0xFF00

%define BOOT_LOAD_SEG       0x2000

%define EXOS_DBG_PROT_ID_UPLOAD_0   0x0001  ; Meta = page count to read.

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

timeCounter:
    dw      0

boot:
    ; Save the drive number from the BIOS.
    mov     [ds:BOOT_DATA_BASE + BOOT_DATA.DriveNumber], dl
    
    ; Setup the stack pointer.
    mov     ax, BOOT_STACK_BASE
    mov     sp, ax
    
    mov     ax, BOOT_STACK_SEG
    mov     ss, ax
    
    ; Enable interrupts.
    sti
    
    ; Configure COM for 8N1 @ 115200 baud, then wait for boot upload.
    ; Disable interrupts.
    mov     cx, COM_REG_IER_IDX
    mov     dl, 0
    call    outByte
    
    ; Set DLAB mode.
    mov     cx, COM_REG_LCR_IDX
    mov     dl, (\
                COM_REG_LCR_DLAB | \
                COM_REG_LCR_8N1)
    call    outByte
    
    ; Divisor = 1, 115200 baud.
    mov     cx, COM_REG_DLAB_0_IDX
    mov     dl, 1
    call    outByte
    
    mov     cx, COM_REG_DLAB_1_IDX
    mov     dl, 0
    call    outByte
    
    ; Clear DLAB, set 8N1.
    mov     cx, COM_REG_LCR_IDX
    mov     dl, COM_REG_LCR_8N1
    call    outByte
    
    ; Enable and clear FIFOs for TX and RX. Set them to 1 byte.
    mov     cx, COM_REG_FCR_IDX
    mov     dl, (\
                COM_REG_FCR_EN | \
                COM_REG_FCR_CLR_RX | \
                COM_REG_FCR_CLR_TX)
    call    outByte

    ; Setup header validation.
    mov     cx, 4
    mov     bx, protHdr
    
readBootImage_0:
    test    cx, cx
    jz      readBootImage_1
    
    ; Read a byte, compare against the header.
    call    readByte
    sub     al, [ds:bx]
    jnz     failure
    
    dec     cx
    inc     bx
    jmp     readBootImage_0
    
readBootImage_1:
    ; Read 1 byte, the number of 4K pages.
    call    readByte
    
    ; Start loading at 0x00020000.
    mov     bx, BOOT_LOAD_SEG 
    mov     ds, bx
    mov     bx, 0
    
readBootImage_2:
    ; Loop for each 4K.
    test    al, al
    jz      execBootImage
    
    ; Decrement the remaining page count and save on stack.
    dec     al
    push    ax
    
    ; Load 4K into cx.
    mov     cx, 4096
    
readBootImage_3:
    test    cx, cx
    jz      readBootImage_4
    
    ; Read a byte, save it, inc/dec index/counter.
    call    readByte
    jmp $
    mov     [ds:bx], al
    
    inc     bx
    dec     cx
    jmp     readBootImage_3
    
readBootImage_4:
    ; Restore page count.
    pop     ax
    
    ; Test for bx == 0.
    test    bx, bx
    jnz     readBootImage_2
    
    mov     bx, ds
    add     bx, 0x1000
    mov     ds, bx
    xor     bx, bx
    jmp     readBootImage_2
    
execBootImage:
    jmp     $

; inByte 
; Reads a byte from the configured COM port at offset in cx.
;   cx:     Offset of configured COM port to read.
inByte:
    push    dx
    
    mov     dx, cx
    
    add     dx, [ds:comAddress]
    in      al, dx
    
    pop     dx
    ret

; outByte
; Writes a byte to the configured COM port at the address offset.
;   cx:     The address offset.
;   dl:     The byte to write.
outByte:
    push    ax
    push    cx
    push    dx
    mov     al, dl
    mov     dx, cx
    add     dx, [ds:comAddress]
    out     dx, al
    pop     dx
    pop     cx
    pop     ax
    ret

; BYTE getComStatus
;   Get the current COM LSR.
getComStatus:
    push    cx
    push    dx
    
    mov     cx, COM_REG_LSR_IDX
    call    inByte
    mov     [ds:state_LastLsr], al
    
    pop     dx
    pop     cx
    ret

; waitComStatus
;   Wait for a status bits to be set on the COM port.
;   cl:     Flags to wait on.
waitComStatus:
    push    bx
    push    cx
    push    dx
    
    mov     word [ds:state_WaitIter], 0
    
waitComStatus_0:
    call    getComStatus
    
    and     al, cl
    jnz     waitComStatus_End
    
    inc     word [ds:state_WaitIter]
    
    ; Repeat, until flags set.
    jmp     waitComStatus_0
    
waitComStatus_End:
    pop     dx
    pop     cx
    pop     bx
    ret

; BYTE readByte:
;   Reads a data byte from the configured COM port.
readByte:
    push    cx
    mov     cx, COM_REG_LSR_DRDY
    call    waitComStatus
    mov     cx, COM_REG_DATA_IDX
    call    inByte
    mov     cl, al
    call    printChar
    mov     al, cl
    pop     cx
    ret

; printChar
;   cl:     The character to print.
printChar:
    push    ax
    push    bx
    mov     bx, 0
    mov     ah, 0x0E
    mov     al, cl
    int     0x10
    pop     bx
    pop     ax
    ret

; Define failure target.
failure:
    ; Indicate failure, then hang.
    mov     al, 8
    mov     cl, 'X'

failure_0:
    dec     al
    call    printChar
    jnz     failure_0
    
    jmp     $

; Expected header for comparison.
protHdr:
    db      'E', 'x', 'O', 's'

; Various state variables for debugging.
state_LastLsr:
    db      0x00
state_WaitIter:
    dw      0x0000
comAddress:
    dw      COM1_PORT

timerTicks:
    dw      0x0000

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

