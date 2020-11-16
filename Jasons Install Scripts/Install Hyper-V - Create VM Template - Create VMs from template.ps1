# Last updated 2020-11-04 by Jason Rush
. 'C:\Jasons Install Scripts\subscripts\Base Server Config.ps1'
. 'C:\Jasons Install Scripts\subscripts\Hyper-V Server Config.ps1'
. 'C:\Jasons Install Scripts\subscripts\Begin creating VM template.ps1'
vmconnect localhost "Server2019StdTemplate"
Write-Output "VM has been created, ISO needs attached, OS needs installed, and logged in to desktop."
Read-Host "Press enter to continue"
. 'C:\Jasons Install Scripts\subscripts\Copy files to VM template and run scripts.ps1'
. 'C:\Jasons Install Scripts\subscripts\Create VMs from CSV.ps1'
