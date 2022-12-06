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
        [Parameter(Mandatory=$True)]
            [string]$ObjectId
        ,[Parameter(Mandatory=$False)]
            [switch]$Instance
        ,[Parameter(Mandatory=$False)]
            [string]$SourceRegion = 'us-west-2'
        ,[Parameter(Mandatory=$False)]
            [string]$SourceAccount = '138467534619'
        ,[Parameter(Mandatory=$False)]
            [string[]]$AccountID  = @('138467534619','427878221502','761649062394')
        ,[Parameter(Mandatory=$false)]
            [string[]]$RegionList = @('us-west-1','us-west-2','us-east-1','us-east-2')
    )

    $Snapshot_Report = [System.Collections.ArrayList]::New()
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
        foreach ($Region in $RegionList) {
            Write-Host "Searching for Vaults in region [$Region]"
            $BackupVaultCheck = Get-BAKBackupVaultList -Region $Region
            foreach ($Vault in $BackupVaultCheck) {
                $BackupVaultName    = $Vault.BackupVaultName
                $Num_RecoveryPoints = $Vault.NumberOfRecoveryPoints
                Write-Host " ${BackupVaultName}: " -ForegroundColor Cyan -NoNewline; Write-Host "$Num_RecoveryPoints objects"
                if ($Num_RecoveryPoints -eq 0) {
                    continue
                }
                else {
                    Write-Host "   looking for snapshots in AWS Backup" -NoNewline
                    $ObjResourceArn = "arn:aws:ec2:${SourceRegion}:${SourceAccount}:volume/${ObjectId}"
                    if ($instance) {
                        $ObjResourceArn = "arn:aws:ec2:${SourceRegion}:${SourceAccount}:instance/${ObjectId}"
                    }
                    try {
                        $VaultSnapshots = Get-BAKRecoveryPointsByBackupVaultList -BackupVaultName $BackupVaultName -ByResourceArn $ObjResourceArn -Region $Region -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Host ", none found" -ForegroundColor Yellow
                        continue
                    }
                    if ($VaultSnapshots) {
                        Write-Host ", $(($VaultSnapshots | Measure-Object).Count) discovered" -ForegroundColor Yellow
                        foreach ($Snapshot in $VaultSnapshots) {
                            $SnapshotTags = Get-BAKResourceTag -Region $Region -ResourceArn $Snapshot.RecoveryPointArn
                            $SnapshotInfo = [PSCustomObject]@{
                                VaultAccount= $ID
                                VaultRegion = $Region
                                Vault       = $BackupVaultName
                                Volume      = $($SnapshotTags.GetEnumerator() | Where-Object Key -eq 'Name').Value
                                'Size (GB)' = $('{0:N0}' -f ($Snapshot.BackupSizeInBytes/1GB))
                                Created     = $Snapshot.CreationDate
                                ResourceArn = $Snapshot.ResourceArn
                                RcrPointArn = $Snapshot.RecoveryPointArn
                                BackupPlan  = $($SnapshotTags.GetEnumerator() | Where-Object Key -eq 'Backup Plan').Value
                            }
                            $Snapshot_Report.Add($SnapshotInfo) | Out-Null
                        }
                    }
                    else {
                        Write-Host ", none found" -ForegroundColor Yellow
                    }
                }

            } # end foreach Vault

            Write-Host "Searching for Snapshots in region [$Region]" -NoNewline
            $Vol_Snapshots = Get-EC2Snapshots -Filter @(@{name='volume-id';values=$ObjectId}) -Region $Region
            if ($Vol_Snapshots) {
                Write-Host ", $(($Vol_Snapshots | Measure-Object).Count) discovered" -ForegroundColor Yellow
                foreach ($Snapshot in $Vol_Snapshots) {
                    $SnapshotInfo = [PSCustomObject]@{
                        VaultAccount= $ID
                        VaultRegion = $Region
                        Vault       = 'n/a'
                        Volume      = $($Snapshot.Tags.GetEnumerator() | Where-Object Key -eq 'Name').Value
                        'Size (GB)' = $('{0:N0}' -f ($Snapshot.VolumeSize))
                        Created     = $Snapshot.StartTime
                        ResourceArn = $Snapshot.SnapshotId
                        RcrPointArn = 'n/a'
                        BackupPlan  = $($Snapshot.Tags.GetEnumerator() | Where-Object Key -eq 'Backup Frequency').Value
                    }
                    $Snapshot_Report.Add($SnapshotInfo) | Out-Null                    
                }
            }
            else {
                Write-Host ", none found" -ForegroundColor Yellow
            }

        } # end foreach Region

    } # end foreach Account

    return $Snapshot_Report