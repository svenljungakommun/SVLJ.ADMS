#requires -version 2
<#

.SYNOPSIS
  Creates a Team in Teams

.DESCRIPTION
  Creates a Team in Teams with support for defining visibility, classification, and guest control.

.NOTES
  Version:        1.9
  Author:         odd-arne.haraldsen@svenljunga.se
  Creation Date:  2021-03-18
  Change Date:    2025-03-18

 .PREREQUISITS
  Powershell 5.0 or higher
  Microsoft Graph Teams Powershell module (Install-Module -Name Microsoft.Graph.Teams)
  Microsoft Graph Groups Powershell module (Install-Module -Name Microsoft.Graph.Groups)
  Microsoft Graph Users Powershell module (install-module Microsoft.Graph.Users)

 .DEPENDENCIES
  Modules
  - write-log
  - PSParameters
  - Send-HTMLErrorMessage


 .EXAMPLE
  Create-NewTeam -tName "Test Team" -tDescription "" -tOwner "firstname.lastname@svenljunga.se" -tVisiblity "private" -tGuests $False -tTemplate "project" -Force $False
 
#>

function Create-NewTeam() {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)][string]$tName,
        [string]$tDescription = "Collaboration group",
        [Parameter(Mandatory=$True)][string]$tOwner,
        [Parameter(Mandatory=$True)][string]$tVisiblity,
        [Parameter(Mandatory=$True)][bool]$tGuests,
		[string]$tTemplate = "standard"
        [bool]$Force = $False
    )

    # Clear tID
    $tID = $null

    # Set iCounter to 0
    $iCounter = 0

    # Success flag (default false)
    $tSuccess = $False

    if($Force) {

        # Write to host and log
        Write-Host "$($MyInvocation.MyCommand) Duplication protection overridden, creation is forced by parameter."
        write-log 3 "$($MyInvocation.MyCommand) Duplication protection overridden, creation is forced by parameter."

    }

    # Begin
    Try {

        # Set protocol type to TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Connect to Microsoft Graph services
        Connect-MgGraph -TenantId $($PSParameters["global.microsoft365.directory.id"]) -ClientId $($PSParameters["global.microsoft365.app.id"]) -CertificateThumbprint $($PSParameters["global.microsoft365.app.auth.thumbprint"]) | Out-Null

        # Write to host and log
        Write-Host "$($MyInvocation.MyCommand) Connected to Microsoft Graph services"
        write-log 3 "$($MyInvocation.MyCommand) Connected to Microsoft Graph services"

        # Check if team exists
        if(!$(Get-MgGroup| ? {$_.DisplayName -eq "$tName" -and $_.AdditionalProperties.resourceProvisioningOptions -eq "Team" }) -or $($Force -eq $True)) {

            # Set Template
            $tParams = @{
                "Template@odata.bind" = “https://graph.microsoft.com/v1.0/teamsTemplates('$tTemplate')”
                DisplayName = "$($tName)"
                Description = "$($tDescription)"
                Visibility = "$($tVisiblity)"
                Members = @(
		            @{
			            "@odata.type" = "#microsoft.graph.aadUserConversationMember"
			            Roles = @(
				            "owner"
			            )
			            "User@odata.bind" = "https://graph.microsoft.com/v1.0/users('$(Get-MgUser -UserId “$($tOwner)” | Select-Object -Expand Id)')"
		            }
                )
            }

            # Create Team
            New-MgTeam -BodyParameter $tParams -Erroraction Stop

            # Write to host and log
            Write-Host "$($MyInvocation.MyCommand) Created Team $($tName)"
            write-log 3 "$($MyInvocation.MyCommand) Created Team $($tName)"
            Write-Host "$($MyInvocation.MyCommand) Owner set to $($tOwner)"
            write-log 3 "$($MyInvocation.MyCommand) Owner set to $($tOwner)"

            # Write to host and log
            Write-Host "$($MyInvocation.MyCommand) Retrieving groupId for Team $($tName)"
            write-log 3 "$($MyInvocation.MyCommand) Retrieving groupId for Team $($tName)"

            # Loop until tID is not null or iCounter has reached 10 attempts
            do {

                # Increase iCounter
                $iCounter++

                # Write to host and log
                Write-Host "$($MyInvocation.MyCommand) Attempt $($iCounter)"
                write-log 4 "$($MyInvocation.MyCommand) Attempt $($iCounter)"
                Write-Host "$($MyInvocation.MyCommand) Waiting 5 seconds..."
                write-log 4 "$($MyInvocation.MyCommand) Waiting 5 seconds..."

                # Wait for 5 seconds
                sleep -Seconds 5

                # Get groupId
                $tId = $(Get-MgGroup -All | ? { $_.AdditionalProperties.resourceProvisioningOptions -eq "Team" -and $_.DisplayName -eq "$($tName)"} -ErrorAction Stop).Id

            } until ($tId -ne $null -or $iCounter -eq 10)
            
            # Write to host and log
            Write-Host "$($MyInvocation.MyCommand) Retrieved groupId $($tId) for Team $($tName)"
            write-log 4 "$($MyInvocation.MyCommand) Retrieved groupId $($tId) for Team $($tName)"

            # Check if guest access is allowed
            if(!$tGuests) {
                
                # Write to host and log
                Write-Host "$($MyInvocation.MyCommand) Guest access disabled"
                write-log 3 "$($MyInvocation.MyCommand) Guest access disabled"

                # Update Settings
                Update-MgTeam -TeamId $tId -BodyParameter @{
                    GuestSettings = @{
                        AllowToAddGuests = $false
                    }
                }

                # Write to host and log
                Write-Host "$($MyInvocation.MyCommand) Guest access has been disabled for Team $($tName)"
                write-log 3 "$($MyInvocation.MyCommand) Guest access has been disabled for Team $($tName)"

            }

            # Guest access is allowed
            else {

                # Write to host and log
                Write-Host "$($MyInvocation.MyCommand) Guest access is set to enabled"
                write-log 3 "$($MyInvocation.MyCommand) Guest access is set to enabled"

            }

            # return true
            return $True

        }

        # If team name already exist
        else {

            # Write to host and log
            Write-Host "$($MyInvocation.MyCommand) Could not create Team with name $($tName), already exists."
            write-log 3 "$($MyInvocation.MyCommand) Could not create Team with name $($tName), already exists."
            Write-Host "$($MyInvocation.MyCommand) Choose another name and try again."
            write-log 3 "$($MyInvocation.MyCommand) Choose another name and try again."

            # Send error message to IT-Support
            Send-HTMLErrorMessage $MyInvocation.MyCommand "Could not create Team $($tName)" "$($tName) already exists."

            # return false
            return $False

        }

    }

    # Catch and handle error
    Catch {

        # Write to host and log
        Write-Host "$($MyInvocation.MyCommand) Could not create Team $($tName)"
        write-log 3 "$($MyInvocation.MyCommand) Could not create Team $($tName)"
        Write-Host "$($MyInvocation.MyCommand) $($ERROR[0])"
        write-log 3 "$($MyInvocation.MyCommand) $($ERROR[0])"

        # Send error message to IT-Support
        Send-HTMLErrorMessage $MyInvocation.MyCommand "Could not create Team $($tName)" $ERROR[0]

        # return false
        return $False

    }

    # Clean up
    Finally {

        # Disconnect from Microsoft Graph services
        Disconnect-MgGraph | Out-Null

        # Write to host and log
        Write-Host "$($MyInvocation.MyCommand) Disconnected from Microsoft Graph services"
        write-log 3 "$($MyInvocation.MyCommand) Disconnected from Microsoft Graph services"

    }

}
