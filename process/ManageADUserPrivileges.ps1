#requires -version 3
<#
.SYNOPSIS
  Automatic management of AD privileges

.DESCRIPTION
  Automatic management of AD privileges

.NOTES
  Version:        1.4
  Author:         odd-arne.haraldsen@svenljunga.se
  Creation Date:  2021-09-21
  Change Date:    2021-10-22

.PREREQUISITES

  Engine
  - Powershell v3 or higher

  Parameters:
  - 

.DEPENDENCIES

  Modules
  - Is-Scheduled
  - fEnabled
  - write-log
  - Get-ADSIUsers
  - Get-ADSIManager
  - Get-Employees
  - Get-tGroups
  - Send-HTMLErrorMessage
  - Add-GroupMembershipBy
  - Remove-GroupMembershipBy

#>
Function ManageADUserPrivileges {

    <#
        Error handling
    #>
    $Error.clear();

    <#
        Fetches schedule and checks if the process is allowed to run at the given time.
    #>
    if($(Is-Scheduled "PS$($MyInvocation.MyCommand)")) {

        <#
            Checks if the function is enabled
        #>
        if ($(fEnabled "PS$($MyInvocation.MyCommand)")) {

            <#
                Write to screen and log
            #>
            write-host "$($MyInvocation.MyCommand) starting process..."
            write-log 4 "$($MyInvocation.MyCommand) starting process..."

            <#
                Write to screen and log
            #>
            write-host "$($MyInvocation.MyCommand) fetching users from AD"
            write-log 4 "$($MyInvocation.MyCommand) fetching users from AD"

            <#
                Create variables
            #>
            $ADUsers = $null

            <#
                Get users from AD 
            #>
            $ADUsers = $(Get-ADSIUsers)

            <#
                Try block
            #>
            try {

                <#
                    Check if $ADUsers contains data
                #>
                if($ADUsers) {

                    <#
                        Counter for number of corrections
                    #>
                    [int]$iCounter = 0

                    <#
                        Process users individually
                    #>
                    $ADUsers | % {
    
                        <#
                            Create variables
                        #>
                        $aAutomaticProvisioning = $null
                        $aAutomaticDeProvisioning = @()
                        $aUserJobs = $null
                        $UserVars = $null
                        $aUserMemberOf = $($_.memberof)
                        $UserID = $($_.samaccountname)

                        <#
                            Create hashtable to hold user information
                        #>
                        $UserVars = @{}
                        $UserVars.Add("samaccountname",$($_.samaccountname));
                        $UserVars.Add("mail",$($_.mail));
                        $UserVars.Add("displayname",$($_.displayname));
                        $UserVars.Add("ssn",$($_.extensionattribute2));

                        <#
                            Flag that the privilege has been automatically provisioned
                        #>
                        $UserVars.Add("AutoProvision",$true);

                        <#
                            Flag that the privilege has been automatically deprovisioned
                        #>
                        $UserVars.Add("AutoDeProvision",$true);

                        # If manager exists
                        if($_.manager) {
                            # Set manager as recipient with copy
                            $UserVars.Add("notifymanager",(Get-ADSIManager $_.manager).mail);
                        }

                        <#
                            Handle each group membership and check against tADGroups
                        #>
                        $($_.memberof) | % {
                            <#
                                Fetch groups from tADGroups
                            #>
                            $(Get-tGroups -fields "groupId,
                                groupName,
                                distinguishedName,
                                requiredTitle,
                                requiredDepartment,
                                requiredCompany,
                                requiredWorkPlace,
                                requiredWorkAddress"
                                -filter "automaticDeProvisioning = '1'
                                and groupEnabled = '1'
                                and distinguishedName = '$($_)"
                            ) | % {
                                <#
                                    Add to array of matched groups
                                #>
                                $aAutomaticDeProvisioning += @(
                                    [pscustomobject]@{
                                        groupId=$($_.groupId);
                                        groupName=$($_.groupName);
                                        distinguishedName=$($_.distinguishedName);
                                        requiredTitle=$($_.requiredTitle);
                                        requiredDepartment=$($_.requiredDepartment);
                                        requiredCompany=$($_.requiredCompany);
                                        requiredWorkPlace=$($_.requiredWorkPlace);
                                        requiredWorkAddress=$($_.requiredWorkAddress);
                                        Remove='0'
                                    }
                                )
                            }
                        }

                        <#
                            Fetch employments
                        #>
                        $(Get-Employees -fields "*" -filter "active") | % {

                            <#
                                Create array with employments
                            #>
                            $aUserJobs += @(
                                [pscustomobject]@{
                                    Title=$($_.Titel);
                                    Department=$($_.Arbetsstalle);
                                    Company=$($_.Forvaltning);
                                    WorkPlace=$($_.Arbetsort);
                                    WorkAddress=$($_.Arbetsadress);
                                }
                            )
            
                            <#
                                Fetch entitlements from tADGroups
                            #>
                            $(Get-tGroups -fields "groupId,
                                groupName,
                                distinguishedName"
                                -filter "(requiredTitle = 'any' or requiredTitle = '$($_.Titel)')
                                and (requiredDepartment = 'any' or requiredDepartment = '$($_.Arbetsstalle)')
                                and (requiredCompany = 'any' or requiredCompany = '$($_.Forvaltning)')
                                and (requiredWorkPlace = 'any' or requiredWorkPlace = '$($_.Arbetsort)')
                                and (requiredWorkAddress = 'any' or requiredWorkAddress = '$($_.Arbetsadress)')
                                and automaticProvisioning = '1'
                                and groupEnabled = '1'"
                            ) | % {
                                $aAutomaticProvisioning += @(
                                    [pscustomobject]@{
                                        groupId=$($_.groupId);
                                        groupName=$($_.groupName);
                                        distinguishedName=$($_.distinguishedName);
                                        Skip='0'
                                    }
                                )
                            }
                        }

                        <#
                            Continue if $aUserJobs exists
                        #>
                        if($aUserJobs) {

                            <#
                                Handle aAutomaticDeProvisioning if exists
                            #>
                            if($aAutomaticDeProvisioning) {
                                $aAutomaticDeProvisioning | % {
                                    $requiredTitle      = $($_.requiredTitle)
                                    $requiredDepartment = $($_.requiredDepartment)
                                    $requiredCompany    = $($_.requiredCompany)
                                    $requiredWorkPlace  = $($_.requiredWorkPlace)
                                    $requiredWorkAddress= $($_.requiredWorkAddress)
                                    
                                    <#
                                        Matching rules
                                    #>
                                    $actualTitle = if($($aUserJobs.where({$_.Title -eq $($requiredTitle)}).Title) -ne $null -or '') { $($aUserJobs.where({$_.Title -eq $($requiredTitle)}).Title) } else { "any" }
                                    $actualDepartment = if($($aUserJobs.where({$_.Department -eq $($requiredDepartment)}).Department) -ne $null -or '') { $($aUserJobs.where({$_.Department -eq $($requiredDepartment)}).Department) } else { "any" }
                                    $actualCompany = if($($aUserJobs.where({$_.Company -eq $($requiredCompany)}).Company) -ne $null -or '') { $($aUserJobs.where({$_.Company -eq $($requiredCompany)}).Company) } else { "any" }
                                    $actualWorkPlace = if($($aUserJobs.where({$_.WorkPlace -eq $($requiredWorkPlace)}).WorkPlace) -ne $null -or '') { $($aUserJobs.where({$_.WorkPlace -eq $($requiredWorkPlace)}).WorkPlace) } else { "any" }
                                    $actualWorkAddress = if($($aUserJobs.where({$_.WorkAddress -eq $($requiredWorkAddress)}).WorkAddress) -ne $null -or '') { $($aUserJobs.where({$_.WorkAddress -eq $($requiredWorkAddress)}).WorkAddress) } else { "any" }

                                    if( 
                                        ( $($actualTitle)      -ne $($_.requiredTitle) ) -or
                                        ( $($actualDepartment) -ne $($_.requiredDepartment) ) -or
                                        ( $($actualCompany)    -ne $($_.requiredCompany) ) -or
                                        ( $($actualWorkPlace)  -ne $($_.requiredWorkPlace) ) -or
                                        ( $($requiredWorkAddress) -ne $($_.requiredWorkAddress) )
                                    ) {
                                        $_.Remove = '1'
                                    }
                                }
                            }

                            <#
                                Handle aAutomaticProvisioning if exists
                            #>
                            if($aAutomaticProvisioning) {
                                $aAutomaticProvisioning | % {
                                    if($aUserMemberOf.Contains($($_.distinguishedName))) {
                                        $_.Skip = '1'
                                    }
                                }
                            }

                            <#
                                Handle group removals
                            #>
                            if($aAutomaticDeProvisioning) {
                                $aAutomaticDeProvisioning.where({$_.Remove -ne '0'}) | % {
                                    write-host "$($MyInvocation.MyCommand) $($UserID) missing active employment for entitlement $($_.groupName)"
                                    write-log 4 "$($MyInvocation.MyCommand) $($UserID) missing active employment for entitlement $($_.groupName)"
                                    Remove-GroupMembershipBy "Name" $($_.groupName) $UserVars
                                    if($UserVars.notify) { $UserVars.Remove("notify"); }
                                    $iCounter++
                                }
                            }

                            <#
                                Handle group additions
                            #>
                            if($aAutomaticProvisioning) {
                                $aAutomaticProvisioning.where({$_.Skip -eq '0'}) | % {
                                    write-host "$($MyInvocation.MyCommand) $($UserID) missing entitlement to $($_.groupName)"
                                    write-log 4 "$($MyInvocation.MyCommand) $($UserID) missing entitlement to $($_.groupName)"
                                    Add-GroupMembershipBy "Name" $($_.groupName) $UserVars
                                    if($UserVars.notify) { $UserVars.Remove("notify"); }
                                    $iCounter++
                                }
                            }

                        } else {
                            write-host "$($MyInvocation.MyCommand) could not handle privileges for $($UserID), required information missing"
                            write-log 3 "$($MyInvocation.MyCommand) could not handle privileges for $($UserID), required information missing"
                        }
                    }
                }

                if($iCounter -ge 0) {
                    write-host "$($MyInvocation.MyCommand) handled $($iCounter) changed privileges"
                    write-log 3 "$($MyInvocation.MyCommand) handled $($iCounter) changed privileges"
                    Send-HTMLNotifyOperator $MyInvocation.MyCommand "handled $($iCounter) changed privileges"
                } else {
                    write-host "$($MyInvocation.MyCommand) could not run, ADUsers contained no information"
                    write-log 3 "$($MyInvocation.MyCommand) could not run, ADUsers contained no information"
                    Send-HTMLErrorMessage $MyInvocation.MyCommand "could not run, ADUsers contained no information"
                }

            }
            catch {
                write-host "$($MyInvocation.MyCommand) An unexpected error occurred"
                write-host "$($MyInvocation.MyCommand) $Error[0]"
                write-log 3 "$($MyInvocation.MyCommand) An unexpected error occurred"
                write-log 3 "$($MyInvocation.MyCommand) $Error[0]"
                Send-HTMLErrorMessage $MyInvocation.MyCommand "An unexpected error occurred" $Error[0]
            }

        } else {
            write-host "$($MyInvocation.MyCommand) could not start, process is disabled."
            write-log 3 "$($MyInvocation.MyCommand) could not start, process is disabled."
        }
    }
}
