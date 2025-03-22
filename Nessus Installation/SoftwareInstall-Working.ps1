<#
.SYNOPSIS
    Installs and registers Nessus Agent on remote servers.

.DESCRIPTION
    This script automates the installation of the Nessus Agent on a list of remote servers, 
    ensuring that any old versions are uninstalled, and the new version is installed, linked, 
    and registered correctly.

.NOTES
    Script Name    : NessusAgentInstall.ps1
    Version        : 1.0
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : Automate the deployment of Nessus Agent across multiple servers.

.PREREQUISITES
    - Ensure WinRM is enabled on target servers.
    - A valid Nessus Agent installer is placed at the specified location.
    - Necessary permissions to execute remote commands and install software.

.PARAMETERS
    None.

.EXAMPLE
    .\NessusAgentInstall.ps1
    Runs the script to install and configure Nessus Agent on all servers listed in the input file.
#>

# Define variables
$Servers = Get-Content "C:\Temp\TestServers.txt"
$NessusInstallerPath = "C:\Temp\NessusAgent-10.8.2-x64.msi"
$NessusGroup = "Windows Server"
$NessusServer = "sensor.cloud.tenable.com"
$NessusKey = "abcdefghijklmnopqrstuvwxyz"
$logFilePath = "C:\Temp\NessusAgentInstallLog.txt"
$errorCsvPath = "C:\Temp\NessusAgentInstallErrors.csv"

# Initialize counters
$successCount = 0
$failureCount = 0
$skippedCount = 0

# Initialize error CSV
"Server,Reason" | Out-File -FilePath $errorCsvPath

# Start logging
"###### Nessus Agent Installation Log ######" | Out-File -FilePath $logFilePath -Append
"Script started at $(Get-Date)" | Out-File -FilePath $logFilePath -Append

foreach ($Server in $Servers) {
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $failureCount++
        "Error: Server name is null or empty." | Out-File -FilePath $errorCsvPath -Append
        continue
    }

    Write-Host "Processing $Server..." -ForegroundColor Cyan
    try {
        # Check if PSRemoting is enabled
        $psRemotingEnabled = Test-Connection -ComputerName $Server -Count 1 -Quiet
        if (-not $psRemotingEnabled) {
            $failureCount++
            "$Server,Error: Unable to connect to the server. Ensure WinRM is enabled." | Out-File -FilePath $errorCsvPath -Append
            continue
        }

        # Enable PSRemoting
        Invoke-Command -ComputerName $Server -ScriptBlock { Enable-PSRemoting -Force }

        # Check if Nessus Agent is installed
        $OldVersion = Invoke-Command -ComputerName $Server -ScriptBlock {
            Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "Nessus Agent*" }
        }

        if ($OldVersion) {
            Write-Host "Old version found on $Server. Uninstalling..." -ForegroundColor Yellow
            $logMessage = "Old version found on $Server. Uninstalling..."
            $logMessage | Out-File -FilePath $logFilePath -Append

            Invoke-Command -ComputerName $Server -ScriptBlock {
                $OldVersion = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "Nessus Agent*" }
                $OldVersion.Uninstall()
            }
            Write-Host "Uninstallation completed on $Server." -ForegroundColor Green
        } else {
            Write-Host "No old version found on $Server." -ForegroundColor Green
        }

        # Copy Nessus Agent installer
        Invoke-Command -ComputerName $Server -ScriptBlock { mkdir "C:\Temp" -Force }
        Copy-Item -Path $NessusInstallerPath -Destination "\\$Server\C$\Temp"

        # Install Nessus Agent
        Invoke-Command -ComputerName $Server -ScriptBlock {
            param ($InstallerPath)
            Start-Process -FilePath "msiexec" -ArgumentList "/i", $InstallerPath, "/qn", "/norestart", "ADDLOCAL=ALL", "INCLUDESERVICE=1" -Wait
        } -ArgumentList "\\$Server\C$\Temp\NessusAgent-10.8.2-x64.msi"

        # Register Nessus Agent
        Invoke-Command -ComputerName $Server -ScriptBlock {
            param ($ServerURL, $Key, $Group)
            Start-Process -FilePath "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe" -ArgumentList "agent", "link", "--key=$Key", "--groups=$Group", "--host=$ServerURL", "--port=443" -Wait
        } -ArgumentList $NessusServer, $NessusKey, $NessusGroup

        # Remove Nessus Agent installer
        Invoke-Command -ComputerName $Server -ScriptBlock {
            Remove-Item -Path "C:\Temp\NessusAgent-10.8.2-x64.msi" -Force
        }

        Write-Host "Nessus Agent installed and registered on $Server." -ForegroundColor Green
        $successCount++

    } catch {
        Write-Host "An error occurred on $Server $_" -ForegroundColor Red
        "$Server,Error: $_" | Out-File -FilePath $errorCsvPath -Append
        $failureCount++
    }
}

# Summary
Write-Host "###### Script completed ######"
Write-Host "Summary: $successCount succeeded, $failureCount failed, $skippedCount skipped."
"Script completed at $(Get-Date)" | Out-File -FilePath $logFilePath -Append
"Summary: $successCount succeeded, $failureCount failed, $skippedCount skipped." | Out-File -FilePath $logFilePath -Append
