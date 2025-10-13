Set-Location "C:\VM_Stuff_Share\Lab_Version1.1\ShopDomain"

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

#VM's domain admin after creating shop.local:
[string]$userName = "Shop\Administrator"
[string]$userPassword = 'SuperSecureLocalPassword123!@#'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$ShopInitialCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

#VM's local admin after re-naming the computer:
[string]$userName = "Shop-Client\Administrator"
[string]$userPassword = 'SuperSecureLocalPassword123!@#'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$ShopClientLocalCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

#VM's local admin after re-naming the computer:
[string]$userName = "shop\Frisky.McRisky"
[string]$userPassword = 'LivinOnAPrayer!!!!'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$FriskyCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

Set-Location "C:\VM_Stuff_Share\Lab_Version1.1\ShopDomain"

# --- Setup Shop-DC ---
Invoke-Command -VMName "Shop-DC" -FilePath '.\VMConfig (ShopDC P1).ps1' -Credential $InitialCredObject   #Configs IPv4, disables IPv6, renames the VM
Start-Sleep -Seconds 120
Invoke-Command -VMName "Shop-DC" -FilePath '.\VMConfig (ShopDC P2).ps1' -Credential $ShopDCLocalCredObject   #Makes the VM a DC in a new forest; research.local
Start-Sleep -Seconds 300
#'Guest Service Interface' must be enabled for Copy-VMFile to work
Enable-VMIntegrationService "Guest Service Interface" -VMName "Shop-DC"
Copy-VMFile "Shop-DC" -SourcePath ".\Users.csv" -DestinationPath "C:\Users.csv" -CreateFullPath -FileSource Host
Start-Sleep -Seconds 30  
Invoke-Command -VMName "Shop-DC" -FilePath '.\VMConfig (ShopDC P3).ps1' -Credential $ShopInitialCredObject   #Creates Backup Ent Admin, users, computers, etc
Start-Sleep -Seconds 60

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
Invoke-Command -VMName "Shop-Client" -FilePath '.\VMConfig (ShopClient P2).ps1' -Credential $ShopClientLocalCredObject    
Start-Sleep -Seconds 120

# --- Misconfig the client ---

#Create an intentionally vulnerable service, give Dan rights to modify/repleace the *.exe, and give Dan the rights to RDP in via PTH
Invoke-Command -VMName "Shop-Client" {New-Item -Path "C:\VulnService" -ItemType Directory -Force | Out-Null} -Credential $ThirdDomainAdminCredObject
Enable-VMIntegrationService "Guest Service Interface" -VMName "Shop-Client"
Copy-VMFile "Shop-Client" -SourcePath ".\PsExec.exe" -DestinationPath "C:\VulnService" -CreateFullPath -FileSource Host
Invoke-Command -VMName "Shop-Client" {Add-LocalGroupMember -Group "Remote Desktop Users" -Member "shop\dan"} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" {Add-LocalGroupMember -Group "Remote Management Users" -Member "shop\dan"} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" {New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -name 'DisableRestrictedAdmin' -PropertyType 'DWORD' -value '0' -force} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" {Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" -FilePath '.\Create-VulnSvc.ps1' -Credential $ThirdDomainAdminCredObject

#Try adding Dan to local admins, run the command to disable RestricteAdminMode with his creds, then remove him from local admins
#If that doesn't work then share Dan's Desktop via SMB and put a clever *.txt on there with a note and their password

#Create the website
Invoke-Command -VMName "Shop-Client" {Install-WindowsFeature -name Web-Server -IncludeManagementTools} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" {New-NetFirewallRule -DisplayName "IIS" -LocalPort "80" -Action Allow -Profile Any -Protocol TCP -Direction Inbound} -Credential $ThirdDomainAdminCredObject

Enable-VMIntegrationService "Guest Service Interface" -VMName "Shop-Client"
Copy-VMFile "Shop-Client" -SourcePath ".\meettheteam.zip" -DestinationPath "C:\meettheteam.zip" -CreateFullPath -FileSource Host
Start-Sleep -Seconds 30
Invoke-Command -VMName "Shop-Client" {Expand-Archive -Path "C:\meettheteam.zip" -DestinationPath "C:\inetpub\wwwroot\"} -Credential $ThirdDomainAdminCredObject
Start-Sleep -Seconds 30
#Invoke-Command -VMName "Shop-Client" {icacls "C:\inetpub\wwwroot" /grant "IIS_IUSRS:(OI)(CI)R" /T} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" {Import-Module WebAdministration ; Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/defaultDocument/files" -name "." -value @{value='meettheteam.html'}} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" {Import-Module WebAdministration ; Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/defaultDocument/files" -name "." -value @{value="meettheteam.html"; position="0"} ; iisreset /restart} -Credential $ThirdDomainAdminCredObject

#Put Frisky.McRisky in Server Admins. Put Frisky.McRisky's creds in DPAPI via a saved RDP session.
Invoke-Command -VMName "Shop-Client" {Add-LocalGroupMember -Group "Administrators" -Member "shop\Frisky.McRisky"} -Credential $ThirdDomainAdminCredObject
Invoke-Command -VMName "Shop-Client" {whoami | Out-Null} -Credential $FriskyCredObject
Start-Sleep 30
Invoke-Command -VMName "Shop-Client" {cmdkey.exe /generic:TERMSRV/Shop-Client.shop.local /user:"shop\Frisky.McRisky" /pass:"LivinOnAPrayer!!!!"} -Credential $FriskyCredObject

#Put Frisky.McRisky's creds in a config file as well
Copy-VMFile "Shop-Client" -SourcePath ".\Shop_Wifi_Profile.xml" -DestinationPath "C:\Users\Frisky.McRisky\Desktop\Shop_Wifi_Profile.xml" -CreateFullPath -FileSource Host
Invoke-Command -VMName "Shop-Client" {netsh wlan add profile filename="C:\Users\Frisky.McRisky\Desktop\Shop_Wifi_Profile.xml" user=all} -Credential $FriskyCredObject

Invoke-Command -VMName "Shop-Client" {Remove-Item "C:\unattend.xml" ; Restart-Computer -Force} -Credential $ThirdDomainAdminCredObject
Start-Sleep -Seconds 120
Write-Host "The 3rd Forest is spun up and ready for action."


#Attacker will have to enumerate usernames, password spray, escalate to local admin, dump creds, take Shop-Client out of the staging group, then escalate domain privileges