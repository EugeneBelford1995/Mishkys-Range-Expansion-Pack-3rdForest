#Give Dan the rights to restart the computer

# Install the PSPrivilege module from the PowerShell Gallery
Install-Module -Name PSPrivilege -Force

# Get the user object for the account
$account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList 'research\dan'

# Add the SeShutdownPrivilege
Add-WindowsRight -Name "SeShutdownPrivilege" -Account $account.Translate([System.Security.Principal.SecurityIdentifier])

# Add the SeRemoteShutdownPrivilege
Add-WindowsRight -Name "SeRemoteShutdownPrivilege" -Account $account.Translate([System.Security.Principal.SecurityIdentifier])

# Verify the changes (optional)
Get-WindowsRight -Name "SeShutdownPrivilege"
Get-WindowsRight -Name "SeRemoteShutdownPrivilege"

# --- Give them a Vulnerable Service to abuse ---

# 1) Create folder for service binary
#$svcFolder = "C:\VulnService"
#New-Item -Path $svcFolder -ItemType Directory -Force | Out-Null

# 2) Copy a harmless executable to act as the service binary (placeholder)
# Using notepad.exe as placeholder; choose any benign exe present on the system
#Copy-Item "C:\Windows\System32\notepad.exe" -Destination "$svcFolder\VulnService.exe" -Force

# 3) Create the service (note sc.exe syntax requires the spaces after '=')
#sc.exe create VulnSvc binPath= "$svcFolder\VulnService.exe" DisplayName= "Vulnerable Test Service" start= auto
sc.exe create VulnSvc binPath= "$svcFolder\PsExec.exe" DisplayName= "Test Service" start= auto

# 4) Grant Non-admin users Modify rights on the folder so low-priv users can overwrite the exe
# This grants the built-in Users group Modify permissions (lab-only!)
#icacls $svcFolder /grant "Users:(M)" /T
#icacls $svcFolder /grant "research\dan:(OI)(CI)M" /T

#Give Dan the right to change his rights and overwrite the service *.exe with their own *.exe
Set-Location C:
$ACL = Get-Acl -Path "C:\VulnService"
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("research\dan”,”FullControl”,”Allow”)
$AccessRule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("research\dan”,”Modify”,”Deny”)
$ACL.SetAccessRule($AccessRule)
$ACL.SetAccessRule($AccessRule2)
$ACL | Set-Acl -Path "C:\VulnService"

# 5) Start the service
Start-Service -Name VulnSvc
Write-Host "Vulnerable service created and started. Service binary at $svcFolder\VulnService.exe"