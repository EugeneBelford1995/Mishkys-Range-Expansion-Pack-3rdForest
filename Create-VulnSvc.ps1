#Give Dan the rights to restart the computer

# Install the PSPrivilege module from the PowerShell Gallery
Install-Module -Name PSPrivilege -Force

# Get the user object for the account
$account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList 'shop\dan'

# Add the SeShutdownPrivilege
Add-WindowsRight -Name "SeShutdownPrivilege" -Account $account.Translate([System.Security.Principal.SecurityIdentifier])

# Add the SeRemoteShutdownPrivilege
Add-WindowsRight -Name "SeRemoteShutdownPrivilege" -Account $account.Translate([System.Security.Principal.SecurityIdentifier])

# Verify the changes (optional)
Get-WindowsRight -Name "SeShutdownPrivilege"
Get-WindowsRight -Name "SeRemoteShutdownPrivilege"

# --- Give them a Vulnerable Service to abuse ---

#Create the service
sc.exe create "VulnSvc" binPath= "C:\VulnService\PsExec.exe" DisplayName= "Test Service" start= auto

#Give Dan rights to abuse the service via icacls
#icacls "C:\VulnService" /grant "shop\dan:(OI)(CI)F" /T

#Give Dan the right to change his rights and overwrite the service *.exe with their own *.exe
Set-Location C:
$ACL = Get-Acl -Path "C:\VulnService"
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("shop\dan”,”FullControl”,”Allow”)
$AccessRule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("shop\dan”,”Write”,”Deny”)
$ACL.SetAccessRule($AccessRule)
$ACL.SetAccessRule($AccessRule2)
$ACL | Set-Acl -Path "C:\VulnService"

#Start the service
#Start-Service -Name VulnSvc