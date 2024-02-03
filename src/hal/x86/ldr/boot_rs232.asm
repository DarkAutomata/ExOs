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

%define BOOT_STACK_SEG      0x1000
%define BOOT_STACK_BASE     0xFF00

%define BOOT_LOAD_SEG       0x2000

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
    
    mov     ax, BOOT_STACK_SEG
    mov     ss, ax
    
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

; delay
;   Executes a short delay.
delay:
    push    cx
    mov     cx, 0x0010

delay_Loop0:
    dec     cx
    jz      delay_LoopExit
    
    push    cx
    mov     cx, 0xFFFF

delay_Loop1:
    dec     cx
    jnz     delay_Loop1
    
    pop     cx
    jmp     delay_Loop0
    
delay_LoopExit:
    pop     cx
    ret
    
; syncRemote
;   Waits until connection established by remote host.
syncRemote:
    
    ; Infinite loop looking for data to load.
syncRemote_ReadLoop:
    ; Setup alternating wait status.
    inc     cx
    
    mov     dx, cx
    and     dx, 0x0003
    shl     dx, 1
    
    add     dx, strStatusPending

    call    printString
    
    mov     dx, COM_REG_LSR_IDX
    call    inByte
    
    test    al, COM_REG_LSR_DRDY
    jnz     syncRemote_ReadHdr
    
    call    delay
    
    mov     dx, strBackspace
    call    printString
    
    ; Repeat, until connection.
    jmp     syncRemote_ReadLoop
    
syncRemote_ReadHdr:
    ; Read the header, compare with expected.
    mov     bx, protHdr
    
syncRemote_ReadHdr0
    mov     al, [bx]
    test    al, al
    jz      syncRemote_ReadImgSize
    
    call    readByte
    cmp     byte [bx], al
    jz      syncRemote_ReadHdr1
    
    call    failure
    
syncRemote_ReadHdr1:
    inc     bx
    jmp     syncRemote_ReadHdr0
    
syncRemote_ReadImgSize:
    mov     dx, protHdr
    call    printString
    
    call    readByte
    mov     cl, al
    
    call    readByte
    mov     ch, al
    
    ; Initialize location information. Loader starts at 0x20000.
    mov     ax, BOOT_LOAD_SEG
    mov     es, ax
    
    ; bx contains the base address for writing.
    mov     bx, 0
    
    ; Begin reading data in 4K chunks.
syncRemote_ReadImg:
    test    cx, cx
    jz      runLoader
    
    mov     dx, strStatusPending
    call    printString
    
    dec     cx
    mov     di, 0
    
syncRemote_ReadImgLoop0:
    cmp     di, 0x1000
    jz      syncRemote_ReadImg
    
    call    readByte
    mov     [es:bx+di], al
    
    inc     di
    jmp     syncRemote_ReadImgLoop0
    
syncRemote_ReadImgLoop1:
    add     bx, 0x1000
    test    bx, bx
    jnz     syncRemote_ReadImg
    
    ; Roll-over detected, update segment.
    mov     ax, es
    add     ax, 0x1000
    mov     es, ax
    jmp     syncRemote_ReadImg
    
runLoader:
    jmp     $
    
; readByte:
;   al = Value read.
readByte:
    push    cx
    push    dx
    
    mov     cx, 0

readByte_WaitLoop:
    mov     dx, COM_REG_LSR_IDX
    call    inByte
    
    test    al, COM_REG_LSR_DRDY
    jnz     readByte_ConsumeByte
    
    call    delay
    
    ; This increments and indexes into the strStatusPending table.
    inc     cx
    mov     dx, cx
    and     dx, 0x0003
    shl     dx, 1
    add     dx, strStatusPending
    call    printString
    
    ; Repeat, until byte.
    jmp     readByte_WaitLoop
    
readByte_ConsumeByte:
    mov     dx, COM_REG_DATA_IDX
    call    inByte
    
    pop     dx
    pop     cx
    ret

; printString:
;   dx = String to print.
printString:
    push    ax
    push    bx
    
    mov     bx, dx
    
printString_Loop:
    mov     al, [bx]
    test    al, al
    jz      printString_Exit
    
    inc     bx
    
    call    printChar

    jmp     printString_Loop
    
printString_Exit:
    pop     bx
    pop     ax
    ret

printChar:
    push    ax
    push    bx
    
    mov     bx, 0
    mov     ah, 0x0E
    int     0x10
    
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

strBackspace:
    db      8, 0

strStatusPending:
    db      '-',  0
    db      '\',  0
    db      '|',  0
    db      '/',  0

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

