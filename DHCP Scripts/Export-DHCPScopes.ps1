<#
.SYNOPSIS
    Export DHCP scope details from multiple DHCP servers, showing Primary and Secondary DNS separately.

.DESCRIPTION
    This script connects to each DHCP server listed in a text file and exports the DHCP scope settings to a CSV file, including Primary and Secondary DNS servers separately.

.NOTES
    Script Name    : Export-DHCPScopes.ps1
    Version        : 1.0
    Author         : Jonathan Preetham
    Approved By    : [Approver's Name]
    Date           : [Today's Date]
    Purpose        : Export DHCP scope and DNS information for documentation or review.

.PREREQUISITES
    - DHCP Server role installed on the servers.
    - Appropriate permissions to query DHCP servers.
    - DHCP Server PowerShell module available.
    - Tested in 2012, 2016 & 2019 Servers

.PARAMETERS
    None

.EXAMPLE
    Run the script directly after setting the Servers.txt path.

#>

# Start of Script

# Path to the text file containing list of DHCP Server names
$DhcpServerList = "C:\Scripts\Servers.txt"

# Output path for CSV
$OutputPath = "C:\Scripts\DHCPScopesExport.csv"

# Module Installation
Import-Module DHCPServer

# Initialize empty array
$AllScopes = @()

# Read server names from file
$Servers = Get-Content -Path $DhcpServerList

foreach ($Server in $Servers) {
    try {
        Write-Host "Processing DHCP Server: $Server" -ForegroundColor Cyan

        # Get all scopes from the server
        $Scopes = Get-DhcpServerv4Scope -ComputerName $Server

        foreach ($Scope in $Scopes) {
            # Get scope options
            $Options = Get-DhcpServerv4OptionValue -ScopeId $Scope.ScopeId -ComputerName $Server -ErrorAction SilentlyContinue

            # Extract DNS servers info (Option ID 6)
            $DnsServers = ($Options | Where-Object {$_.OptionId -eq 6}).Value

            # Assign Primary and Secondary DNS (handle if only one exists)
            $PrimaryDNS = $null
            $SecondaryDNS = $null

            if ($DnsServers.Count -ge 1) {
                $PrimaryDNS = $DnsServers[0]
            }
            if ($DnsServers.Count -ge 2) {
                $SecondaryDNS = $DnsServers[1]
            }

            # Collect data
            $AllScopes += [PSCustomObject]@{
                DHCPServerName = $Server
                ScopeName      = $Scope.Name
                ScopeID        = $Scope.ScopeId
                StartRange     = $Scope.StartRange
                EndRange       = $Scope.EndRange
                SubnetMask     = $Scope.SubnetMask
                State          = $Scope.State
                PrimaryDNS     = $PrimaryDNS
                SecondaryDNS   = $SecondaryDNS
            }
        }
    }
    catch {
        Write-Warning "Failed to process $Server. Error: $_"
    }
}

# Export to CSV
$AllScopes | Export-Csv -Path $OutputPath -NoTypeInformation -Force

Write-Host "DHCP Scopes exported to $OutputPath" -ForegroundColor Green

# End of Script
