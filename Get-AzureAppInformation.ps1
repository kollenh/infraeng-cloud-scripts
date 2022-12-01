

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False)]
        [string]$TenantId = '9ca75128-a244-4596-877b-f24828e476e2'
)

Connect-AzAccount -Tenant $TenantId | Out-Null

$AzureAppdata = [System.Collections.ArrayList]::New()
Get-AzSubscription | foreach-object {
    $Subscription_Name = $_.Name
    $Subscription_Id   = $_.Id

    Write-Host "Checking $Subscription_Name"
    Select-AzSubscription $Subscription_Name | Out-Null
    Get-AzWebApp | foreach-object {
        $Subscription_WebAppName = $_.Name
        $WebApp_ResourceGroup    = $_.ResourceGroup

        Write-Host " ..looking at $Subscription_WebAppName"
        $WebApp_SslInformation   = Get-AzWebAppSSLBinding -ResourceGroupName $WebApp_ResourceGroup -WebAppName $Subscription_WebAppName
        foreach ($binding in $WebApp_SslInformation) {
            $obj = [PSCustomObject]@{
                SubscriptionId = $Subscription_Id
                Subscription   = $Subscription_Name
                ResourceGroup  = $WebApp_ResourceGroup
                WebApp         = $Subscription_WebAppName
                WebAppHostName = ($binding).Name
                WebAppSslState = ($binding).SslState
                WebAppCert     = ($binding).Thumbprint
            }
            $AzureAppdata.Add($obj) | Out-Null    
        }

        #Write-Output $obj
    }
}

return $AzureAppdata