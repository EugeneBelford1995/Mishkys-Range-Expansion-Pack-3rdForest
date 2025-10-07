#shop.local Ent Admin:
[string]$userName = "shop\Break.Glass"
[string]$userPassword = 'SuperDuperExtraSafeDomainPassword12!@'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$ThirdDomainAdminCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

#VM's initial local admin:
[string]$userName = "Changme\Administrator"
[string]$userPassword = 'SuperSecureLocalPassword123!@#'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$InitialCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

#Get the IP scheme, GW, & CIDR from Shop-DC. Shop-DC got it's config from DHCP and then changed its own last octet to 150
$NIC = Invoke-Command -VMName "Shop-DC" {(Get-NetIPConfiguration).InterfaceAlias} -Credential $ThirdDomainAdminCredObject
$DC_GW = Invoke-Command -VMName "Shop-DC" {(Get-NetIPConfiguration -InterfaceAlias (Get-NetAdapter).InterfaceAlias).IPv4DefaultGateway.NextHop} -Credential $ThirdDomainAdminCredObject
$DC_IP = Invoke-Command -VMName "Shop-DC" {(Get-NetIPAddress | Where-Object {$_.InterfaceAlias -eq "$using:NIC"}).IPAddress} -Credential $ThirdDomainAdminCredObject
#$DC_Prefix = Invoke-Command -VMName "Shop-DC" {(Get-NetIPAddress | Where-Object {$_.IPAddress -like "*172*"}).PrefixLength} -Credential $ThirdDomainAdminCredObject
$DC_Prefix = Invoke-Command -VMName "Shop-DC" {(Get-NetIPAddress | Where-Object {$_.InterfaceAlias -eq "$using:NIC"}).PrefixLength} -Credential $ThirdDomainAdminCredObject
$FirstOctet =  $DC_IP.Split("\.")[0]
$SecondOctet = $DC_IP.Split("\.")[1]
$ThirdOctet = $DC_IP.Split("\.")[2]
$NetworkPortion = "$FirstOctet.$SecondOctet.$ThirdOctet"
$Gateway = $DC_GW
#$NIC = (Get-NetAdapter).InterfaceAlias

Function Config-NIC
{
    Param
    (
    [Parameter(Mandatory=$true, Position=0)]
    [string] $VMName,
    [Parameter(Mandatory=$true, Position=1)]
    [string] $IP
    )
$IP = "$NetworkPortion.$IP"

#This is here for de-bugging purposes, feel free to remove it once everything is tested & verified
Write-Host "Configuring $VMName to use IP $IP, Gateway $Gateway, and Prefix $DC_Prefix"

#Set IPv4 address, gateway, & DNS servers
Invoke-Command -VMName "$VMName" {$NIC = (Get-NetAdapter).InterfaceAlias ; Disable-NetAdapterBinding -InterfaceAlias $NIC -ComponentID ms_tcpip6} -Credential $InitialCredObject
Invoke-Command -VMName "$VMName" {$NIC = (Get-NetAdapter).InterfaceAlias ; New-NetIPAddress -InterfaceAlias $NIC -AddressFamily IPv4 -IPAddress $using:IP -PrefixLength $using:DC_Prefix -DefaultGateway $using:Gateway} -Credential $InitialCredObject
Invoke-Command -VMName "$VMName" {$NIC = (Get-NetAdapter).InterfaceAlias ; Set-DNSClientServerAddress -InterfaceAlias $NIC -ServerAddresses ("$using:NetworkPortion.145", "$using:NetworkPortion.140", "$using:NetworkPortion.141", "1.1.1.1", "8.8.8.8")} -Credential $InitialCredObject
} #Close Config-NIC function