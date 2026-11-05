# Root-OU
New-ADOrganizationalUnit -Name "Novatrix" -Path "DC=novatrix,DC=se"

# Clients
New-ADOrganizationalUnit -Name "Clients" -Path "OU=Novatrix,DC=novatrix,DC=se"
New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Clients,OU=Novatrix,DC=novatrix,DC=se"
New-ADOrganizationalUnit -Name "Servers" -Path "OU=Clients,OU=Novatrix,DC=novatrix,DC=se"

# Users
New-ADOrganizationalUnit -Name "Users" -Path "OU=Novatrix,DC=novatrix,DC=se"
New-ADOrganizationalUnit -Name "Standard" -Path "OU=Users,OU=Novatrix,DC=novatrix,DC=se"

# Admins
New-ADOrganizationalUnit -Name "Admins" -Path "OU=Novatrix,DC=novatrix,DC=se"

# Service Accounts
New-ADOrganizationalUnit -Name "ServiceAccounts" -Path "OU=Novatrix,DC=novatrix,DC=se"

# Groups
New-ADOrganizationalUnit -Name "Groups" -Path "OU=Novatrix,DC=novatrix,DC=se"
New-ADOrganizationalUnit -Name "Security" -Path "OU=Groups,OU=Novatrix,DC=novatrix,DC=se"
New-ADOrganizationalUnit -Name "Distribution" -Path "OU=Groups,OU=Novatrix,DC=novatrix,DC=se"
