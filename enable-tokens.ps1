$Definition = @'
using System;
using System.Runtime.InteropServices;

public class Win32Token {
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out long lpLuid);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, uint BufferLength, IntPtr PreviousState, IntPtr ReturnLength);

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct TOKEN_PRIVILEGES {
        public uint PrivilegeCount;
        public long Luid;
        public uint Attributes;
    }
}
'@

Add-Type -TypeDefinition $Definition

# Define Privilege constants
$TOKEN_ADJUST_PRIVILEGES = 0x0020
$TOKEN_QUERY = 0x0008
$SE_PRIVILEGE_ENABLED = 0x0002

# Get current process token
$hProcess = [System.Diagnostics.Process]::GetCurrentProcess().Handle
$hToken = [IntPtr]::Zero

if ([Win32Token]::OpenProcessToken($hProcess, ($TOKEN_ADJUST_PRIVILEGES -bor $TOKEN_QUERY), [ref]$hToken)) {
    # Extract all privileges owned by this admin identity
    $Privileges = (whoami /priv /fo csv | ConvertFrom-Csv) | Where-Object { $_."State" -eq "Disabled" }
    
    foreach ($Priv in $Privileges) {
        $Luid = 0
        if ([Win32Token]::LookupPrivilegeValue($null, $Priv."Privilege Name", [ref]$Luid)) {
            $TP = New-Object Win32Token+TOKEN_PRIVILEGES
            $TP.PrivilegeCount = 1
            $TP.Luid = $Luid
            $TP.Attributes = $SE_PRIVILEGE_ENABLED
            
            # Commit the enabled state
            [Win32Token]::AdjustTokenPrivileges($hToken, $false, [ref]$TP, 0, [IntPtr]::Zero, [IntPtr]::Zero)
        }
    }
    Write-Host "Token adaptation broadcast complete. Spawning fully enabled terminal session..." -ForegroundColor Green
    Start-Process powershell -Verb RunAs
} else {
    Write-Error "Failed to map process security token."
}
