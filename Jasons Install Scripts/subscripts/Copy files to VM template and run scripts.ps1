$VMName = "Server2019StdTemplate"
$scriptsPath = "C:\Jasons Install Scripts"

# Make sure the Guest Service Interface is enabled so we can 
Get-VM -Name $VMName | Get-VMIntegrationService -Name "Guest Service Interface" | Enable-VMIntegrationService -Verbose

$VMCredential = Get-Credential -Message "Enter VM Admin credentials"

# Run the initial base configuration, copy files, install PSWindowsUpdate module
Invoke-Command -VMName $VMName -Credential $VMCredential -FilePath 'C:\Jasons Install Scripts\subscripts\Base Server Config.ps1'
Invoke-Command -VMName $VMName -Credential $VMCredential -ScriptBlock {
    Get-PackageProvider -name nuget -force | Out-Null
    Install-Module PSWindowsUpdate -confirm:$false -force | Out-Null
}

# Install Windows Updates until no updates left or not installing
Do {
    $prevUpdatesAvailable = Invoke-Command -VMName $VMName -Credential $VMCredential -ScriptBlock { Get-WindowsUpdate -Download -acceptall }
    Write-Output "Available updates:"
    $prevUpdatesAvailable | Foreach-Object {
        Write-Output "`t$($_.Title)"
    }
    Write-Output "Installing updates and rebooting..."
    (Invoke-Command -VMName $VMName -Credential $VMCredential -ScriptBlock { Get-WindowsUpdate -Install -acceptall -IgnoreReboot; Restart-Computer -Force }) | Out-Null
    Write-Output "`tWaiting 60 seconds for reboot to start..."
    Start-Sleep 60
    While ( (Get-VM -Name $VMName).State -ne "Running" ){ Write-Output "`tSleeping another 30 seconds..."; Start-Sleep 30 }
    # Replace with:    while ((icm -VMName $DCVMName -Credential $DCLocalCredential {“Test”} -ea SilentlyContinue) -ne “Test”) {Sleep -Seconds 1}
    $updatesAvailable = Invoke-Command -VMName $VMName -Credential $VMCredential -ScriptBlock { wuauclt.exe /detectnow; Get-WindowsUpdate }
} While ( $updatesAvailable -ne $prevUpdatesAvailable )

Write-Output "Remaining updates:"
$updatesAvailable | Foreach-Object {
    Write-Output "`t$($_.Title)"
}

# Clean up and sysprep
# TODO: THIS DOES NOT SEEM TO BE RUNNING AUTOMATED, NEED TO INVESTIGATE FURTHER
Write-Output "Running Sysprep"
Write-Output "`tThis step does not seem to run correctly via automated means. You must run the following as admin:"
Write-Output "`tC:\windows\system32\sysprep\sysprep.exe /generalize /oobe /shutdown"
Read-Host "Press enter to continue"
<#
Invoke-Command -VMName $VMName -Credential $VMCredential -ScriptBlock {
    #Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList ‘/generalize /oobe /shutdown’
    $cmd = 'C:\Windows\System32\Sysprep\Sysprep.exe'
    $args = '/generalize','/oobe','/shutdown'
    & $cmd $args
}
#>

Write-Output "Waiting for VM to power off..."
While ( (Get-VM -Name $VMName).State -ne "Off" ){ Write-Output "`tSleeping another 30 seconds..."; Start-Sleep 30 }

# Move VM VHDX file to template path and delete VM
Write-Output "Moving VHDX file to template path and deleting VM"
$DriveLetter = (get-volume | Sort-Object -Descending { $_.Size } | Select-Object -First 1).DriveLetter
$VMRootPath = "$($DriveLetter):\Hyper-V Guests"
$VMTemplate = "$($DriveLetter):\source\$($VMName).vhdx"
New-Item -ItemType Directory -Path "$($DriveLetter):\source\" -Force | Out-Null

Move-Item "$VMRootPath\$VMName\$VMName-C.vhdx" $VMTemplate
Remove-VM -Name $VMName -Force
Remove-Item -Recurse "$VMRootPath\$VMName\" -Force
