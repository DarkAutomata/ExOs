#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <windows.h>

void
Usage()
{
    fprintf(stdout, "exec (CLIENT | SERVER) PIPE_NAME\n");
}

typedef struct _DBG_PROT_HDR
{
    BYTE Signature[4];      // 'ExOs'
    USHORT CmdId;           // The protocol command.
    USHORT Meta;            // Extra data,
} DBG_PROT_HDR;

#define EXOS_DBG_PROT_ID_HELLO          0x0000
#define EXOS_DBG_PROT_ID_UPLOAD_0       0x0001

typedef struct _DBG_IMG_SPEC
{
    BYTE* pImageData;
    ULONG ImageSize;
} DBG_IMG_SPEC;

typedef struct _DBG_STATE
{
    HANDLE PipeHnd;
    HANDLE RdEvt;
    HANDLE WrEvt;
    
    BOOL PipeRdy;
    
    OVERLAPPED RdOvr;
    OVERLAPPED WrOvr;
    
    BYTE RdBuff[4096];
    BYTE WrBuff[4096];
} DBG_STATE;

BOOL
DbgState_Create(
    _Out_ DBG_STATE* pState
    );

VOID
DbgState_Destroy(
    _In_ DBG_STATE* pState
    );

BOOL
DbgState_ClientConn(
    _Inout_ DBG_STATE* pState,
    _In_z_ const char* pPipeName
    );

BOOL
DbgState_SendData(
    _Inout_ DBG_STATE* pState,
    _In_reads_bytes_(ByteCount) const BYTE* pData,
    _In_ ULONG ByteCount
    );

BOOL
DbgState_ReadData(
    _Inout_ DBG_STATE* pState,
    _Out_writes_bytes_(ByteCount) BYTE* pData,
    _In_ ULONG ByteCount
    );

BOOL
DbgState_SendImage(
    _Inout_ DBG_STATE* pState,
    _In_ DBG_IMG_SPEC* pImage
    );

BOOL
DbgState_Create(
    _Out_ DBG_STATE* pState
    )
{
    // Most state can be zero initialized.
    ZeroMemory(pState, sizeof(*pState));
    
    // Pipe handles are special.
    pState->PipeHnd = INVALID_HANDLE_VALUE;
    
    // Create everything, check everything.
    pState->RdEvt = CreateEventA(NULL, TRUE, FALSE, NULL);
    pState->WrEvt = CreateEventA(NULL, TRUE, FALSE, NULL);
    
    if ((pState->RdEvt == NULL) ||
        (pState->WrEvt == NULL))
    {
        DbgState_Destroy(pState);
        
        return FALSE;
    }
    
    return TRUE;
}

VOID
DbgState_Destroy(
    _In_ DBG_STATE* pState
    )
{
    if (pState->PipeHnd != INVALID_HANDLE_VALUE)
    {
        CloseHandle(pState->PipeHnd);
        pState->PipeHnd = INVALID_HANDLE_VALUE;
    }
    
    if (pState->RdEvt)
    {
        CloseHandle(pState->RdEvt);
        pState->RdEvt = NULL;
    }
    
    if (pState->WrEvt)
    {
        CloseHandle(pState->WrEvt);
        pState->WrEvt = NULL;
    }
}

BOOL
DbgState_ClientConn(
    _Inout_ DBG_STATE* pState,
    _In_z_ const char* pPipeName
    )
{
    int tryCount = 32;
    
    while (tryCount-- > 0)
    {
        DWORD lastError;
        
        fprintf(stdout, "ClientConn: [%d]%s...\n", tryCount, pPipeName);
        
        pState->PipeHnd = CreateFileA(
                pPipeName,
                (GENERIC_READ | GENERIC_WRITE),
                0,
                NULL,
                OPEN_EXISTING,
                FILE_FLAG_OVERLAPPED,
                NULL);
        
        // If not an invalid value, report success.
        if (pState->PipeHnd != INVALID_HANDLE_VALUE)
        {
            pState->PipeRdy = TRUE;
            break;
        }
        
        lastError = GetLastError();
        
        if (lastError == ERROR_PIPE_BUSY)
        {
            WaitNamedPipe(pPipeName, 60000);
        }
        else
        {
            fprintf(stdout, "Error: %08X\n", lastError);
            Sleep(1000);
        }
    }
    
    if (! pState->PipeRdy)
    {
        fprintf(stdout, "ClientConn Failed\n");
        goto Cleanup;
    }
    
Cleanup:
    
    return pState->PipeRdy;
}

BOOL
DbgState_SendData(
    _Inout_ DBG_STATE* pState,
    _In_reads_bytes_(ByteCount) const BYTE* pData,
    _In_ ULONG ByteCount
    )
{
    BOOL result = FALSE;
    DWORD bytesWritten;
    
    if (! pState->PipeRdy)
    {
        return FALSE;
    }
    
    ResetEvent(pState->WrEvt);
    
    pState->WrOvr.hEvent = pState->WrEvt;
    
    result = WriteFile(
            pState->PipeHnd,
            pData,
            ByteCount,
            &bytesWritten,
            &pState->WrOvr);
    if (! result)
    {
        if (GetLastError() == ERROR_IO_PENDING)
        {
            result = TRUE;
        }
    }
    
    if (result)
    {
        result = GetOverlappedResult(
                pState->PipeHnd,
                &pState->WrOvr, 
                &bytesWritten,
                TRUE);
    }
    
    if (! result)
    {
        fprintf(
                stdout, "DBG - %s:%d DbgState_SendData Failure: %08X\n",
                __FILE__, __LINE__,
                GetLastError());
    }
    
    return result;
}

BOOL
DbgState_ReadData(
    _Inout_ DBG_STATE* pState,
    _Out_writes_bytes_(ByteCount) BYTE* pData,
    _In_ ULONG ByteCount
    )
{
    BOOL result = FALSE;
    DWORD bytesRead;
    
    if (! pState->PipeRdy)
    {
        return FALSE;
    }
    
    ResetEvent(pState->RdEvt);
    
    pState->RdOvr.hEvent = pState->RdEvt;
    
    result = ReadFile(
            pState->PipeHnd,
            pData,
            ByteCount,
            &bytesRead,
            &pState->RdOvr);
    if (! result)
    {
        if (GetLastError() == ERROR_IO_PENDING)
        {
            result = TRUE;
        }
    }
    
    if (result)
    {
        result = GetOverlappedResult(
                pState->PipeHnd,
                &pState->RdOvr, 
                &bytesRead,
                TRUE);
    }
    
    if (! result)
    {
        fprintf(
                stdout, "DBG - %s:%d DbgState_ReadData Failure: %08X\n",
                __FILE__, __LINE__,
                GetLastError());
    }
    
    return result;
}

BOOL
DbgState_SendImage(
    _Inout_ DBG_STATE* pState,
    _In_ DBG_IMG_SPEC* pImage
    )
{
    BOOL result = TRUE;
    
    return result;
}

int
main(
    int argc,
    char* argv[]
    )
{
    BOOL result = TRUE;
    DBG_STATE dbgState = {0};
    DBG_PROT_HDR dbgHdr = {0};
    const char* pPipeName = "!!!";
    const USHORT pageCount = 0x0201;
    BYTE* pJunk = NULL;
    
    pJunk = (BYTE*)malloc(sizeof(BYTE) * 0x08000);
    if (! pJunk)
    {
        fprintf(stdout, "Alloc failed\n");
        return 1;
    }
    else
    {
        int i;
        
        for (i = 0; i < 0x08000; i++)
        {
            pJunk[i] = (BYTE)(i & 0xFF);
        }
    }
    
    pPipeName = argv[1];
    
    fprintf(stdout, "Attempting connection...\n");
    
    if (! DbgState_ClientConn(&dbgState, pPipeName))
    {
        fprintf(stdout, "Failed to connect client.\n");
        return 1;
    }
    
    fprintf(stdout, "Connection successful, syncing...\n");
    
    // Send the boot code.
    dbgHdr.Signature[0] = 'E';
    dbgHdr.Signature[1] = 'x';
    dbgHdr.Signature[2] = 'O';
    dbgHdr.Signature[3] = 's';
    dbgHdr.CmdId = 1;
    dbgHdr.Meta = 2;        // 2 x 4K pages, 8K total.
    
    result = DbgState_SendData(&dbgState, (BYTE*)&dbgHdr, sizeof(dbgHdr));
    
    fprintf(stdout, "Sent header.\n");
    
Cleanup:
    
    DbgState_Destroy(&dbgState);
    
    if (pJunk)
    {
        free(pJunk);
    }
    return 0;
}

