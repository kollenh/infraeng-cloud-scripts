    <#
    .SYNOPSIS
        Loops through all Backup Vaults in an account, returning any and all snapshots associated with the volume ID

    .DESCRIPTION
        
    .PARAMETER ObjectId
        ID of the volume from which the snapshots were taken; all associated snapshots will be returned

    .PARAMETER SourceRegion
        Name of the region where the volume resides

    .PARAMETER Test
        Switch to indicate the script should post to a different Teams channel for testing
    
    .EXAMPLE
        Get-EBSSnapshotByObjectId 

    .NOTES

    .Version
        1.0 Initial script created by Kollen Hensley, Slalom 	[12/01/2022]
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False)]
            [string[]]$AccountID  = @('138467534619','427878221502','761649062394')
        ,[Parameter(Mandatory=$false)]
            [string[]]$RegionList = @('us-west-1','us-west-2','us-east-1','us-east-2')

    )

# Credentials
    foreach ($ID in $AccountID) {
        try {
            Switch ($ID) {
                '427878221502'        {
                    # this is the "new" Infrastructure account
                    $ProfileName = 'InfraProd'
                }
                '761649062394'      {
                    $ProfileName = 'DRVault'
                }
                default          {
                    # this is the "legacy" Infrastructure account
                    $ProfileName = 'MyDefault' 
                }
            }
            Write-Host "`nUsing profile" -nonewline; Write-Host " $ProfileName " -ForegroundColor Cyan -NoNewline; Write-Host "for connection to account $ID"
            Initialize-AWSDefaultconfiguration -ProfileName $ProfileName
        }
        catch {
            throw "Unable to connect to the account"
            return
        }

        $Volume_Report = [System.Collections.ArrayList]::New()
        foreach ($Region in $RegionList) {
            Write-Host "Searching $Region region for volumes.."
            # Loop through each region and get all EBS volumes
            Get-EC2Volume -Region $Region | ForEach-Object {
                $Vol_Id      = $_.VolumeId
                $Vol_Tags    = $_.Tags
                
                $Volume_Info = [PSCustomObject]@{
                    Account     = $ID
                    Zone        = $_.AvailabilityZone
                    VolumeId    = $Vol_Id 
                    Name        = $($Vol_Tags.GetEnumerator() | Where-Object Key -eq 'Name').Value
                    Size        = $('{0:N0} GB' -f ($_.Size/1GB))
                    State       = $_.State
                    Created     = $_.CreateTime
                    BAKFreq     = $($Vol_Tags.GetEnumerator() | Where-Object Key -eq 'Backup Frequency').Value
                }

                #find any associated snapshots
                $Snapshot_Count = 0
                $filter_by_volumeid = @(@{name='volume-id';values=$Vol_Id})
                $Snapshots = Get-EC2Volume -Filter $filter_by_volumeid
                if ($Snapshots) {
                    $Snapshot_Count = ($Snapshots | Measure-Object).Count
                }
                $Volume_Info | Add-Member -MemberType NoteProperty -Name 'Snapshots' -Value $Snapshot_Count
                $Volume_Report.Add($Volume_Info) | Out-Null

            } #end foreach Volume
        
        } #end foreach Region
        
    } #end foreach Account
    
    return $Volume_Report