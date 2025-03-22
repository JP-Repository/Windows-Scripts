<#
.SYNOPSIS
    This script checks and exports Task Scheduler information from servers listed in a CSV file, after verifying their availability.

.DESCRIPTION
    The script retrieves Task Scheduler details (task names, status, triggers, etc.) from servers listed in a CSV file, checks if the server is reachable, and exports the information to a CSV file on the user's Desktop.

.NOTES
    Script Name    : Export-TaskSchedulerInfo.ps1
    Version        : 1.1
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : Export Task Scheduler information from specified servers.

.PARAMETERS
    None

.EXAMPLE
    .\Export-TaskSchedulerInfo.ps1

    This will retrieve Task Scheduler information from the servers listed in the ServerNames.csv file after checking if they are reachable, and export it to a CSV file on the Desktop.

#>

# Check PowerShell version and required module
$requiredPowershellVersion = "5.1"
$requiredModule = "ScheduledTasks"

# Check if the PowerShell version meets the required version
$psVersion = $PSVersionTable.PSVersion
if ($psVersion -lt [Version]$requiredPowershellVersion) {
    Write-Host "This script requires PowerShell version $requiredPowershellVersion or higher." -ForegroundColor Red
    exit
}

# Check if the required module is installed
if (-not (Get-Module -ListAvailable -Name $requiredModule)) {
    Write-Host "The '$requiredModule' module is not installed. Please install it to continue." -ForegroundColor Red
    exit
}

# Import the required module
Import-Module $requiredModule

# Define the output file path (Desktop location)
$outputFile = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('Desktop'), 'TaskScheduler_Info.csv')

# Define the path to the CSV file containing server names
$csvFilePath = "C:\Path\To\ServerNames.csv"  # Update this path to your CSV file

# Import server names from the CSV file
$servers = Import-Csv -Path $csvFilePath

# Initialize an empty array to store task information
$taskInfoArray = @()

# Total number of servers to process
$totalServers = $servers.Count
$currentServer = 0

# Loop through each server from the CSV and retrieve Task Scheduler information
foreach ($server in $servers) {
    $currentServer++

    # Check if the server is reachable using Test-Connection
    Write-Host "Checking availability of $($server.ServerName)..." -ForegroundColor Cyan
    $isReachable = Test-Connection -ComputerName $server.ServerName -Count 1 -Quiet

    # If the server is reachable, retrieve Task Scheduler information
    if ($isReachable) {
        Write-Host "$($server.ServerName) is reachable. Retrieving Task Scheduler information..." -ForegroundColor Green

        # Get all scheduled tasks on the server
        try {
            $tasks = Get-ScheduledTask -ComputerName $server.ServerName
        } catch {
            Write-Host "Error retrieving tasks from $($server.ServerName). Skipping..." -ForegroundColor Red
            continue
        }

        # Loop through each task and collect the necessary information
        foreach ($task in $tasks) {
            $taskInfo = New-Object PSObject -property @{
                ServerName      = $server.ServerName
                TaskName        = $task.TaskName
                State           = $task.State
                LastRunTime     = $task.LastRunTime
                NextRunTime     = $task.NextRunTime
                TriggerType     = ($task.Triggers | ForEach-Object { $_.TriggerType }) -join ', '
                Author          = $task.Principal.UserId
                TaskPath        = $task.TaskPath
            }

            # Add the task information to the array
            $taskInfoArray += $taskInfo
        }
    } else {
        Write-Host "$($server.ServerName) is not reachable. Skipping..." -ForegroundColor Yellow
    }

    # Update the progress bar
    $percentComplete = ($currentServer / $totalServers) * 100
    Write-Progress -PercentComplete $percentComplete -Status "Processing $($server.ServerName)" -Activity "Retrieving Task Scheduler info..."

}

# Export the task information to a CSV file
$taskInfoArray | Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "Task Scheduler information has been exported to $outputFile" -ForegroundColor Green
