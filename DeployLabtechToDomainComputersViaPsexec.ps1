$sourcePath = "C:\source\"
$psexecUrl = "https://live.sysinternals.com/psexec.exe"
$psexecPath = "$sourcePath\psexec.exe"
$msiRemoteFileName = "Automate_Agent.msi"
$msiRemoteUncPath = "c$\$msiRemoteFileName"
$msiRemoteLocalPath = "c:\$msiRemoteFileName"

$pre2012 = $false
if( [environment]::OSVersion.Version -le [Version]'6.2' ){
    $pre2012 = $true
}

# FUNCTIONS

Function pause ($message)
{
    # Check if running Powershell ISE
    if ($psISE)
    {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("$message")
    }
    else
    {
        Write-Host "$message" -ForegroundColor Yellow
        $x = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

Function Get-FileName($initialDirectory)
{
    if( $pre2012 ){
        Read-Host "MSI Path: "
    }else{
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
        Out-Null

        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.initialDirectory = $initialDirectory
        $OpenFileDialog.filter = "All files (*.*)| *.*"
        $OpenFileDialog.ShowDialog() | Out-Null
        $OpenFileDialog.filename
    }
} #end function Get-FileName


# START CODE

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if( -not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ){
    Write-Error "Must be run as administrator"
    pause
}

# Create source directory, if it doesn't exist.
If(!(test-path $sourcePath)){
    New-Item -ItemType Directory -Force -Path $sourcePath
    if(!(Test-Path $sourcePath)){
        Write-Error "Creating source directory at $sourcePath failed."
        pause
        return
    }
}

# Download psexec if it doesn't exist in the source directory.
if(!(Test-Path $psexecPath)){
    (New-Object System.Net.WebClient).DownloadFile( $psexecUrl, $psexecPath )
    if(!(Test-Path $psexecPath)){
        Write-Error "psexec download failed."
        pause
        return
    }
}

# Import ActiveDirectory module.
If ( ! (Get-module ActiveDirectory )) {
    Import-Module ActiveDirectory
    If ( ! (Get-module ActiveDirectory )) {
        Write-Error "Importing ActiveDirectory module failed."
        pause
        return
    }
}

$msiLocalPath = Get-FileName -initialDirectory $sourcePath

if( '' -eq $msiLocalPath ){
    Write-Error "No file path selected."
    pause
    return
}

$activeAdComputers = Get-ADComputer -Filter {enabled -eq $true} -properties * | select Name,DNSHostName
$activeAdComputers = Get-ADComputer -Filter {enabled -eq $true} -properties * | Where-Object { ($_.Name -ne $(hostname)) -and ($_.DNSHostName -ne $null) } | select Name,DNSHostName

$activeAdComputers | ForEach-Object {
    Write-Host "Name: $($_.Name) DNS: $($_.DnsHostName)"
    if (test-Connection -Cn $_.DNSHostName -quiet) {
        # Copy the MSI installer to the remote computer.
        Write-Host "Copying from $msiLocalPath to \\$($_.DnsHostName)\$msiRemoteUncPath"
        Copy-Item $msiLocalPath \\$($_.DnsHostName)\$msiRemoteUncPath
        if(!(Test-Path \\$($_.DnsHostName)\$msiRemoteUncPath)){
            Write-Error "Writing installer to remote computer $($_.DnsHostName) failed."
        }else{
            $psexecArgs = "\\$($_.DnsHostName) -s cmd /c `"msiexec.exe /i $msiRemoteLocalPath /q /qn /norestart`""
            Write-Host "Attempting to install on $($_.DnsHostName)"
            Start-Process -Filepath "$psexecPath" -ArgumentList $psexecArgs -NoNewWindow -PassThru -Wait # -RedirectStandardOutput stdout.txt -RedirectStandardError stderr.txt
        }
    } else {
        write-verbose "$($_.DnsHostName) is not online"
    }

}
