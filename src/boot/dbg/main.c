#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <windows.h>

void
Usage()
{
    fprintf(stdout, "exec (CLIENT | SERVER) PIPE_NAME\n");
}

typedef struct _DBG_STATE
{
    HANDLE PipeHnd;
    HANDLE RdEvt;
    HANDLE WrEvt;
    
    BOOL PipeRdy;
    BOOL RdPnd;
    BOOL WrPnd;
    
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
DbgState_Create(
    _Out_ DBG_STATE* pState
    )
{
    // Most state can be zero initialized.
    ZeroMemory(pState, sizeof(*pState));
    
    // Pipe handles are special.
    pState->PipeHnd = INVALID_HANDLE_VALUE;
    
    // Create everything, check everything.
    pState->RdEvt = CreateEventA(NULL, FALSE, FALSE, NULL);
    pState->WrEvt = CreateEventA(NULL, FALSE, FALSE, NULL);
    
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
    
    fprintf(stdout, "ClineConn: State=%d\n", pState->PipeRdy);
    
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
            pState->WrPnd = TRUE;
        }
    }
    
    if (pState->WrPnd)
    {
        WaitForSingleObject(pState->WrEvt, INFINITE);
        pState->WrPnd = FALSE;
    }
    
    result = GetOverlappedResult(
            pState->PipeHnd,
            &pState->WrOvr, 
            &bytesWritten,
            FALSE);
    
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
            pState->RdPnd = TRUE;
        }
    }
    
    if (pState->RdPnd)
    {
        WaitForSingleObject(pState->RdEvt, INFINITE);
        pState->RdPnd = FALSE;
    }
    
    result = GetOverlappedResult(
            pState->PipeHnd,
            &pState->RdOvr, 
            &bytesRead,
            FALSE);
    
    if (! result)
    {
        fprintf(
                stdout, "DBG - %s:%d DbgState_ReadData Failure: %08X\n",
                __FILE__, __LINE__,
                GetLastError());
    }
    
    return result;
}

int
main(
    int argc,
    char* argv[]
    )
{
    DBG_STATE dbgState = {0};
    const char* pPipeName = "!!!";
    const USHORT pageCount = 0x0201;
    BYTE* pJunk = NULL;
    
    pJunk = (BYTE*)malloc(sizeof(BYTE) * 0x08000);
    if (! pJunk)
    {
        fprintf(stdout, "Alloc failed\n");
        return 1;
    }
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
    fprintf(stdout, "Connection successful, sending header...\n");
    
    if (! DbgState_SendData(&dbgState, (const BYTE*)("ExOs"), 4))
    {
        fprintf(stdout, "Failed to send connect packet.\n");
        return 1;
    }
    fprintf(stdout, "Connection header sent.\n");
    
    if (! DbgState_SendData(&dbgState, (const BYTE*)&pageCount, 2))
    {
        fprintf(stdout, "Sending page count failed.\n");
        return 1;
    }
    fprintf(stdout, "Payload page count send.\n");
    
    if (! DbgState_SendData(&dbgState, pJunk, 0x08000))
    {
        fprintf(stdout, "Payload send failed\n");
        return 1;
    }
    fprintf(stdout, "Finished send. Waiting to ready.\n");
    
    DbgState_ReadData(&dbgState, pJunk, 20);
    for (;;);
    
    fprintf(stdout, "Clean exit\n");
    
Cleanup:
    fprintf(stdout, "Cleanup\n");
    
    DbgState_Destroy(&dbgState);
    
    return 0;
}

