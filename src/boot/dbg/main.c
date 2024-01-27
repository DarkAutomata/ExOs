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
    
    if ((pState->RdEvent == NULL) ||
        (pState->WrEvent == NULL))
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
        pState->RdEvent = NULL;
    }
    
    if (pStae->WrEvt)
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
        
        result = GetOverlappedResult(
                pState->PipeHnd,
                pState->WrOvr, 
                &bytesWritten,
                FALSE);
        
        if (! result)
        {
            fprintf(
                    stdout, "DBG - %s:%d DbgState_SendData Failure: %08X\n",
                    __FILE__, __LINE__,
                    GetLastError());
        }
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
}

int
main(
    int argc,
    char* argv[]
    )
{
    DBG_STATE dbgHost = {0};
    
    dbgHost.PipeHnd = INVALID_HANDLE_VALUE;
    
    dbgHost.rdEvt = CreateEvent(NULL, FALSE, FALSE, NULL);
    if (dbgHost.rdEvt == NULL)
    {
        goto Cleanup;
    }
    
    dbgHost.wrEvt = CreateEvent(NULL, FALSE, FALSE, NULL);
    if (dbgHost.wrEvt == NULL)
    {
        goto Cleanup;
    }
    
    if (0 == stricmp(argv[1], "client"))
    {
        while (pipeHandle == INVALID_HANDLE_VALUE)
        {
            pipeHandle = CreateFileA(
                    argv[2],
                    (GENERIC_READ | GENERIC_WRITE),
                    0,
                    NULL,
                    OPEN_EXISTING,
                    FILE_FLAG_OVERLAPPED,
                    NULL);
            
            if (pipeHandle != INVALID_HANDLE_VALUE)
            {
                break;
            }
            
            if (GetLastError() == ERROR_PIPE_BUSY)
            {
                WaitNamedPipe(argv[2], 10000);
            }
            else
            {
                fprintf(stdout, "Error: %08X\n", GetLastError());
                Sleep(1000);
            }
        }
    }
    else if (0 == stricmp(argv[1], "server"))
    {
        // Create the pipe handle.
        pipeHandle = CreateNamedPipeA(
                argv[2],
                (PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED),
                (PIPE_TYPE_BYTE |
                PIPE_READMODE_MESSAGE |
                PIPE_WAIT),
                PIPE_UNLIMITED_INSTANCES,
                4096,
                4096,
                0,
                NULL);
    }
    else
    {
        Usage();
        return -1;
    }
    
    if (pipeHandle == INVALID_HANDLE_VALUE)
    {
        fprintf(stdout, "Creation Failure: %08X\n", GetLastError());
        goto Cleanup;
    }
    
    connected = TRUE;
    
    if (! connected)
    {
        fprintf(stdout, "Connection Failure: %08X\n", GetLastError());
        goto Cleanup;
    }
    
    while (connected)
    {
        if (! rdQueued)
        {
            ZeroMemory(&rdOverlapped, sizeof(rdOverlapped));
            rdOverlapped.hEvent = rdEvent;
            
            rdQueued = ReadFile(
                    pipeHandle,
                    &rdBuffer[rdBufferIndex],
                    1,
                    NULL,
                    &rdOverlapped);
            if (! rdQueued)
            {
                if (GetLastError() == ERROR_IO_PENDING)
                {
                    rdQueued = TRUE;
                }
                else
                {
                    fprintf(stdout, "Read failure: %08X\n", GetLastError());
                    goto Cleanup;
                }
            }
        }
        
        // 
        // Attempt to send 
        // 
        // Wait until data read.
        //
        WaitForSingleObject(rdEvent, INFINITE);
        rdBufferIndex++;
        
        // 
        // Check for valid data.
        // 
        if (rdBufferIndex >= 4)
        {
            rdBuffer[rdBufferIndex] = 0;
            fprintf(stdout, "RECEIVED: %s\n", rdBuffer);
            rdBufferIndex = 0;
        }
    }
    
Cleanup:
    
    fprintf(stdout, "Exiting.\n");

    if (pipeHandle != INVALID_HANDLE_VALUE)
    {
        CloseHandle(pipeHandle);
    }
    
    if (rdEvent != NULL)
    {
        CloseHandle(rdEvent);
    }
    
    if (wrEvent != NULL)
    {
        CloseHandle(wrEvent);
    }
    
    return 0;
}

