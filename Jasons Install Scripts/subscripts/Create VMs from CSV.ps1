<#

Example CSV Contents:

Name,RAM,Cores,OSDiskSize,DataDiskLetter,DataDiskSize,Roles
XYZ-DC01,8,4,200,,,AD
XYZ-DC02,8,4,200,,,AD
XYZ-FP01,16,4,200,E,1000,Print;File

#>

$CSVInfo = Import-Csv 'C:\Jasons Install Scripts\config\VMs.csv'

$VMName = "Server2019StdTemplate"
$DriveLetter = (get-volume | Sort-Object -Descending { $_.Size } | Select-Object -First 1).DriveLetter
$VMRootPath = "$($DriveLetter):\Hyper-V Guests"
$VMTemplate = "$($DriveLetter):\source\$($VMName).vhdx"

$VMCredential = Get-Credential -Message "Enter VM Admin credentials"

$CSVInfo | ForEach-Object {
    $VMName = $_.Name
    Write-Host "Name: $VMName"
    $VMPath = "$VMRootPath\$($_.Name)"
    Write-Host "Path: $VMPath"
    if( ! (Test-Path $VMRootPath) ){
        Write-Warning "Path does not exist: $VMRootPath"
    }
    $VMRAM = [convert]::ToInt32( ($_.RAM), 10 ) * 1024MB
    Write-Host "RAM: $VMRAM"
    $VMCores = [convert]::ToInt32( ($_.Cores), 10 )
    Write-Host "Cores: $VMCores"
    $VMOSDiskSize = [convert]::ToInt32( ($_.OSDiskSize), 10 ) * 1024MB
    Write-Host "OS Disk Size: $VMOSDiskSize"
    $VMDataDiskLetter = $_.DataDiskLetter
    if( $_.DataDiskLetter ){
        $VMDataDiskSize = [convert]::ToInt32( ($_.DataDiskSize), 10 ) * 1024MB
        Write-Host "Data Disk: $VMDataDiskLetter @ $($_.DataDiskSize) GB"
    }

    if( Get-VM -Name $VMName -ErrorAction SilentlyContinue ){
        Write-Warning "VM with name $VMName already exists."
    }else{
        Write-Host "Creating VM '$VMName' at '$VMRootPath' with $($_.RAM) GB RAM"
        New-VM -Name $VMName -Path $VMRootPath -MemoryStartupBytes $VMRAM -Generation 2
        Write-Host "Setting VM to $VMCores CPU cores"
        Set-VMProcessor -VMName $VMName -Count $VMCores
        Write-Host "Connecting VM to vSwitch 'ExternalSwitch'"
        # Look at adding the -SwitchName parameter to New-VM instead!
        Get-VMSwitch ExternalSwitch | Connect-VMNetworkAdapter -VMName $VMName
    }

    $VMOSFilePath = "$VMPath\$VMName-C.vhdx"
    if( Test-Path $VMOSFilePath){
        Write-Warning "OS VHDX file already exists: $VMOSFilePath"
    }else{
        Write-Host "Copying $VMTemplate to $VMOSFilePath"
        #Copy-Item $VMTemplate $VMOSFilePath
        Convert-VHD -Path $VMTemplate -DestinationPath $VMOSFilePath -VHDType Fixed
        Write-Host "Resizing $VMOSFilePath to $($VMOSDiskSize / 1024MB) GB"
        Resize-VHD -Path $VMOSFilePath -SizeBytes $VMOSDiskSize
        Add-VMHardDiskDrive -VMName $VMName -Path $VMOSFilePath -ControllerType SCSI
#        Write-Host "Setting boot order: 'IDE', 'CD', 'LegacyNetworkAdapter', 'Floppy'"
#        Set-VMBios $VMName -StartupOrder @("IDE", "CD", "LegacyNetworkAdapter", "Floppy")
        Write-Host "Setting boot order: 'Drive','Network''"
# TODO: Add-VMDvdDrive and add DVD drive to boot order
        $VMNetworkAdapter = Get-VMNetworkAdapter -VMName $VMName
        $VMHardDriveDisk = Get-VMHardDiskDrive -VMName $VMName
        Set-VMFirmware -VMName $VMName -BootOrder $VMHardDriveDisk,$VMNetworkAdapter
    }
    $VMDataFilePath = "$VMPath\$VMName-$VMDataDiskLetter.vhdx"
    if( ($_.DataDiskLetter) -and -not (Test-Path $VMDataFilePath) ){
        Write-Host "Creating data disk at $VMDataFilePath"
        New-VHD -Path $VMDataFilePath -SizeBytes $VMDataDiskSize -Fixed
        Add-VMHardDiskDrive -VMName $VMName -Path $VMDataFilePath -ControllerType SCSI
    }else{
        if( -not (Test-Path $VMDataFilePath) ){
            Write-Host "No data disk specified."
        }else{
            Write-Warning "Data disk already exists at $VMDataFilePath"
        }
    }
    vmconnect localhost $VMName
    Write-Host "Power on VM and complete Out-of-box experience for this VM."
    Write-Host "`tJust set up credentials to match what you provided earlier and leave the VM logged in."
    Read-Host "Press [Enter] to continue"

    # Make sure the Guest Service Interface is enabled so we can 
    Get-VM -Name $VMName | Get-VMIntegrationService -Name "Guest Service Interface" | Enable-VMIntegrationService -Verbose

    Invoke-Command -VMName $VMName -Credential $VMCredential -FilePath 'C:\Jasons Install Scripts\subscripts\Base Server Config.ps1'
    Invoke-Command -VMName $VMName -Credential $VMCredential -ScriptBlock {
        Rename-Computer -NewName $Using:VMName -Restart
    }
    Write-Host "Rebooting $VMName... Please log into the VM once it has finished booting up"
    Start-Sleep 30
    while ((Invoke-Command -VMName $VMName -Credential $VMCredential {“Test”} -ea SilentlyContinue) -ne “Test”) { Write-Host "`tSleeping 10 seconds..."; Sleep -Seconds 10}

    if( -not [string]::IsNullOrEmpty( $_.Roles ) ){
        Write-Output "Preparing to install server roles..."

        # Run scripts to install roles
        $scriptsPath = "C:\Jasons Install Scripts"

        $_.Roles -Split ';' | ForEach-Object {
            if( Test-Path -ErrorAction SilentlyContinue -Path "C:\Jasons Install Scripts\roles\$($_).ps1" ){
                Write-Output "Found role installation script for '$_'. Running..."
                Invoke-Command -VMName $VMName -Credential $VMCredential -FilePath "C:\Jasons Install Scripts\roles\$($_).ps1"
            }else{
                Write-Warning "No role installation script found for '$_'."
            }
        }
    }
}
