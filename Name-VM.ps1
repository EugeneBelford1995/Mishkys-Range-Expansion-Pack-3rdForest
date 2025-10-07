#VM's initial local admin:
[string]$userName = "Changme\Administrator"
[string]$userPassword = 'SuperSecureLocalPassword123!@#'
# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$InitialCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

Function Name-VM
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $VMName,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $NewName
    )

Invoke-Command -VMName $VMName -ScriptBlock {`
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes ; `
`
` #Disable IPv6 
$NIC = (Get-NetAdapter).InterfaceAlias ; `
Disable-NetAdapterBinding -InterfaceAlias $NIC -ComponentID ms_tcpip6 ; `
`
Install-WindowsFeature -Name "RSAT" -IncludeAllSubFeature ; `
Rename-Computer -NewName "$using:NewName" -PassThru -Restart -Force `
} -Credential $InitialCredObject `
}