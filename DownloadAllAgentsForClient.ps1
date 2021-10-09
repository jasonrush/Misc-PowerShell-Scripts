# Configuration Variables.

# Base URL for Labtech server (ie 'https://contoso.hostedrmm.com')
$url = "https://contoso.hostedrmm.com";

# File name to use for local copy of installer
$filePrefix = 'Automate_Agent-'
$fileSuffix = '.msi'



Function Get-Folder($initialDirectory){
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder"
    $foldername.rootfolder = "MyComputer"

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return $folder
}

Function Remove-InvalidFileNameChars {
  param(
    [Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
    [String]$Name
  )

  $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
  $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
  return ($Name -replace $re)
}



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

# Select locations.
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

# Select destination for installers.

$downloadDestination = Get-Folder

Write-Host "Will download installers to $downloadDestination"

$selectedLocations = $locations | Out-GridView -OutputMode Multiple -Title "Select Location(s)"

foreach( $currentLocation in $selectedLocations ){
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

    $locationName = Remove-InvalidFileNameChars $currentLocation.Name

    $link = "$url/Labtech/Deployment.aspx?installType=msi&ID=$($currentLocation.Id)"
    $downloadPath = "$downloadDestination/$filePrefix$locationName$fileSuffix"

    Write-Verbose "Downloading Agent (MSI) from"
    Write-Verbose "`t$link"
    Write-Verbose "to"
    Write-Verbose "`t$downloadPath"
    $client = New-Object System.Net.WebClient
    $client.Headers['Authorization'] = "bearer $($ApiToken.AccessToken)";
    $client.DownloadFile($link, $downloadPath)
    <#
    # TODO: This may be better to rework something like: Invoke-WebRequest $url -OutFile 'c:\windows\temp\installer.exe' -UseBasicParsing
    This will add a step toward being able to run this on Core installs/etc. I'm not sure if th System.Net.WebClient works w/o IE?
    #>

    if( -not ( Test-Path $downloadPath ) ){
        Write-Error "MSI download failed for $locationName."
        return
    }
}

