<#
    .Synopsis 
        Adds a user or group to local administrator group

    .Description
        This scripts adds the given user or group to local administrators group on given list of servers.

    .Parameter ComputerName
        Computer Name(s) on which you want to add user/group to local administrators

    .Parameter ObjectType
        This parameter takes either of two values, User or Group. This parameter indicates the type of object
        you want to add to local administrators

    .Parameter ObjectName
        Name of the object (user or group) which you want to add to local administrators group. This should be in 
        Domain\UserName or Domain\GroupName format

    .Example
        Set-LocalAdminGroupMembers.ps1 -ObjectType User -ObjectName "AD\TestUser1" -ComputerName srvmem1, srvmem2 

        Adds AD\TestUser1 user account to local administrators group on srvmem1 and srvmeme2

    .Example
        Set-LocalAdminGroupMembers.ps1 -ObjectType Group -ObjectName "ADDomain\AllUsers" -ComputerName (Get-Content c:\servers.txt) 

        Adds AD\TestUser1 Group to local administrators group on servers listed in c:\servers.txt


#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,Position=1)]
    [ValidateSet("User","Group")]
    [String]
    $ObjectType,

    [Parameter(Mandatory=$true,Position=2)]
    [ValidateScript({($_.split("\").count -eq 2)})]
    [string]$ObjectName,

    [Parameter(Position=3)]
    [String[]]$ComputerName=$env:COMPUTERNAME
)

# Ensure directory exists
if (-not (Test-Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory
}

# Name and location of the output file
$ResultsFile = "c:\temp\ResultsofLocalGroupAddition.csv"

# Check if the file already exists to avoid adding duplicate headers
if (-not (Test-Path $ResultsFile)) {
    # Add headers if the file does not exist
    Add-Content -Path $ResultsFile -Value "ComputerName,Status,Comments"
}

$ObjDomain = $ObjectName.Split("\")[0]
$ObjName = $ObjectName.Split("\")[1]
$ComputerCount = $ComputerName.Count
$count = 0

foreach($Computer in $ComputerName) {
    $count++
    $Status = $null
    $Comment = $null
    Write-Host ("{0}. Working on {1}" -f $Count, $Computer)
    
    # Test if computer is online
    if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
        Write-Verbose "$Computer : Online"
        try {
            # Fallback to using Invoke-Command if WinNT:// fails
            Invoke-Command -ComputerName $Computer -ScriptBlock {
                $GroupObj = [ADSI]"WinNT://./Administrators"
                $GroupObj.Add("WinNT://$using:ObjDomain/$using:ObjName")
            }
            $Status = "Success"
            $Comment = "Added $ObjectName $ObjectType to Local administrators group"
            Write-Verbose "Successfully added $ObjectName $ObjectType to $Computer"
        } catch {
            # Handle any errors that occur during the addition
            $Status = "Failed"
            $Comment = $_.Exception.Message
            Write-Verbose "Failed to add $ObjectName $ObjectType to $Computer. Error: $Comment"
        }

        # Add the results to the CSV file
        Add-Content -Path $ResultsFile -Value ("{0},{1},{2}" -f $Computer, $Status, $Comment)
    } else {
        Write-Warning "$Computer : Offline"
        Add-Content -Path $ResultsFile -Value ("{0},{1},{2}" -f $Computer, "Offline", "")
    }
}
