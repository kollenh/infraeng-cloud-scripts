    <#
    .SYNOPSIS
        Loops through all Backup Vaults in an account, returning any and all snapshots associated with the volume ID

    .DESCRIPTION
        
    .PARAMETER VolumeId
        ID of the volume from which the snapshots were taken; all associated snapshots will be returned

    .PARAMETER SourceRegion
        Name of the region where the volume resides

    .PARAMETER Test
        Switch to indicate the script should post to a different Teams channel for testing
    
    .EXAMPLE
        Get-EBSSnapshotByVolumeId 

    .NOTES

    .Version
        1.0 Initial script created by Kollen Hensley, Slalom 	[12/01/2022]
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
            [string]$VolumeId
        ,[Parameter(Mandatory=$False)]
            [string]$SourceRegion = 'us-west-2'
        ,[Parameter(Mandatory=$False)]
            [string]$SourceAccount = '138467534619'
        ,[Parameter(Mandatory=$false)]
            [switch]$Test
        ,[Parameter(Mandatory=$False)]
            [string[]]$AccountID  = @('138467534619','427878221502','761649062394')
        ,[Parameter(Mandatory=$false)]
            [string[]]$RegionList = @('us-west-1','us-west-2','us-east-1','us-east-2')
    )

    $Snapshot_Report = [System.Collections.ArrayList]::New()
    foreach ($Account in $AccountID) {
        try {
            Switch ($Account) {
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
            Write-Host "`nUsing $ProfileName for connection to $Account" -ForegroundColor Yellow
            Initialize-AWSDefaultconfiguration -ProfileName $ProfileName
        }
        catch {
            throw "Unable to connect to the account"
            return
        }
        foreach ($Region in $RegionList) {
            Write-Host "Searching for Vaults in $Region region..."
            $BackupVaultCheck = Get-BAKBackupVaultList -Region $Region
            foreach ($Vault in $BackupVaultCheck) {
                $BackupVaultName    = $Vault.BackupVaultName
                $Num_RecoveryPoints = $Vault.NumberOfRecoveryPoints
                if ($Num_RecoveryPoints -eq 0) {
                    Write-Host "  no recovery points found in vault $BackupVaultName"
                    continue
                }
                else {
                    Write-Host "Searching for snapshots in "-nonewline; Write-Host "$BackupVaultName..." -ForegroundColor Yellow
                    $ObjResourceArn = "arn:aws:ec2:${SourceRegion}:${SourceAccount}:volume/${VolumeId}"
                    try {
                        $SnapShots = Get-BAKRecoveryPointsByBackupVaultList -BackupVaultName $BackupVaultName -ByResourceArn $ObjResourceArn -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Host "  no recovery points for $VolumeId found in vault $BackupVaultName"
                        continue
                    }
                    if ($SnapShots) {
                        Write-Host "  $(($SnapShots | Measure-Object).Count) recovery objects were discovered" -ForegroundColor Cyan
                        Write-Host "  building report..."
                        foreach ($Snapshot in $SnapShots) {
                            $SnapshotTags = Get-BAKResourceTag -Region $Region -ResourceArn $Snapshot.RecoveryPointArn
                            $SnapshotInfo = [PSCustomObject]@{
                                Account     = $Account
                                Region      = $Region
                                Vault       = $BackupVaultName
                                Volume      = $($SnapshotTags.GetEnumerator() | Where-Object Key -eq 'Name').Value
                                Size        = $('{0:N0} GB' -f ($Snapshot.BackupSizeInBytes/1GB))
                                Created     = $Snapshot.CreationDate
                                ResourceArn = $Snapshot.ResourceArn
                                RcrPointArn = $Snapshot.RecoveryPointArn
                                BackupPlan  = $($SnapshotTags.GetEnumerator() | Where-Object Key -eq 'Backup Plan').Value
                            }
                            $Snapshot_Report.Add($SnapshotInfo) | Out-Null
                        }
                    }
                }

            } # end foreach Vault

        } # end foreach Region

    } # end foreach Account

    return $Snapshot_Report