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
            [string[]]$RegionList = @('us-west-1','us-west-2','us-east-1','us-east-2','eu-west-1')

    )

    # Check for credentials for each account
    #MyDefault = Prod
    #InfraProd = Shared Svcs
    #SecOps    = InfoSec
    #DRVault   = DR Account

    $Volume_List   = [System.Collections.ArrayList]::New()
    $Snapshot_List = [System.Collections.ArrayList]::New()
    foreach ($account in $AccountID) {
        Switch ($Account) {
            '252302356329'  {
                $AWS_Profile = 'SecOps'
                $AccountName = 'SecOps'
            }
            '427878221502'  {
                $AWS_Profile = 'InfraProd'
                $AccountName = 'Infra Shared'
            }
            default         {
                $AWS_Profile = 'MyDefault'
                $AccountName = 'Legacy Prod'
            }
        }
        
        foreach ($Region in $RegionList) {
            Initialize-AWSDefaultconfiguration -ProfileName $AWS_Profile -Region $Region

            # Get the data
            $Tags       = Get-EC2Tag
            $Volumes    = Get-EC2Volume
            $Snapshots  = Get-EC2Snapshots -OwnerId self -Region $Region
        
            foreach ($V in $Volumes) {
                $SnapCount = ($Snapshots | Where-Object VolumeId -eq $($v.VolumeId) | Measure-Object).Count
                $Object = [PSCustomObject]@{
                    Account     = $AccountName
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

            $Snapshots | Group-Object VolumeId | Foreach-Object {
                $Grouped_Snapshot = [PSCustomObject]@{
                    Account     = $AccountName
                    Region      = $Region
                    Number      = $_.Count
                    Volume      = $_.Name
                    Name        = $($Tags | Where-Object ResourceId -eq $_.Name | Where-Object Key -eq 'Name').Value
                    Description = $_.Group[-1].Description
                    Size        = $_.Group[-1].VolumeSize
                    Tier        = $_.Group[-1].StorageTier
                    State       = $_.Group[-1].State
                    Started     = $_.Group[-1].StartTime
                }
                $Snapshot_List.Add($Grouped_Snapshot) | Out-Null
            }
        }
    }
    
    Write-Host "Volumes accounted for $('{0:N0}' -f $SnapShotTotal) of $(($Snapshots | Measure-Object).Count) snapshots" -ForegroundColor Cyan

    $Volume_List | Export-Csv c:\IT\reports\Volumes.csv -NoTypeInformation
    $Snapshot_List | Export-Csv c:\IT\reports\Snapshots.csv -NoTypeInformation
    