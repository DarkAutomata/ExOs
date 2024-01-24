#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <windows.h>

void
Usage()
{
    fprintf(stdout, "exec (CLIENT | SERVER) PIPE_NAME\n");
}

int
main(
    int argc,
    char* argv[]
    )
{
    HANDLE pipeHandle = INVALID_HANDLE_VALUE;
    HANDLE rdEvent = NULL;
    HANDLE wrEvent = NULL;
    
    OVERLAPPED rdOverlapped = {0};
    OVERLAPPED wrOverlapped = {0};
    
    BYTE wrByte = 0;
    
    BYTE rdBuffer[1024];
    WORD rdBufferIndex = 0;
    
    BOOL connected = FALSE;
    
    BOOL rdQueued = FALSE;
    BOOL wrQueued = FALSE;
    
    rdEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
    if (rdEvent == NULL)
    {
        goto Cleanup;
    }
    
    wrEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
    if (wrEvent == NULL)
    {
        goto Cleanup;
    }
    
    if (0 == stricmp(argv[1], "client"))
    {
        pipeHandle = CreateFileA(
                argv[2],
                (GENERIC_READ | GENERIC_WRITE),
                0,
                NULL,
                OPEN_EXISTING,
                FILE_FLAG_OVERLAPPED,
                NULL);
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

