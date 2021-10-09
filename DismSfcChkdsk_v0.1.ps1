If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Error "Must be run as administrator (elevated mode)."
	Write-Output "`nPress any key to continue..."
	[Console]::ReadKey($true) | Out-Null
}

# TODO: Add check to only run dism if 2012 or newer...

Write-Host "Running DISM clean-up"
Write-Host "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
dism /online /cleanup-image /restorehealth

Write-Output "`nPress any key to continue..."
[Console]::ReadKey($true) | Out-Null

Write-Host "Running SFC Scan"
Write-Host "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
sfc /scannow

Write-Output "`nPress any key to continue..."
[Console]::ReadKey($true) | Out-Null

Write-Host "Running read-only checkdisk"
Write-Host "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
$volumes = Get-Partition | Where-Object { $_.DriveLetter -match "[a-zA-Z]" }

foreach ( $volume in $volumes ){
    Repair-Volume $volume.DriveLetter -Scan
    Write-Output "`nPress any key to continue..."
    [Console]::ReadKey($true) | Out-Null
}

Write-Host "Online repairs and scan completed."

Write-Output "`nPress any key to continue..."
[Console]::ReadKey($true) | Out-Null
