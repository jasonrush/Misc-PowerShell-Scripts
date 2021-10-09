# Configuration Variables.

# Base URL for Labtech server (ie 'https://contoso.hostedrmm.com')
$url = "https://contoso.hostedrmm.com";

# File name to use for local copy of installer
$file = 'LT_Agent.msi'

# Prompt for user credentials.
$credentials = Get-Credential -Message "Enter Connectwise Automate credentials"

# Log in, and get API token.
$loginPage= "$url/cwa/api/v1/apitoken"
Write-Verbose "Using login page '$loginPage'"
$headers = @{
    'Accept'='application/json, text/plain, */*'
}

$plaintextPassword = $credentials.GetnetworkCredential().Password
$payload = @{
    UserName=$($credentials.UserName)
    Password=$plaintextPassword
    TwoFactorPasscode=''
}
$ApiToken = Invoke-RestMethod -Uri $loginPage -Method POST -Headers $headers -Body ($payload | ConvertTo-Json -Compress) -ContentType "application/json;charset=UTF-8"

# Select client.
$clientsListPage = "$url/cwa/api/v1/clients?pageSize=-1&includeFields='Name'&orderBy=Name asc"
$headers = @{
    "Accept"="application/json, text/plain, */*"
    "Authorization"="bearer $($ApiToken.AccessToken)"
}
$requestResult = Invoke-WebRequest -Method GET -Uri $clientsListPage -Headers $headers
$clients = $requestResult | ConvertFrom-Json

$currentClient = $clients | Out-GridView -OutputMode Single -Title "Select Client"

if( $null -eq $currentClient ){
    Write-Error "No client selected."
    return
}

# Select location.
$locationsListPage = "$url/cwa/api/v1/locations?pageSize=-1&includeFields=Name&orderBy=Name asc"
$headers = @{
    "Accept"="application/json, text/plain, */*"
    "Authorization"="bearer $($ApiToken.AccessToken)"
}
$requestResult = Invoke-WebRequest -Method GET -Uri $locationsListPage -Headers $headers
$locations = $requestResult | ConvertFrom-Json
$locations = $locations | Where-Object { $_.Client.Name -eq $currentClient.Name }

if( $null -eq $locations ){
    Write-Error "No locations found for client $($currentClient.Name)"
    return
}

$currentLocation = $locations | Out-GridView -OutputMode Single -Title "Select Location"

# Prompt for installer type? Or assume EXE or MSI? This may change based on how we install... Note "ID" == location ID.s
# MSI
# Request URL: https://contoso.hostedrmm.com/Labtech/Deployment.aspx?installType=msi&ID=146
# EXE
# Request URL: https://contoso.hostedrmm.com/Labtech/Deployment.aspx?ID=146
# Linux x86
# Request URL: https://contoso.hostedrmm.com/Labtech/Deployment.aspx?LINUX=3&ID=146
# Linux x86_64
# Request URL: https://contoso.hostedrmm.com/Labtech/Deployment.aspx?LINUX=4&ID=146
# Mac
# Request URL: https://contoso.hostedrmm.com/Labtech/Deployment.aspx?installType=mac&ID=146

$link = "$url/Labtech/Deployment.aspx?installType=msi&ID=$($currentLocation.Id)"
$tmp = "$env:TEMP\$file"

Write-Verbose "Downloading Agent (MSI) from"
Write-Verbose "`t$link"
Write-Verbose "to"
Write-Verbose "`t$tmp"
$client = New-Object System.Net.WebClient
$client.Headers['Authorization'] = "bearer $($ApiToken.AccessToken)";
$client.DownloadFile($link, $tmp)
<#
# TODO: This may be better to rework something like: Invoke-WebRequest $url -OutFile 'c:\windows\temp\installer.exe' -UseBasicParsing
This will add a step toward being able to run this on Core installs/etc. I'm not sure if th System.Net.WebClient works w/o IE?
#>

if( -not ( Test-Path $tmp ) ){
    Write-Error "MSI download failed."
    return
}

Write-Host "Running installer"
<#
$DataStamp = get-date -Format yyyyMMddTHHmmss
$logFile = '{0}-{1}.log' -f $file.fullname,$DataStamp
$MSIArguments = @(
    "/i"
    ('"{0}"' -f $file.fullname)
    "/qn"
    "/norestart"
    "/L*v"
    $logFile
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
#>

<#
completely silent: /quiet
minimal gui is:    /passive
#>

$installerResult = Start-Process msiexec.exe -Wait -ArgumentList "/I $tmp"
if( $? ){
    Write-Host "Installation seems to have succeeded."
}else{
    Write-Error "Installation seems to have failed."
}
del $tmp
Write-Host "Installation script complete."
