<#
.SYNOPSIS
    Checks if PowerShell remoting is enabled on a list of servers.

.DESCRIPTION
    This script reads a list of servers from a file (CSV or TXT) and checks if PowerShell remoting is enabled on each.
    The results are logged to a specified file for later review.

.NOTES
    Script Name    : Check-PSRemoting.ps1
    Version        : 1.0
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : Validate PowerShell remoting status on remote servers.

.PREREQUISITES
    - Ensure WinRM is enabled on remote servers.
    - The file containing server names should be in a valid format (one server per line for TXT, or a single column for CSV).

.PARAMETERS
    -ServersFile: Path to the file containing server names.
    -LogFile: Path to the log file where results will be saved.

.EXAMPLE
    .\Check-PSRemoting.ps1 -ServersFile "C:\Temp\Servers.txt" -LogFile "C:\Temp\PSRemotingLog.txt"
#>

param (
    [string]$ServersFile = "C:\Temp\Servers.txt",
    [string]$LogFile = "C:\Temp\PSRemotingLog.txt"
)

# Read servers from file
if (-Not (Test-Path $ServersFile)) {
    Write-Host "Error: Servers file not found at $ServersFile" -ForegroundColor Red
    exit 1
}

$Servers = Get-Content -Path $ServersFile

# Start logging
"###### PowerShell Remoting Check Log ######" | Out-File -FilePath $LogFile -Append
"Script started at $(Get-Date)" | Out-File -FilePath $LogFile -Append

foreach ($Server in $Servers) {
    if ([string]::IsNullOrWhiteSpace($Server)) {
        Write-Host "Skipping empty server entry." -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Checking PowerShell remoting on $Server..." -ForegroundColor Cyan
    try {
        Test-WSMan -ComputerName $Server -ErrorAction Stop
        Write-Host "$Server PowerShell remoting is enabled." -ForegroundColor Green
        "$Server, Success: PowerShell remoting is enabled." | Out-File -FilePath $LogFile -Append
    } catch {
        Write-Host "$Server PowerShell remoting is NOT enabled." -ForegroundColor Red
        "$Server, Error: PowerShell remoting is NOT enabled." | Out-File -FilePath $LogFile -Append
    }
}

# End logging
"Script completed at $(Get-Date)" | Out-File -FilePath $LogFile -Append
Write-Host "Check completed. Log file saved at $LogFile" -ForegroundColor Cyan
