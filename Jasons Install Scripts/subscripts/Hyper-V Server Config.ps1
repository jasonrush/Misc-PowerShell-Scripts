# Last updated 2020-11-04 by Jason Rush

# Start installing and configuring Hyper-V
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart

# Create VM Folder 
$DriveLetter = (get-volume | Sort-Object -Descending { $_.Size } | Select-Object -First 1).DriveLetter
$HyperVGuestsPath = "$($DriveLetter):\Hyper-V Guests\"
if( -not ( Test-Path $HyperVGuestsPath ) ){
    Write-Host "Creating path: $HyperVGuestsPath"
    New-Item -Path $HyperVGuestsPath -ItemType Directory
}else{
    Write-Host "Path already exists: $HyperVGuestsPath"
}

# Set VM Folder
$VMHost = Get-VMHost
$VMsPath = "$($DriveLetter):\Hyper-V Guests\"
if( $VMHost.VirtualHardDiskPath -ne $VMsPath ){
    Write-Host "Setting VirtualHardDiskPath: $VMsPath"
    Set-VMHost -VirtualHardDiskPath $VMsPath
}else{
    Write-Host "VirtualHardDiskPath already set: $($VMHost.VirtualHardDiskPath)"
}
if( $VMHost.VirtualMachinePath -ne $VMsPath ){
    Write-Host "Setting VirtualMachinePath: $VMsPath"
    Set-VMHost -VirtualMachinePath $VMsPath
}else{
    Write-Host "VirtualMachinePath already set: $($VMHost.VirtualMachinePath)"
}

# Create an Internal Network
if( (Get-VMSwitch).count -eq 0 ){
    $ActiveNetAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    Write-Host "Creating first vSwitch via: $($ActiveNetAdapter.Name)"
    New-VMSwitch -name ExternalSwitch  -NetAdapterName $ActiveNetAdapter.Name -AllowManagementOS $true  
}else{
    Write-Host "VMSwitch(es) already found."
}

# Create Source folder
if( -not ( Test-Path "$($DriveLetter):\source\" ) ){
    Write-Host "Creating path: $($DriveLetter):\source\"
    New-Item -Path "$($DriveLetter):\source\" -ItemType Directory
}else{
    Write-Host "Path already exists: $($DriveLetter):\source\"
}
if( -not ( Test-Path "$($DriveLetter):\source\ISOs\" ) ){
    Write-Host "Creating path: $($DriveLetter):\source\ISOs\"
    New-Item -Path "$($DriveLetter):\source\ISOs\" -ItemType Directory
}else{
    Write-Host "Path already exists: $($DriveLetter):\source\ISOs\"
}

