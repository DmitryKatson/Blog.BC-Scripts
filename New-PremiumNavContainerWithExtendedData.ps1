
function New-PremiumNavContainerWithExtendedData {
    Param(
        [switch]$accept_eula,
        [string]$containerName, 
        [string]$imageName = "", 
        [string]$licenseFile = "",
        [System.Management.Automation.PSCredential]$Credential = $null,
        [string]$customConfigPackageFile = ""
    )

    $startTime=(Get-Date);

    Clear-Host
    Write-Host "Start creation of $containerName"
    New-NavContainer -accept_eula:$accept_eula `
                 -containername $containername `
                 -auth NavUserPassword `
                 -Credential $credential `
                 -includeCSide `
                 -doNotExportObjectsToText `
                 -usessl:$false `
                 -updateHosts `
                 -assignPremiumPlan `
                 -shortcuts Desktop `
                 -imageName $navdockerimage `
                 -licenseFile $licenseFile `
                 -additionalParameters $additionalParameters `
                 -alwaysPull

    Setup-NavContainerTestUsers -containerName $containername -password $password

    Switch-NavContainerToPremiumMode -containerName $containername 

    ImportAndApply-ConfigPackageInNavContainer -containerName $containername -configPackageType:Premium 

    #ImportAndApply-ConfigPackageInNavContainer -containerName $containername -configPackageType:Custom -customConfigPackageFile $customConfigPackageFile
      
    $Elapsed = (Get-Date)-$startTime;
    Write-Host "Creation of $containerName is finished. It took " $Elapsed.TotalMinutes " minutes"
}

function Switch-NavContainerToPremiumMode {
    param (
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [System.Management.Automation.PSCredential]$sqlCredential = $null
    )

    $fobfile = Join-Path $env:TEMP "SetPremiumExperience.fob"
    Download-File -sourceUrl "http://bit.ly/bcsetpremiumexpfob" -destinationFile $fobfile
    Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $sqlCredential
    Start-Sleep -Seconds 5
    Invoke-NavContainerCodeunit -containerName $containerName -tenant $tenant -CodeunitId 60000 -MethodName SetPremiumExperience
    Write-Host -ForegroundColor green "Business Central UI is switched to Premium mode"
}

function ImportAndApply-ConfigPackageInNavContainer {
    param (
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",

        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",

        [Parameter(Mandatory=$false)]
        [ValidateSet('Premium','Custom')]
        [string]$configPackageType = "Premium",

        [Parameter(Mandatory=$false)]
        [string]$customConfigPackageFile    
        )
    
        if ($configPackageType -eq "Custom" -and !$customConfigPackageFile) {
            throw "Specify configuration package file"
        }

        # Import fob to run Import And Apply Conf Package File    
        $fobfile = Join-Path $env:TEMP "ImportAndApplyRapidStartPackage.fob"
        Download-File -sourceUrl "http://bit.ly/bcimportapplyconfpackfob" -destinationFile $fobfile
        Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $sqlCredential 
        Start-Sleep -Seconds 5
        
        # Find Cronus Company
        $CronusCompany = Get-CompanyInNavContainer -containerName $containerName | Where { $_.CompanyName -like ‘CRONUS*’ -and $_.EvaluationCompany -eq "true"} | Select-Object -First 1
        
        if ($configPackageType -eq "Premium")
        {

            # Get Extended Conf Package File from Container  
            $containerConfigPackageFilePath = Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { 
                #Try to find Extended Configuration Package
                $originalFile = Get-Childitem –Path C:\ConfigurationPackages\*.EXTENDED.rapidstart | Select-Object -First 1 
                Copy-Item $originalFile.fullName -Destination $env:TEMP
                return Join-Path $env:TEMP $originalFile.Name
            } 
            if ($containerConfigPackageFilePath -eq "") {
                throw "Extended configuration package was not found"
            }                

            # Import and apply Conf Package File    
            Write-Host "Importing and applying configuration package from $containerConfigPackageFilePath (container path)" 
            Invoke-NavContainerCodeunit -containerName $containerName -tenant $tenant -CompanyName $CronusCompany.CompanyName -CodeunitId 60000 -MethodName ImportAndApplyRapidStartPackage -Argument $containerConfigPackageFilePath    
            Write-Host -ForegroundColor Green "Configuration package imported and applied"

        }

        if ($configPackageType -eq "Custom")
        {
            if ($customConfigPackageFile.StartsWith("http://", [StringComparison]::OrdinalIgnoreCase) -or $customConfigPackageFile.StartsWith("https://", [StringComparison]::OrdinalIgnoreCase)) {

                $tempFileName = "CustomConfigurationPackage.rapidstart"
                $localConfigPackageFilePath = Join-Path $env:TEMP $tempFileName
                $containerConfigPackageFilePath = Join-Path "C:\" $tempFileName
                Write-Host "Downloading file from $customConfigPackageFile"
                Download-File -sourceUrl $customConfigPackageFile -destinationFile $localConfigPackageFilePath 
                        
            } else {
                $tempFileName = "CustomConfigurationPackage.rapidstart"
                $localConfigPackageFilePath = $customConfigPackageFile
                $containerConfigPackageFilePath = Join-Path "C:\" $tempFileName
            }

            Copy-FileToNavContainer -containerName $containerName -localPath $localConfigPackageFilePath -containerPath $containerConfigPackageFilePath
            Write-Host "Importing and applying custom configuration package" 
            Invoke-NavContainerCodeunit -containerName $containerName -tenant $tenant -CompanyName $CronusCompany.CompanyName -CodeunitId 60000 -MethodName ImportAndApplyRapidStartPackage -Argument $containerConfigPackageFilePath    
            Write-Host -ForegroundColor Green "$configPackageType configuration package imported and applied"
        }
}


install-module navcontainerhelper -force

$accept_eula = $true
$containername = 'BC-Prem-Ext'
$navdockerimage = 'mcr.microsoft.com/businesscentral/sandbox:ca'

$username = 'admin'
$password = ConvertTo-SecureString "admin" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $password)
$licenseFile = 'C:\ProgramData\NavContainerHelper\License\license.flf'

New-PremiumNavContainerWithExtendedData -accept_eula:$accept_eula `
                    -containername $containername `
                    -Credential $credential `
                    -imageName $navdockerimage `
                    -licenseFile $licenseFile
