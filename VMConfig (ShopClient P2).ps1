#shop.local Ent Admin:
[string]$userName = "shop\Break.Glass"
[string]$userPassword = 'SuperDuperExtraSafeDomainPassword12!@'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

If($env:USERDOMAIN -ne "shop")
{
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
Add-Computer -DomainName shop.local -Credential $credObject -Restart -Force
}

Else{Write-Host "System is already on the domain." | Out-Null}