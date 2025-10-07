Set-Location "C:\VM_Stuff_Share\Lab_Version1.1\CousinDomain\WSUS"

. .\Create-VM.ps1
Create-VM -VMName "Shop-DC"
Create-VM -VMName "Shop-Client"
Write-Host "Please wait, the VMs are booting up."
Start-Sleep -Seconds 180

#VM's initial local admin:
[string]$userName = "Changme\Administrator"
[string]$userPassword = 'SuperSecureLocalPassword123!@#'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$InitialCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

#VM's local admin after re-naming the computer:
[string]$userName = "Shop-DC\Administrator"
[string]$userPassword = 'SuperSecureLocalPassword123!@#'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$ShopDCLocalCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

#VM's local admin after re-naming the computer:
[string]$userName = "Shop-Client\Administrator"
[string]$userPassword = 'SuperSecureLocalPassword123!@#'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$ShopClientLocalCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

Set-Location "C:\VM_Stuff_Share\Lab_Version1.1\ShopDomain"

# --- Setup Shop-DC
Invoke-Command -VMName "Shop-DC" -FilePath '.\VMConfig (ShopDC P1).ps1' -Credential $InitialCredObject   #Configs IPv4, disables IPv6, renames the VM
Start-Sleep -Seconds 120
Invoke-Command -VMName "Shop-DC" -FilePath '.\VMConfig (ShopDC P2).ps1' -Credential $ShopDCLocalCredObject   #Makes the VM a DC in a new forest; research.local
Start-Sleep -Seconds 300 
Invoke-Command -VMName "Shop-DC" -FilePath '.\VMConfig (ShopDC P3).ps1' -Credential $ThirdDomainAdminCredObject   #Creates Backup Ent Admin, users, computers, etc


#Last step; set the Administrator password

#shop.local Ent Admin:
[string]$userName = "shop\Break.Glass"
[string]$userPassword = 'SuperDuperExtraSafeDomainPassword12!@'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$ThirdDomainAdminCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

Invoke-Command -VMName "Shop-DC" {Set-ADAccountPassword -Identity "Administrator" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText 'SuperDuperExtraSafeDomainPassword12!@' -Force)} -Credential $ThirdDomainAdminCredObject

# --- Setup Shop-Client

#Config the VM's NIC
. .\Config-NIC.ps1
Config-NIC -VMName "Shop-Client" -IP "151"
Start-Sleep -Seconds 30

#Rename the VM, disable IPv6, & install RSAT
. .\Name-VM.ps1
Name-VM -VMName "Shop-Client" -NewName "Shop-Client"
Start-Sleep -Seconds 120

#Joins shop.local
Invoke-Command -VMName "Shop-Local" -FilePath '.\VMConfig (ShopClient P2).ps1' -Credential $ShopClientLocalCredObject    
Start-Sleep -Seconds 120

# --- Misconfig the client ---


Invoke-Command -VMName "Shop-Client" {New-Item -Path "C:\VulnService" -ItemType Directory -Force | Out-Null} -Credential $ThirdDomainAdminCredObject
Enable-VMIntegrationService "Guest Service Interface" -VMName "Shop-Client"
Copy-VMFile "Shop-Client" -SourcePath ".\PsExec.exe" -DestinationPath "C:\VulnService" -CreateFullPath -FileSource Host
Invoke-Command -VMName "Shop-Client" {Add-LocalGroupMember -Group "Remote Desktop Users" -Member "shop\dan"} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" -FilePath '.\Create-VulnSvc.ps1' -Credential $ThirdDomainAdminCredObject

Invoke-Command -VMName "Shop-Client" {Install-WindowsFeature -name Web-Server -IncludeManagementTools} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" {New-NetFirewallRule -DisplayName "IIS" -LocalPort "80" -Action Allow -Profile Any -Protocol TCP -Direction Inbound} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" {Restart-Computer -Force} -Credential $ThirdDomainAdminCredObject
Start-Sleep -Seconds 120