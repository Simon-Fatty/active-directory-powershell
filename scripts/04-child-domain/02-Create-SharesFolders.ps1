<#
.SYNOPSIS
Create file shares for Gemensam and per-department, set NTFS permissions and enable Access-Based Enumeration (ABE).

USAGE
Run on the file server (e.g. CH-DC01) as an administrator.
Change $ShareRoot if you prefer a different path.
#>

$ShareRoot = "D:\Shares\V49"   # Change as needed
$Domain = "child.novatrix.se"
$DomainNetBIOS = "CHILD"       # Change to your domain's NetBIOS name (used in DOMAIN\Group references)
$FileServerNetBIOS = "CH-DC01" # Change to your file server's NETBIOS name if different

# Ensure folder root
if (-not (Test-Path $ShareRoot)) {
    New-Item -Path $ShareRoot -ItemType Directory -Force | Out-Null
}

# Create Gemensam share
$gemPath = Join-Path $ShareRoot "Gemensam"
if (-not (Test-Path $gemPath)) { New-Item -Path $gemPath -ItemType Directory -Force | Out-Null }

# Remove existing share if any, then create SMB share with ABE
if (Get-SmbShare -Name "Gemensam" -ErrorAction SilentlyContinue) { Remove-SmbShare -Name "Gemensam" -Force }
New-SmbShare -Name "Gemensam" -Path $gemPath -FullAccess "$DomainNetBIOS\Domain Admins" -ChangeAccess "$DomainNetBIOS\Domain Users" -FolderEnumerationMode AccessBased

# Create department shares
Import-Module ActiveDirectory -ErrorAction Stop
$groups = Get-ADGroup -Filter 'SamAccountName -like "GRP_*"' -Properties SamAccountName | Select-Object -ExpandProperty SamAccountName

foreach ($g in $groups) {
    # Derive folder name from group name GRP_department_name -> department_name
    $dept = $g -replace '^grp_','' -replace '_',' '
    $deptFolder = $g -replace '^grp_',''
    $path = Join-Path $ShareRoot $deptFolder
    if (-not (Test-Path $path)) { New-Item -Path $path -ItemType Directory -Force | Out-Null }

    # Set NTFS permissions
    $acl = Get-Acl $path
    $acl.SetAccessRuleProtection($true, $false) # Disable inheritance
    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$DomainNetBIOS\Domain Admins","FullControl","ContainerInherit,ObjectInherit","None","Allow")
    $groupRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$DomainNetBIOS\$g","Modify","ContainerInherit,ObjectInherit","None","Allow")
    $domainUsersRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$DomainNetBIOS\Domain Users","ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow")
    $acl.ResetAccessRule($adminRule)
    $acl.AddAccessRule($adminRule)
    $acl.AddAccessRule($groupRule)
    $acl.AddAccessRule($domainUsersRule)
    Set-Acl -Path $path -AclObject $acl

    # Create SMB share with ABE
    $shareName = $deptFolder
    if (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue) { Remove-SmbShare -Name $shareName -Force }
    New-SmbShare -Name $shareName -Path $path -FullAccess "$DomainNetBIOS\Domain Admins" -ChangeAccess "$DomainNetBIOS\$g" -FolderEnumerationMode AccessBased
    Write-Host "Created share: $shareName -> $path"
}

Write-Host "Shares and permissions created. Gemensam available as \\\\$FileServerNetBIOS\\Gemensam" -ForegroundColor Green
