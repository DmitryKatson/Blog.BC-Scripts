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

    New-BCCloudSandBox -url $url -authHeaderDA $authHeaderDA -sandboxName $sandboxName -nextVersion:$true

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

function Get-BCCloudEnvironments {
    param (
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        $authHeaderDA,
        $envName
    )

    $req = $url +  '/v1.2/admin/applications/BusinessCentral/environments/' + $envName
    $result = Invoke-WebRequest `
                                -Uri   $req `
                                -Headers @{Authorization=$authHeaderDA} `
                                -Method Get 

    $result.Content   
}


function Get-BCCloudAvailableVersions{
    param (
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        $authHeaderDA
    )

    $req = $url +  '/v1.2/admin/applications/BusinessCentral/rings/'
    $result = Invoke-WebRequest `
                                -Uri   $req `
                                -Headers @{Authorization=$authHeaderDA} `
                                -Method Get 

    $result.Content
}


function Get-BCCloudAvailablePreviewVersion{
    param (
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        $authHeaderDA
    )

    $supportedVersions = Get-BCCloudAvailableVersions -url $url -authHeaderDA $authHeaderDA | ConvertFrom-Json
    $appVersion = $supportedVersions.value | where { $_.ringFriendlyName -eq "Preview" } | Select -ExpandProperty "applicationVersion"
    $major = $appVersion.major
    $minor = $appVersion.minor
    $build = $appVersion.build
    $revision = $appVersion.revision
     
    return ("$major.$minor.$build.$revision")
<#  
    #There where problems in API when appVersion returned in flat format 
    $major = $appVersion |
    Select-String '(?<=major=)\d+' |
    Select-Object -Expand Matches |
    Select-Object -Expand Value

    $minor =$appVersion |
    Select-String '(?<=minor=)\d+' |
    Select-Object -Expand Matches |
    Select-Object -Expand Value

    $build = $appVersion |
    Select-String '(?<=build=)\d+' |
    Select-Object -Expand Matches |
    Select-Object -Expand Value

    $revision = $appVersion |
    Select-String '(?<=revision=)\d+' |
    Select-Object -Expand Matches |
    Select-Object -Expand Value

    return ("$major.$minor.$build.$revision") 
#>
}

function New-BCCloudSandBox {
    param (
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        $authHeaderDA,
        [Parameter(Mandatory=$true)]
        [string] $sandboxName,
        [switch] $nextVersion
    )

    if (! $nextVersion) {
        $req = $url +  "/v1.2/admin/applications/BusinessCentral/environments/$sandboxName"
    } else {
        $appVersion = Get-BCCloudAvailablePreviewVersion -url $url -authHeaderDA $authHeaderDA
        $req = $url +  "/v1.2/admin/applications/BusinessCentral/environments/$sandboxName/$appVersion/PREVIEW"
    }

    Write-Host "Creating new Sandbox..."          

    $JSON = @'
    {
        "type": "Sandbox"
    }
'@

     try {
       $result = Invoke-WebRequest `
            -Uri   $req `
            -Headers @{Authorization=$authHeaderDA} `
            -Method PUT `
            -Body $JSON -ContentType "application/json"
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
    }

    $sandboxStatus = Get-BCCloudSandBoxStatus -url $url -authHeaderDA $authHeaderDA -sandboxName $sandboxName
    
    if (($status -eq '400') -and ($sandboxStatus -ne "Preparing"))
    {
        Write-Host -ForegroundColor Red "Sandbox already exists"
        return
    }
    
    # Wait until Sandbox is ready
    Wait-BCCloudSandBoxReady -url $url -authHeaderDA $authHeaderDA -sandboxName $sandboxName
 
}

function Get-BCCloudSandBoxStatus {
    param (
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        $authHeaderDA,
        [Parameter(Mandatory=$true)]
        [string] $sandboxName
    )
    
    try{
        $result = Get-BCCloudEnvironments -url $url -authHeaderDA $authHeaderDA -envName $sandboxName
        if ($result) {$currStatus = $result  | ConvertFrom-Json |select status}
        return ($currStatus.status)
    } catch {
        $currStatus = $_.Exception.Response.StatusCode
        return ($currStatus)
    }    
}

function Wait-BCCloudSandBoxReady {
    param (
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        $authHeaderDA,
        [Parameter(Mandatory=$true)]
        [string] $sandboxName
    )

    $status = Get-BCCloudSandBoxStatus -url $url -authHeaderDA $authHeaderDA -sandboxName $sandboxName
    if ($status -eq "NotFound")
    {
        Write-Host -ForegroundColor Red "Sandbox is not found"
        return
    } 
    if ($status -eq "Removing")
    {
        Write-Host -ForegroundColor Yellow "Sandbox is removing"
        return
    }
    if ($status -eq "Unauthorized")
    {
        return
    }
    while (($status -ne "Active") -and ($status -ne "NotFound"))
    {
        $wait = 30
        $status = Get-BCCloudSandBoxStatus -url $url -authHeaderDA $authHeaderDA -sandboxName $sandboxName
        if (($status -ne "Active") -and ($status -ne "NotFound"))
        {
            Write-Host -ForegroundColor Yellow "Sandbox is cooking. Current status is" $status ". Next try in $wait sec"
            Start-Sleep -Seconds $wait    
        }
    }
    
    Write-Host -ForegroundColor Green "Sandbox is " $status            
    
}


# --------------------------------------Prerequisites-------------------------------------

Install-Package Azure -Force
Install-Module AzureAD -Force

# --------------------------------------Initialize-------------------------------------

$url ='https://api.businesscentral.dynamics.com'
$appId = "" #">>YOUR APP ID<<"
$DAemail = "admin.prem@airappsbctestus.onmicrosoft.com"
$DApassword = ''
$tenantdomain = "airappsbctestus.onmicrosoft.com"
$sandboxName = 'My-Wave2-Sandbox'
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

        