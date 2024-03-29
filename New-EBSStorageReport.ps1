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
            [string[]]$AccountID  = @('138467534619','252302356329','427878221502')
        ,[Parameter(Mandatory=$false)]
            [string[]]$RegionList = @('us-west-1','us-west-2','us-east-1','us-east-2','eu-west-1')

    )

    # Get all snapshots in the DR vault
    Initialize-AWSDefaultconfiguration -ProfileName 'DRVault'
    Write-Host "`nGetting all snapshots from the DR vault" -NoNewline
    $All_DR_Snapshots = Get-BAKRecoveryPointsByBackupVaultList -BackupVaultName 'slawsitprodbackup-us-east-2-backup-vault' | `
        Sort-Object ResourceArn,CompletionDate -Descending 
    Write-Host ", found $(($All_DR_Snapshots | Measure-Object).Count)" -ForegroundColor Yellow

    foreach ($ID in $AccountID) {
        try {
            # [below is temp, replace in production script]
            Switch ($ID) {
                '427878221502'        {
                    # "new" infrastructure account
                    $ProfileName = 'InfraProd'
                }
                '761649062394'      {
                    # DR/backup account
                    $ProfileName = 'DRVault'
                }
                '252302356329' {
                    # InfoSec account
                    $ProfileName = 'SecOps'
                }
                default          {
                    # "legacy" infrastructure account
                    $ProfileName = 'MyDefault' 
                }
            }
            Write-Host "Using profile" -nonewline; Write-Host " $ProfileName " -ForegroundColor Cyan -NoNewline; Write-Host "for connection to account $ID"
            Initialize-AWSDefaultconfiguration -ProfileName $ProfileName
        }
        catch {
            throw "Unable to connect to the account"
            return
        }

        $Volume_Report = [System.Collections.ArrayList]::New()

        # Build array of AWS Backup vaults that contain objects
        $Backup_Vaults = [System.Collections.ArrayList]::New()
        foreach ($Region in $RegionList) {
            Write-Host "Searching [$Region] for Backup vaults with recovery points"
            $BackupVaults = Get-BAKBackupVaultList -Region $Region
            foreach ($Vault in $BackupVaults) {
                if ($Vault.NumberOfRecoveryPoints -gt 0) {
                    $Vault_Data = [PSCustomObject]@{
                        VaultName   = $Vault.BackupVaultName
                        VaultRegion = $Region
                    }
                    $Backup_Vaults.Add($Vault_Data) | Out-Null
                }
            }
        }

        # Loop through each region and get all EBS volumes
        foreach ($Region in $RegionList) {
            Write-Host "Searching [$Region] for volumes:"
            Get-EC2Volume -Region $Region | ForEach-Object {
                $Vol_Id      = $_.VolumeId
                $Vol_Tags    = $_.Tags

                Write-Host " Discovered volume [$Vol_Id]"
                
                #find any associated snapshots
                $filter_by_volumeid = @(@{name='volume-id';values=$Vol_Id})
                Write-Host "  >looking for associated snapshots" -NoNewline
                $Snapshots = Get-EC2Snapshots -Filter $filter_by_volumeid -Region $Region
                if ($Snapshots) {
                    $Snapshot_Count = ($Snapshots | Measure-Object).Count
                    $Snapshot_Tags  = ($Snapshots | Sort-Object StartTime -Descending | Select-Object -First 1).Tags
                    $Backup_Plan    = ($Snapshot_Tags.GetEnumerator() | Where-Object Key -eq 'Backup Plan').Value
                }
                else {
                    $Snapshot_Count = 0
                }
                Write-Host ", found $Snapshot_Count" -ForegroundColor Yellow

                #look for snapshots in a Backup Vault
                $VaultSnapshotTotal = 0
                foreach ($VaultObj in $Backup_Vaults) {
                    Write-Host "  >looking in " -nonewline; write-host "$($VaultObj.VaultName)" -NoNewline -ForegroundColor Cyan; write-host " vault" -NoNewline
                    $ObjResourceArn = "arn:aws:ec2:${Region}:${ID}:volume/${Vol_Id}"
                    try {
                        $VaultSnapShots     = Get-BAKRecoveryPointsByBackupVaultList -BackupVaultName $($VaultObj.VaultName) -ByResourceArn $ObjResourceArn -Region $($VaultObj.VaultRegion) -ErrorAction SilentlyContinue
                        $VaultSnapshotCount = ($VaultSnapShots | Measure-Object).Count
                    }
                    catch {
                        $VaultSnapshotCount = 0
                        #continue
                    }
                    Write-Host ", found $VaultSnapshotCount" -ForegroundColor Yellow
                    $VaultSnapshotTotal = $VaultSnapshotTotal + $VaultSnapshotCount
                } #end foreach Vault

                #look for snapshots in the DR Vault
                Write-Host "  >searching for snapshots in slawsitprodbackup-us-east-2-backup-vault vault" -NoNewline
                $DR_VaultSnapshots = $All_DR_Snapshots | Where-Object ResourceArn -eq $ObjResourceArn
                $DR_Vault_Count    = ($DR_VaultSnapshots | Measure-Object).Count
                Write-Host ", found $DR_Vault_Count`n" -ForegroundColor yellow

                $Volume_Info = [PSCustomObject]@{
                    Account     = $ID
                    Zone        = $_.AvailabilityZone
                    VolumeId    = $Vol_Id 
                    Name        = $($Vol_Tags.GetEnumerator() | Where-Object Key -eq 'Name').Value
                    'Size(GB)'  = $('{0:N0}' -f ($_.Size))
                    Type        = $_.VolumeType
                    State       = $_.State
                    Created     = $_.CreateTime
                    Frequency   = $($Vol_Tags.GetEnumerator() | Where-Object Key -eq 'Backup Frequency').Value
                    Snapshots   = $Snapshot_Count
                    BackupPlan  = $Backup_Plan
                    LocalVault  = $VaultSnapshotTotal
                    DRVault     = $DR_Vault_Count
                }

                #Append volume information to report
                $Volume_Report.Add($Volume_Info) | Out-Null

            } #end foreach Volume
        
        } #end foreach Region
        
    } #end foreach Account
    
    return $Volume_Report