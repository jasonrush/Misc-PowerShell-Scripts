# Last updated 2019-12-19 by Jason Rush

#region Set/check Firewalls to fully permissive
Write-Output "[I] Setting all firewall profiles to fully permissive"

Set-NetFirewallProfile -DefaultInboundAction Allow

# Check Domain Firewall Profile
if( (get-netfirewallprofile | Where-Object {$_.name -eq "Domain"}).DefaultInboundAction -eq "Allow" ){
    Write-Output "[I] Domain profile is fully permissive"
}else{
    throw "[W] WARNING - Domain profile is not fully permissive"
}


# Check Private Firewall Profile
if( (get-netfirewallprofile | Where-Object {$_.name -eq "Private"}).DefaultInboundAction -eq "Allow" ){
    Write-Output "[I] Private profile is fully permissive"
}else{
    throw "[W] WARNING - Private profile is not fully permissive"
}


# Check Domain Firewall Profile
if( (get-netfirewallprofile | Where-Object {$_.name -eq "Public"}).DefaultInboundAction -eq "Allow" ){
    Write-Output "[I] Public profile is fully permissive"
}else{
    throw "[W] WARNING - Public profile is not fully permissive"
}
#endregion

#region Set/check timezone
Write-Output "[I] Setting timezone to 'Alaskan Standard Time'"

# Set timezone to Alaska
tzutil /s "Alaskan Standard Time"

#TODO: Check timezone!
Write-Output "[I] TODO: Check/verify timezone."
#endregion

#region Set/check RDP is enabled
Write-Output "[I] Enabling Remote Desktop (and associated firewall rules)"

# Set
if( get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" ){
    # Change registry entry
    set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
}else{
    # Create registry entry
    New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0 -PropertyType dword
}
# Enable RDP through firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Check/verify
if( (get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections").fDenyTSConnections -eq 0 ){
    Write-Output "[I] Remote Desktop is enabled"
}else{
    throw "[W] WARNING - Remote Desktop is not enabled"
}

Write-Output "[I] TODO: Verify Remote Desktop firewall rules"
#endregion

#region Remap optical drive to F:\, if necessary
Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' |
  Select-Object -First 1 |
  Set-WmiInstance -Arguments @{DriveLetter='F:'} | Out-Null
#endregion

#region Online additional drives, create partitions, and extend partitions to max size
Write-Output "[I] Checking if C: partition should be extended"

if( ( (Get-Partition -DriveLetter c).size + 1MB ) -lt (Get-PartitionSupportedSize -DriveLetter c).sizeMax ){
    Write-Output "[I] Extending C: partition"
    Resize-Partition -DriveLetter c -Size (Get-PartitionSupportedSize -DriveLetter c).sizeMax
}else{
    Write-Output "[I] C: partition is already max size"
}

Write-Output "[I] Bringing offline drives online, and creating a single maxed partition on each"

# Online any additional drives, partition, etc?
get-disk | where-object {$_.operationalstatus -eq "Offline"} | set-disk -IsOffline $False
start-sleep 10
Get-Disk |
    Where-Object { $_.partitionstyle -eq "raw" } |
    Initialize-Disk -PartitionStyle GPT -PassThru |
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "DATA" -Confirm:$false
start-sleep 10
#endregion

#region Check/create /source/ directory
$DriveLetter = (get-volume | Sort-Object -Descending { $_.Size } | Select-Object -First 1).DriveLetter
$sourcePath = "$($DriveLetter):\source\"
Write-Output "[I] Checking if $sourcePath directory exists"

if( (Test-Path $sourcePath) ){
    Write-Output "[I] $sourcePath already exists"
}else{
    Write-Output "[I] Creating $sourcePath"
    New-Item $sourcePath -type directory | Out-Null
}
#endregion

















Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
# Sleep 300 seconds-ish
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

