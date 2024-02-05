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

%define EXOS_DBG_PROT_ID_HELLO      0x0000
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

startSync:
    mov     cx, 128

sendSync_0:
    dec     cx
    jz      readBootImage_ReadHdr_0
    
    mov     [ds:protHdr_Id], EXOS_DBG_PROT_ID_HELLO
    mov     [ds:protHdr_Meta], cx
    call    writeHdr
    
    jmp     sendSync_0
    
readBootImage_ReadHdr_0:
    ; Update the header for reply testing.
    mov     byte [ds:protHdr_Id], EXOS_DBG_PROT_ID_UPLOAD_0
    
    ; Just updated the header with the upload command. Verify 6 bytes of the
    ; header, then read the meta data to get the page count. After that stream
    ; into memory.
    mov     cx, 6
    call    verifyHdr
    
    jmp $
    ; Oops.
    call    failure
    
readBootImage_ReadHdr_1:
    inc     bx
    jmp     readBootImage_ReadHdr_0
    
readBootImage_ReadImgSize:
    call    readByte
    mov     cl, al
    
    call    readByte
    mov     ch, al
    
    jmp $
    ; Initialize location information. Loader starts at 0x20000.
    mov     ax, BOOT_LOAD_SEG
    mov     es, ax
    
    ; bx contains the base address for writing.
    mov     bx, 0
    
    ; Begin reading data in 4K chunks.
readBootImage_ReadImg:
    test    cx, cx
    jz      runLoader
    
    dec     cx
    
readBootImage_ReadImg_0:
    test    bx, 0x0FFF
    jz      readBootImage_ReadImg_1
    
    call    readByte
    mov     [es:bx], al
    
    inc     bx
    jmp     readBootImage_ReadImg_0
    
readBootImage_ReadImg_1:
    test    bx, bx
    jnz     readBootImage_ReadImg
    
    ; Roll-over detected, update segment.
    mov     ax, es
    add     ax, 0x1000
    mov     es, ax
    jmp     readBootImage_ReadImg
    
runLoader:
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
    push    dx
    mov     dx, cx
    add     dx, [ds:comAddress]
    out     dx, al
    mov     dx, 0xFF00              ; Include a delay.

outByte_0:
    dec     dx
    jnz     outByte_0
    
    pop     dx
    ret

; waitComStatus
;   Wait for a status bits to be set on the COM port.
;   cx:     Flags to wait on.
waitComStatus:
    call    inByte
    
    test    al, COM_REG_LSR_DRDY
    jnz     waitComStatus_End
    
    call    printState
    
    ; Repeat, until flags set.
    jmp     waitComStatus
    
waitComStatus_End:
    ret

; BYTE readByte:
;   Reads a data byte from the configured COM port.
readByte:
    mov     cx, COM_REG_LSR_DRDY
    call    waitComStatus
    mov     cx, COM_REG_DATA_IDX
    jmp     inByte      ; Tail call.

; writeHdr
;   Writes protHdr contents to the configured COM port.
writeHdr:
    push    bx
    push    cx
    push    di
    
    mov     bx, protHdr
    mov     di, 0
    
writeHdr_0:
    mov     cx, COM_REG_LSR_S_TXE
    call    waitComStatus
    
    mov     cl, [ds:bx+di]
    call    outByte
    inc     di
    cmp     di, 8
    jb      writeHdr_0
    
writeHdr_1:
    pop     di
    pop     cx
    pop     bx
    ret

; printState:
;   Prints the state registers.
printState:
    push    cx
    push    dx
    
    mov     cl, 10          ; Reset cursor position
    call    printChar
    
    ; Print the version.
    mov     cl, [ds:protHdr_Version]
    mov     dx, 8
    call    printBin
    
    ; Print a dash.
    mov     cl, '-'
    call    printChar
    
    ; Print Command ID.
    mov     cl, [ds:protHdr_Id]
    mov     dx, 8
    call    printBin
    
    ; Print a dash.
    mov     cx, [ds:protHdr_Meta]
    mov     dx, 16
    call    printBin
    
    pop     dx
    pop     cx
    ret

; printBin
;   Prints an 8 or 16-bit number in binary.
;   cx:     The value to print.
;   dx:     The bit count to output.
printBin:
    push    ax
    push    cx
    push    dx
    
    mov     ax, cx                  ; Shift value to ax.
printBin_0:
    dec     dx                      ; Decrement print amount.
    jz      printBin_1              ; Exit when 0.
    
    push    ax                      ; Save ax before shifting it.
    mov     cl, dl                  ; Load cl with the shift amount
    shr     ax, cl                  ; Shift ax right by current bit index to print.
    and     ax, 0x0001              ; Mask everything off by the first bit.
    add     al, '0'                 ; Add '0' so bit set ==> '1', bit clear ==> '0'
    mov     cl, al                  ; Shift al into cl for calling printChar.
    call    printChar               ; Call printChar, cl = '0' or '1'.
    pop     ax                      ; Restore ax.
    jmp     printBin_0              ; Continue.
    
printBin_1:
    pop     dx
    pop     cx
    ret

; verifyHdr
; Reads cx bytes from the configured COM port and compares.
;   cx:     The number of characters to compare.
verifyHdr:
    push    bx
    push    cx
    
    xor     ax, ax              ; Clear ax to setup for use.
    mov     bx, protHdr         ; Start reading the first header byte.
    
verifyHdr_0:
    test    cx, cx              ; Test remaining byte count, exit on 0.
    jz      verifyHdr_1
    
    call    readByte            ; Read a byte.
    sub     al, [ds:bx]         ; Compare byte read with buffer.
    jnz     verifyHdr_1
    
    inc     bx                  ; Advance compare pointer.
    dec     cx                  ; Reduce the counter.
    jmp     verifyHdr_0
    
verifyHdr_1:
    pop     cx
    pop     bx
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
    ; Loop on failure.
    jmp     $

; Define protocol data.
; The header expected before every message.
protHdr:
    db      'E', 'x', 'O', 's'
protHdr_Id:
    dw      EXOS_DBG_PROT_ID_HELLO
protHdr_Meta:
    dw      0x0000

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

