    <#
    .SYNOPSIS
        Returns a report of all instances with EBS storage, unattached EBS volumes, and EBS snapshots

    .DESCRIPTION
        
        
    .PARAMETER 

    .PARAMETER SourceRegion

    .PARAMETER Test
        Switch to indicate the script should post to a different Teams channel for testing
    
    .EXAMPLE
        

    .NOTES

    .Version
        
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False)]
            [string[]]$AccountID  = @('138467534619','252302356329','427878221502')
        ,[Parameter(Mandatory=$false)]
            [string[]]$RegionList = @('us-west-1','us-west-2','us-east-1','us-east-2')

    )

    # Check for credentials for each account
    #MyDefault = Prod
    #InfraProd = Shared Svcs
    #SecOps    = InfoSec
    #DRVault   = DR Account

    $Volume_List   = [System.Collections.ArrayList]::New()
    $Snapshot_List = [System.Collections.ArrayList]::New()
    foreach ($Region in $RegionList) {
        Initialize-AWSDefaultconfiguration -ProfileName MyDefault -Region $Region


        # Get the data
#        $Tags       = Get-EC2Tag
        $Volumes    = Get-EC2Volume
        $Snapshots  = Get-EC2Snapshots -OwnerId self -Region $Region
    
        foreach ($V in $Volumes) {
            $SnapCount = ($Snapshots | Where-Object VolumeId -eq $($v.VolumeId) | Measure-Object).Count
            $Object = [PSCustomObject]@{
                Region      = $Region
                VolID       = $V.VolumeId
                Name        = ($V.Tags | Where-Object Key -eq 'Name').Value
                CreateTime  = $V.CreateTime
                Encrypted   = $V.Encrypted
                State       = $V.State
                VolumeType  = $V.VolumeType
                Size        = $V.Size
                Snapshots   = $SnapCount
            }
            $Volume_List.Add($Object) | Out-Null
            $SnapShotTotal  = $SnapShotTotal + $SnapCount
        }

        $Grouped_Snapshots  = $Snapshots | Group-Object VolumeId | Select-Object `
            Count,
            Name,
            @{Label='Description';Expression={$_.Group[-1].Description}},
            @{Label='Size';Expression={$_.Group[-1].VolumeSize}},
            @{Label='Tier';Expression={$_.Group[-1].StorageTier}},
            @{Label='State';Expression={$_.Group[-1].State}},
            @{Label='Started';Expression={$_.Group[-1].StartTime}}
        $Snapshot_List.Add($Grouped_Snapshots) | Out-Null
    }
    Write-Host "Volumes accounted for $('{0:N0}' -f $SnapShotTotal) snapshots" -ForegroundColor Cyan
    $Volume_List
    $Snapshot_List
    