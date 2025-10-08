$ADRoot = (Get-ADDomain).DistinguishedName
$FQDN = (Get-ADDomain).DNSRoot

#Store a password for users
[string]$DSRMPassword = 'SuperDuperExtraSafeDomainPassword12!@'
# Convert to SecureString
[securestring]$UserPassword = ConvertTo-SecureString $DSRMPassword -AsPlainText -Force

$User = "Break.Glass"

New-ADUser -SamAccountName $User -Name $User -UserPrincipalName "$User@$FQDN" -AccountPassword $UserPassword -Enabled $true -Description "Backup Ent Admin" -PasswordNeverExpires $true
Add-ADGroupMember -Identity "Enterprise Admins" -Members "$User"
Add-ADGroupMember -Identity "Domain Admins" -Members "$User"
Add-ADGroupMember -Identity "Schema Admins" -Members "$User"
Add-ADGroupMember -Identity "Administrators" -Members "$User"

New-ADOrganizationalUnit -Name "PlaceHolder" -Path "$ADRoot"
New-ADGroup "Server Admins" -GroupScope Universal -GroupCategory Security -Path "ou=PlaceHolder,$ADRoot"
New-ADGroup "Servers" -GroupScope Universal -GroupCategory Security -Path "ou=PlaceHolder,$ADRoot"
New-ADGroup "Staging" -GroupScope Universal -GroupCategory Security -Path "ou=PlaceHolder,$ADRoot"
New-ADComputer -Name "Shop-Client" -SAMAccountName "Shop-Client" -DisplayName "Shop-Client" -Path "ou=PlaceHolder,$ADRoot"
Add-ADGroupMember -Identity "Servers" -Members "Shop-Client"
Add-ADGroupMember -Identity "Staging" -Members "Shop-Client"

#Store a password for users
[string]$DSRMPassword = 'PasswordReuseIsFun!'
# Convert to SecureString
[securestring]$OtherUserPassword = ConvertTo-SecureString $DSRMPassword -AsPlainText -Force

$OtherUser = "Dan"
New-ADUser -SamAccountName $OtherUser -Name $OtherUser -UserPrincipalName "$OtherUser@$FQDN" -AccountPassword $OtherUserPassword -Enabled $true -Description "Server Admin Intern" -PasswordNeverExpires $true -Path "ou=PlaceHolder,$ADRoot"
Add-ADGroupMember -Identity "Server Admins" -Members "Dan" #This group will have WriteProperty Membership Property Set GUID over the group that's denied GPO rights

#Put Shop-Client in two groups; one is allowed GenericAll on a GPO (Servers) and the other (Staging) is denied GenericAll on the same GPO
#Create a GPO and apply it to the Domian Controllers OU. This will be the target GPO. Use the NTP GPO as an example, in fact I could use that one as is.

$victim = (Get-ADObject "<GPO>,$ADRoot" -Properties *).DistinguishedName
$acl = Get-ACL $victim
$user = New-Object System.Security.Principal.SecurityIdentifier (Get-ADGroup "Servers").SID
$user2 = New-Object System.Security.Principal.SecurityIdentifier (Get-ADGroup "Staging").SID
$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $user,"GenericAll","ALLOW",([GUID]("00000000-0000-0000-0000-000000000000")).guid,"None",([GUID]("00000000-0000-0000-0000-000000000000")).guid))
$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $user2,"GenericAll","DENY",([GUID]("00000000-0000-0000-0000-000000000000")).guid,"None",([GUID]("00000000-0000-0000-0000-000000000000")).guid))
#Apply above ACL rules
Set-ACL $victim $acl

#Dan's group Server Admins will have the right to add/remove users from the denied group (Staging) via WriteProperty Membership Set
$victim = (Get-ADGroup "Staging" -Properties *).DistinguishedName
$acl = Get-ACL $victim
$user = New-Object System.Security.Principal.SecurityIdentifier (Get-ADGroup "Server Admins").SID
$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $user,"GenericAll","ALLOW",([GUID]("00000000-0000-0000-0000-000000000000")).guid,"None",([GUID]("00000000-0000-0000-0000-000000000000")).guid))
#Apply above ACL rules
Set-ACL $victim $acl
