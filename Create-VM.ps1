Function Create-VM
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $VMName,
         [Parameter(Mandatory=$false, Position=1)]
         [string] $IP
    )

#Creates the VM from a provided ISO & answer file, names it provided VMName
Set-Location "C:\VM_Stuff_Share\Lab_Version1.1\ShopDomain"
$isoFilePath = "..\..\ISOs\Windows Server 2022 (20348.169.210806-2348.fe_release_svc_refresh_SERVER_EVAL_x64FRE_en-us).iso"
$answerFilePath = ".\2022_autounattend.xml"

New-Item -ItemType Directory -Path C:\Hyper-V_VMs\$VMName

$convertParams = @{
    SourcePath        = $isoFilePath
    SizeBytes         = 100GB
    Edition           = 'Windows Server 2022 Datacenter Evaluation (Desktop Experience)'
    VHDFormat         = 'VHDX'
    VHDPath           = "C:\Hyper-V_VMs\$VMName\$VMName.vhdx"
    DiskLayout        = 'UEFI'
    UnattendPath      = $answerFilePath
}

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
. '.\Convert-WindowsImage.ps1'

Convert-WindowsImage @convertParams

#Test if a Default Switch exists, if so, use it, otherwise use the Testing switch
$ErrorActionPreference = "SilentlyContinue"
If(Get-VMSwitch -Name "Default Switch")
{
Write-Host "It looks like we are on Windows 10 or 11 Pro. Setting RAM & vSW accordingly."
New-VM -Name $VMName -Path "C:\Hyper-V_VMs\$VMName" -MemoryStartupBytes 2GB -Generation 2
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes 2GB -StartupBytes 3GB -MaximumBytes 4GB
Connect-VMNetworkAdapter -VMName $VMName -Name "Network Adapter" -SwitchName "Default Switch"
}

ElseIf(Get-VMSwitch -Name "Testing")
{
Write-Host "It looks like we are on Hyper-V Server or Windows Server. Setting RAM & vSW accordingly." 
New-VM -Name $VMName -Path "C:\Hyper-V_VMs\$VMName" -MemoryStartupBytes 6GB -Generation 2
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes 6GB -StartupBytes 6GB -MaximumBytes 8GB
Connect-VMNetworkAdapter -VMName $VMName -Name "Network Adapter" -SwitchName "Testing"
}

Else{Write-Host "It looks like Hyper-V is not setup & configured correctly."}

$vm = Get-Vm -Name $VMName
$vm | Add-VMHardDiskDrive -Path "C:\Hyper-V_VMs\$VMName\$VMName.vhdx"
$bootOrder = ($vm | Get-VMFirmware).Bootorder
#$bootOrder = ($vm | Get-VMBios).StartupOrder
if ($bootOrder[0].BootType -ne 'Drive') {
    $vm | Set-VMFirmware -FirstBootDevice $vm.HardDrives[0]
    #Set-VMBios $vm -StartupOrder @("IDE", "CD", "Floppy", "LegacyNetworkAdapter")
}
Start-VM -Name $VMName
}#Close the Create-VM function