<#
.SYNOPSIS
    Monitors NTLM authentication-related event logs in real-time.

.DESCRIPTION
    This script continuously monitors NTLM authentication-related event logs (Event IDs: 4624, 4625, 4776)
    from the Security event log and logs them to a file.

.NOTES
    Script Name    : Monitor-NTLMEventLogs.ps1
    Version        : 1.0
    Author         : Open Source
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : Continuously monitor and log NTLM authentication events.

.PREREQUISITES
    - Must be run with administrative privileges.
    - Ensure the Security event log contains NTLM-related events.
    - Log file directory (C:\Logs) must exist or be created before execution.

.PARAMETERS
    -Interval <int>
      Specifies the interval (in seconds) to check for new events. Default is 60 seconds.

.EXAMPLE
    Start monitoring NTLM event logs with a 60-second interval:
    .\Monitor-NTLMEventLogs.ps1 -Interval 60
#>

Function Monitor-NTLMEventLogs {
   param (
       [int]$interval = 60
   )
   while ($true) {
       try {
           # Get current date and time for the filter
           $currentTime = Get-Date
           # Get NTLM related event logs (Event IDs: 4624, 4625, 4776)
           $events = Get-WinEvent -FilterHashtable @{
               LogName = 'Security';
               ID = 4624, 4625, 4776;
               StartTime = (Get-Date).AddSeconds(-$interval)
           }
           foreach ($event in $events) {
               # Parse and display relevant information from the event logs
               $timeCreated = $event.TimeCreated
               $eventID = $event.Id
               $message = $event.Message
               # Log the information to a file
               $logMessage = "Time: $timeCreated`nEvent ID: $eventID`nMessage: $message`n-----------------------------`n"
               $logMessage | Out-File -FilePath "C:\Logs\NTLMEventLogs.txt" -Append
           }
       } catch {
           Write-Host "An error occurred: $_"
       }
       # Wait for the specified interval before checking again
       Start-Sleep -Seconds $interval
   }
}

# Start monitoring NTLM event logs with default interval
Monitor-NTLMEventLogs -interval 60
