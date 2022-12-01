[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
		[string]$OldCertThumbprint
    ,[Parameter(Mandatory=$True)]
        [string]$CertFilePath
    ,[Parameter(Mandatory=$True)]
        [SecureString]$PFXpass
    ,[Parameter(Mandatory=$False)]
        [string]$TenantId = '9ca75128-a244-4596-877b-f24828e476e2'
)

# Convert PFX secure string to regular string
$Passphrase = (New-Object PSCredential 0, $PFXpass).GetNetworkCredential().Password

#Connect to Azure
Connect-AzAccount -Tenant $TenantId | Out-Null

$AzureAppdata = [System.Collections.ArrayList]::New()
Get-AzSubscription | foreach-object {
    $Subscription_Name = $_.Name
    $Subscription_Id   = $_.Id

    Write-Host "Opening subscription $Subscription_Name"
    Select-AzSubscription $Subscription_Name | Out-Null
    Get-AzWebApp | foreach-object {
        $Subscription_WebAppName = $_.Name
        $WebApp_ResourceGroup    = $_.ResourceGroup

        Write-Host " ..checking $Subscription_WebAppName"
        $WebApp_SslInformation   = Get-AzWebAppSSLBinding -ResourceGroupName $WebApp_ResourceGroup -WebAppName $Subscription_WebAppName
        foreach ($binding in $WebApp_SslInformation) {
			$WebAppHostName 		= ($binding).Name
			$Certificate_Thumbprint = ($binding).Thumbprint
			#Write-Host "   certificate: $Certificate_Thumbprint"

			if ($Certificate_Thumbprint -eq $OldCertThumbprint) {
				Write-Host "   Updating $WebAppHostName with new cert" -ForegroundColor Yellow
				New-AzWebAppSSLBinding -ResourceGroupName $WebApp_ResourceGroup `
					-WebAppName $Subscription_WebAppName `
					-CertificateFilePath $CertFilePath `
					-CertificatePassword $Passphrase `
					-Name $WebAppHostName `
					| Out-Null

				$NewWebAppBinding = Get-AzWebAppSSLBinding -ResourceGroupName $WebApp_ResourceGroup -WebAppName $Subscription_WebAppName -Name $WebAppHostName
				$Certificate_Thumbprint = $NewWebAppBinding.Thumbprint
			}
			else {
				Write-Host "   Existing certificate is not in scope" -ForegroundColor Cyan
			}
            $obj = [PSCustomObject]@{
                SubscriptionId = $Subscription_Id
                Subscription   = $Subscription_Name
                ResourceGroup  = $WebApp_ResourceGroup
                WebApp         = $Subscription_WebAppName
                WebAppHostName = $WebAppHostName
                WebAppSslState = ($binding).SslState
                WebAppCert     = $Certificate_Thumbprint

            }
            $AzureAppdata.Add($obj) | Out-Null    
        }
    }
}
return $AzureAppdata

#AzureWebSites
Select-AzSubscription "Slalom-IT-EPP-Prod"
New-AzWebAppSSLBinding -ResourceGroupName "SlalomProfileBuilderWebResourceGroup" `
	-WebAppName "SlalomProfileBuilderWeb" 	
	-CertificateFilePath $CertFilePath `
	-CertificatePassword $Passphrase `
	-Name "profiles.slalom.com"
New-AzWebAppSSLBinding -ResourceGroupName "SlalomProfileBuilderWeb-Qa" `
	-WebAppName "SlalomProfileBuilderWeb-Qa" `
	-CertificateFilePath $CertFilePath `
	-CertificatePassword $Passphrase `
	-Name "testprofiles.slalom.com"

	
Select-AzSubscription "Slalom-IT-MyTime-Prod"
	New-AzWebAppSSLBinding -ResourceGroupName "MyTime-Prod-Resources" -WebAppName "mytime-production" -CertificateFilePath $CertFilePath -CertificatePassword $Passphrase -Name "mytime-ssl.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "MyTime-Prod-Resources" -WebAppName "mytime-production" -NewCertThumbprint $NewCertThumbprint -Name "mytime.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "MyTime-Prod-Resources" -WebAppName "mytime-insiders"   -NewCertThumbprint $NewCertThumbprint -Name "mytime-insiders.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "MyTime-Test-Resources" -WebAppName "mytime-develop"    -NewCertThumbprint $NewCertThumbprint -Name "devmytime.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "MyTime-Test-Resources" -WebAppName "mytime-test"       -NewCertThumbprint $NewCertThumbprint -Name "testmytime.slalom.com"

Select-AzSubscription "Slalom-IT-SlalomER-Prod"
	New-AzWebAppSSLBinding -ResourceGroupName "SlalomER" -WebAppName "slalom-er-prod" -CertificateFilePath $CertFilePath -CertificatePassword $Passphrase -Name "er.slalom.com"

Select-AzSubscription "Slalom-IT-SlalomMobileApps-Prod"
	New-AzWebAppSSLBinding -ResourceGroupName "Default-Web-WestUS" -WebAppName "SlalomApps" -CertificateFilePath $CertFilePath -CertificatePassword $Passphrase -Name "apps.slalom.com"

Select-AzSubscription "Slalom-IT-InvestorPortal-Prod"
	New-AzWebAppSSLBinding -ResourceGroupName "SlalomInvestorPortal" -WebAppName "slalominvestorportal" -CertificateFilePath $CertFilePath -CertificatePassword $Passphrase -Name "investor.slalom.com"


Select-AzSubscription "Brad Projects"
	New-AzWebAppSSLBinding -ResourceGroupName "BasicDemoResourceGroup" -WebAppName "slalomvotestage" -CertificateFilePath $CertFilePath -CertificatePassword $Passphrase -Name "sdlstage.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "BasicDemoResourceGroup" -WebAppName "SlalomValues" -NewCertThumbprint $NewCertThumbprint -Name "values.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "BasicDemoResourceGroup" -WebAppName "SlalomValues" -NewCertThumbprint $NewCertThumbprint -Name "vote.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "BasicDemoResourceGroup" -WebAppName "SlalomValues" -NewCertThumbprint $NewCertThumbprint -Name "decisionlab.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "BasicDemoResourceGroup" -WebAppName "SlalomValues" -NewCertThumbprint $NewCertThumbprint -Name "dlab.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "BasicDemoResourceGroup" -WebAppName "SlalomValues" -NewCertThumbprint $NewCertThumbprint -Name "sdl.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "BasicDemoResourceGroup" -WebAppName "SlalomValues" -NewCertThumbprint $NewCertThumbprint -Name "executivebookclub.slalom.com"
	New-AzWebAppSSLBinding -ResourceGroupName "BasicDemoResourceGroup" -WebAppName "SlalomValues" -NewCertThumbprint $NewCertThumbprint -Name "storyboard.slalom.com"
