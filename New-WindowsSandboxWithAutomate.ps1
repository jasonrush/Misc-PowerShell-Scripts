$Command = {
    Set-ExecutionPolicy Unrestricted    
    $ModulesToInstall = @("powershellget.2.2.1","packagemanagement.1.4.5")
    foreach($Module in $ModulesToInstall)
    {
        Write-Host "Installing $Module"
        $PackageManagementPath = (Join-Path $env:temp "$Module.zip")
        (new-object Net.WebClient).DownloadFile("https://psg-prod-eastus.azureedge.net/packages/$Module.nupkg", $PackageManagementPath)
        $Destination = "C:\Program Files\WindowsPowerShell\Modules\$($Module.Split(".")[0])"
        New-Item -itemtype Directory -Path $Destination -Force | Out-Null
        Expand-Archive $PackageManagementPath $Destination
    }
    (new-object Net.WebClient).DownloadString('https://bit.ly/LTPoSh') | iex; Install-LTService -Server 'https://Automate.Hostname.com' -LocationID 1 -SkipDotNet;
}


$EncodedScript = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Command))
$XMLString = @"
<Configuration>
<VGpu>Disable</VGpu>
<Networking>Enable</Networking>
<LogonCommand>
   <Command>powershell.exe -noexit -command iex ([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String("""$EncodedScript""")))</Command>
</LogonCommand>
</Configuration>
"@
$XML = [xml]$XMLString
$WSBFilePath = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), ".wsb")
Set-Content -Value $XMLString -Path $WSBFilePath -Force

Start-Process -Wait $WSBFilePath