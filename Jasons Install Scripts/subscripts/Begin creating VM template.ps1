# Last updated 2020-11-04 by Jason Rush
$DriveLetter = (get-volume | Sort-Object -Descending { $_.Size } | Select-Object -First 1).DriveLetter
$VMRootPath = "$($DriveLetter):\Hyper-V Guests"

$VMName = "Server2019StdTemplate"
Write-Host "Name: $VMName"

$VMPath = "$VMRootPath\$($_.Name)"
Write-Host "Path: $VMPath"
if( ! (Test-Path $VMRootPath) ){
    Write-Warning "Path does not exist: $VMRootPath"
}

$VMRAM = [convert]::ToInt32( (8), 10 ) * 1024MB
Write-Host "RAM: $VMRAM"

$VMCores = [convert]::ToInt32( (4), 10 )
Write-Host "Cores: $VMCores"

$VMOSDiskSize = [convert]::ToInt32( (30), 10 ) * 1024MB
Write-Host "OS Disk Size: $VMOSDiskSize"

if( Get-VM -Name $VMName -ErrorAction SilentlyContinue ){
    Write-Warning "VM with name $VMName already exists."
}else{
    Write-Host "Creating VM '$VMName' at '$VMRootPath' with $($VMRAM/1024MB) RAM"
    New-VM -Name $VMName -Path $VMRootPath -MemoryStartupBytes $VMRAM -NewVHDPath "$VMRootPath\$VMName\$VMName-C.vhdx" -NewVHDSizeBytes $VMOSDiskSize -Generation 2
    Write-Host "Setting VM to $VMCores CPU cores"
    Set-VMProcessor -VMName $VMName -Count $VMCores
    Write-Host "Connecting VM to vSwitch 'ExternalSwitch'"
    Get-VMSwitch ExternalSwitch | Connect-VMNetworkAdapter -VMName $VMName
}
# TODO: Add-VMDvdDrive and then set boot order to "HDD","DVD","Network"