<#
.SYNOPSIS
Create OUs, security groups and import users into child.novatrix.se from CSV.

USAGE
Run on a management server with RSAT installed and run as a user with privileges to create OUs, groups and users.
CSV expected at C:\Temp\V49-Users1.csv with headers: first_name,last_name,department
The script will create an OU for each department under "OU=Users,DC=child,DC=novatrix,DC=se".
#>

Import-Module ActiveDirectory -ErrorAction Stop

$CsvPath = "C:\Temp\V49-Users1.csv"
$BaseOU = "OU=Users,DC=child,DC=novatrix,DC=se"  # Change if you prefer another OU path
# Initial password is entered at runtime instead of being stored in the script.
$DefaultPassword = Read-Host -AsSecureString "Initial password for new users"

if (-Not (Test-Path $CsvPath)) {
    Write-Error "CSV not found at $CsvPath. Please place your CSV there and ensure headers: first_name,last_name,department"
    exit 1
}

$users = Import-Csv -Path $CsvPath

# Ensure base OU exists
if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$BaseOU'" -ErrorAction SilentlyContinue)) {
    Write-Host "Base OU $BaseOU does not exist. Creating it..." -ForegroundColor Yellow
    New-ADOrganizationalUnit -Name "Users" -Path "DC=child,DC=novatrix,DC=se"
}

# Create OUs for departments and create security groups
$createdGroups = @()

foreach ($u in $users) {
    $dept = ($u.department -replace '[^a-zA-Z0-9 _-]','').Trim()
    if ([string]::IsNullOrWhiteSpace($dept)) { $dept = "General" }
    $ouName = $dept
    $ouPath = "OU=$ouName,$BaseOU"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouPath'" -ErrorAction SilentlyContinue)) {
        Write-Host "Creating OU: $ouName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name $ouName -Path $BaseOU -ProtectedFromAccidentalDeletion $false
    }

    # Create a security group for department (Global, Security)
    $groupSam = ("GRP_" + ($dept -replace '\s+','_')).ToLower()
    if (-not (Get-ADGroup -Filter "SamAccountName -eq '$groupSam'" -ErrorAction SilentlyContinue)) {
        Write-Host "Creating group: $groupSam" -ForegroundColor Cyan
        New-ADGroup -Name $groupSam -SamAccountName $groupSam -GroupScope Global -GroupCategory Security -Path $ouPath
    }
    $createdGroups += $groupSam
}

# Create users and add to groups
foreach ($u in $users) {
    $first = $u.first_name.Trim()
    $last = $u.last_name.Trim()
    $dept = ($u.department -replace '[^a-zA-Z0-9 _-]','').Trim()
    if ([string]::IsNullOrWhiteSpace($dept)) { $dept = "General" }
    $ouPath = "OU=$dept,$BaseOU"
    $sam = ($first.Substring(0,1) + $last).ToLower() -replace '[^a-z0-9]',''
    $displayName = "$first $last"
    $userPrincipalName = "$sam@child.novatrix.se"

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Host "User $sam already exists. Skipping." -ForegroundColor Yellow
        continue
    }

    Write-Host "Creating user $displayName ($sam) in OU $ouPath" -ForegroundColor Green
    New-ADUser -Name $displayName `
        -GivenName $first `
        -Surname $last `
        -SamAccountName $sam `
        -UserPrincipalName $userPrincipalName `
        -DisplayName $displayName `
        -Path $ouPath `
        -AccountPassword $DefaultPassword `
        -Enabled $true `
        -ChangePasswordAtLogon $true

    # Add to department group
    $groupSam = ("GRP_" + ($dept -replace '\s+','_')).ToLower()
    try {
        Add-ADGroupMember -Identity $groupSam -Members $sam -ErrorAction Stop
    } catch {
        Write-Warning "Could not add $sam to ${groupSam}: $_"
    }
}

Write-Host "Done. Created/verified OUs, groups and imported users." -ForegroundColor Green
