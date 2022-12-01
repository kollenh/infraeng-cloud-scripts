    <#
    .SYNOPSIS
        Remove one or more snapshots from an AWS Backup Vault

    .DESCRIPTION
        
    .PARAMETER AccountId
        The AWS account ID that will be polled for information

    .PARAMETER AccountName
        The AWS account name that will be polled for information

    .PARAMETER BackupVault
        Name of the AWS backup vault that holds all the DR backups

    .PARAMETER VaultRegion
        The AWS regions that will be checked for protected systems

    .PARAMETER VolumeId
        ID of the volume from which the snapshots were taken; all associated snapshots will be returned

    .PARAMETER SnapshotId
        ID of the specific snapshot to be removed

    .PARAMETER Test
        Switch to indicate the script should post to a different Teams channel for testing
    
    .EXAMPLE
        Remove-EBSsnapshotFromVault 

    .NOTES

    .Version
        1.0 Initial script created by Kollen Hensley, Slalom 	[12/01/2022]
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
            [string]$AccountId
        ,[Parameter(Mandatory=$false)]
            [string]$AccountName
        ,[Parameter(Mandatory=$true)]
            [string]$BackupVault
        ,[Parameter(Mandatory=$false)]
            [string]$VolumeId
        ,[Parameter(Mandatory=$false)]
            [string]$SnapshotId
        ,[Parameter(Mandatory=$False)]
            [string]$SourceRegion = 'us-west-2'
        ,[Parameter(Mandatory=$false)]
            [string]$VaultRegion = 'us-east-2'
        ,[Parameter(Mandatory=$false)]
            [switch]$Test
    )

    if ($AccountName) {
        Switch ($AccountName) {
            'IT-Prod'        {
                # this is the "new" Infrastructure account
                $AccountId = '427878221502'
            }
            'DR-Backup'      {
                $AccountId = '761649062394'
            }
            default          {
                # this is the "legacy" Infrastructure account
                $AccountId = '138467534619' 
            }
        }
    }

    # **We need a way to specify & test credentials**

    # Check the provided information contains recovery data
    $BackupVaultCheck = Get-BAKBackupVaultList -Region $VaultRegion | Where-Object BackupVaultName -eq $BackupVault
    if (-not $BackupVaultCheck) {
        Throw "'$BackupVault' was not located in '$VaultRegion', please check the information and try again"
        return
    }
    if ($BackupVaultCheck.NumberOfRecoveryPoints -eq 0) {
        Throw "There were no recovery points located in '$BackupVault', please check the information and try again"
        return
    }

    
    # Build string values from the parameters
    if ($SnapshotId) {
        $ObjResourceArn = "arn:aws:ec2:${VaultRegion}::snapshot/${SnapshotId}"
    }
    else{
        $ObjResourceArn = "arn:aws:ec2:${SourceRegion}:${AccountId}:volume/${VolumeId}"
    }

    Write-Host "Searching for objects in the $BackupVault vault.."
    $SnapShots = Get-BAKRecoveryPointsByBackupVaultList -BackupVaultName $BackupVault -ByResourceArn $ObjResourceArn
    if (-not $SnapShots) {
        Throw "No snapshots were located with ResourceArn '$ObjResourceArn'"
        return
    }
    Write-Host "$(($SnapShots | Measure-Object).Count) objects were found"

    foreach ($obj in $SnapShots) {
        $SnapshotTags = Get-BAKResourceTag -Region $AWSRegion -ResourceArn $obj.RecoveryPointArn
        $obj | Select-Object @{l='VolumeName';e={$($SnapshotTags.GetEnumerator() | Where-Object Key -eq 'Name').Value}},`
                             @{l='Size';e={'{0:N0} GB' -f ($obj.BackupSizeInBytes/1GB)}},`
                             CreationDate,`
                             ResourceArn,`
                             RecoveryPointArn,`
                             @{l='BackupPlan';e={$($SnapshotTags.GetEnumerator() | Where-Object Key -eq 'Backup Plan').Value}}
        #Remove-BAKRecoveryPoint -RecoveryPointArn $obj.RecoveryPointArn -WhatIf
    }
