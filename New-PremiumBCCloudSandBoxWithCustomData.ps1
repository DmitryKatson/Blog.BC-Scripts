# --------------------------------------Functions-------------------------------------

function New-PremiumBCCloudSandBoxWithCustomData {
    param 
    (
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        [string] $appId,
        [Parameter(Mandatory=$true)]
        [string] $DAemail,
        [string] $DApassword,
        [Parameter(Mandatory=$true)]
        [string] $tenantdomain,
        [Parameter(Mandatory=$true)]
        [string] $sandboxName,
        [Parameter(Mandatory=$true)]
        [string] $companyName

    )

    $startTime=(Get-Date);
    Clear-Host

    # Connect to admin Center
    $authHeaderDA = GetAuthHeader -DAemail $DAemail -DApassword $DApassword -tenantdomain $tenantdomain -appId $appId

    Write-Host $authHeaderDA

    $Elapsed = (Get-Date)-$startTime;

}

function GetAuthHeader
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true)]
        [string] $DAemail,
        [string] $DApassword,
        [Parameter(Mandatory=$true)]
        [string] $tenantdomain,
        [Parameter(Mandatory=$true)]
        [string] $appId
    )

    Write-Host "Checking for AzureAD module..."
    if (!$CredPrompt){$CredPrompt = 'Auto'}
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    if ($AadModule -eq $null) {$AadModule = Get-Module -Name "AzureADPreview" -ListAvailable}
    if ($AadModule -eq $null) {write-host "AzureAD Powershell module is not installed. The module can be installed by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt. Stopping." -f Yellow;exit}
    if ($AadModule.count -gt 1) {
        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]
        $aadModule      = $AadModule | ? { $_.version -eq $Latest_Version.version }
        $adal           = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms      = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
        }
    else {
        $adal           = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms      = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
        }
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

    if ($DApassword) {
    
        $cred = [Microsoft.IdentityModel.Clients.ActiveDirectory.UserPasswordCredential]::new($DAemail, $DApassword)
        $ctx  = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new("https://login.windows.net/$tenantdomain")
        $token = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($ctx, "https://api.businesscentral.dynamics.com", $appId, $cred).GetAwaiter().GetResult().AccessToken

        if ($token) { Write-Host -ForegroundColor Green "Successfully connected to Cloud Business Central"}
        if (!$token) { Write-Host -ForegroundColor Red "Connection to Cloud Business Central failed"}

        return "Bearer $($token)"

    } 
    else {
  
        $authority = "https://login.windows.net"
        $resource    = "https://projectmadeira.com"    
        $clientRedirectUri = [uri]"BusinessCentralWebServiceClient://auth"     

        $authenticationContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext -ArgumentList "$authority/$tenantdomain"
        $platformParameters = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters -ArgumentList ([Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Always)
        $userIdentifier = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier -ArgumentList ($DAemail, [Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifierType]::RequiredDisplayableId)
        $authenticationResult = $authenticationContext.AcquireTokenAsync($resource, $appId, $clientRedirectUri, $platformParameters, $userIdentifier).GetAwaiter().GetResult()
    
        if ($authenticationResult.AccessToken) { Write-Host -ForegroundColor Green "Successfully connected to Cloud Business Central"}
        if (!$authenticationResult.AccessToken) { Write-Host -ForegroundColor Red "Connection to Cloud Business Central failed"}
    
        return "$($authenticationResult.AccessTokenType) $($authenticationResult.AccessToken)" 
    }    
} 

# --------------------------------------Prerequisites-------------------------------------

Install-Package Azure -Force
Install-Module AzureAD -Force

# --------------------------------------Initialize-------------------------------------

$url ='https://api.businesscentral.dynamics.com'
$appId = "581e2ea2-008e-44e9-8ec0-9e5d40540b27" #">>YOUR APP ID<<"
$DAemail = "admin.prem@airappsbctestus.onmicrosoft.com"
$DApassword = ''
$tenantdomain = "airappsbctestus.onmicrosoft.com"
$sandboxName = 'Sandbox-AirApps'
$companyName = 'AirApps'

# --------------------------------------Main Function-------------------------------------

New-PremiumBCCloudSandBoxWithCustomData `
        -url $url `
        -appId $appId `
        -DAemail $DAemail `
        -DApassword $DApassword `
        -tenantdomain $tenantdomain `
        -sandboxName $sandboxName `
        -companyName $companyName

        