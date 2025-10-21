<#
.SYNOPSIS
    Copies a folder to multiple domain controllers and logs success/failure.

.DESCRIPTION
    Reads a list of DC names from a text file, copies a source folder to each DC's target path,
    and exports the results to a CSV log for auditability.

.NOTES
    Author: Jonathan Preetham
    Date: 2025-10-21
    Requirements: Ensure remote access permissions and firewall rules allow SMB traffic.
#>

#region Configuration
$SourceFolder   = "\\ServerName\Azure ATP Sensor Setup"         # Folder to copy
$TargetFolder   = "C$\Temp"         # Target path on remote DCs (e.g., c$\TargetFolder)
$DCListFile     = "C:\Temp\DCList.txt"          # Text file with DC names, one per line
$LogFile        = "C:\Temp\CopyResults.csv"      # Output CSV log file
#endregion

#region Initialize
$Results = @()
$DCList = Get-Content -Path $DCListFile
$TotalDCs = $DCList.Count
#endregion

#region Main Logic
for ($i = 0; $i -lt $TotalDCs; $i++) {
    $dc = $DCList[$i]
    $Destination = "\\$dc\$TargetFolder"
    $Status = "Unknown"
    $ErrorMessage = ""

    # Show progress
    $PercentComplete = [int](($i + 1) / $TotalDCs * 100)
    Write-Progress -Activity "Copying folder to DCs" `
                   -Status "Processing $dc ($($i + 1)/$TotalDCs)" `
                   -PercentComplete $PercentComplete

    try {
        Copy-Item -Path $SourceFolder -Destination $Destination -Recurse -Force -ErrorAction Stop
        $Status = "Success"
    }
    catch {
        $Status = "Failure"
        $ErrorMessage = $_.Exception.Message
    }

    $Results += [PSCustomObject]@{
        DCName        = $dc
        Destination   = $Destination
        Status        = $Status
        ErrorMessage  = $ErrorMessage
        Timestamp     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    # Console feedback
    if ($Status -eq "Success") {
        Write-Host "[Success] Copy to $dc" -ForegroundColor Green
    }
    else {
        Write-Host "[Failure] Copy to $dc" -ForegroundColor Red
    }
}
#endregion

#region Export Results
$Results | Export-Csv -Path $LogFile -NoTypeInformation -Encoding UTF8
Write-Host "`nCopy operation completed. Results exported to $LogFile" -ForegroundColor Cyan
#endregion