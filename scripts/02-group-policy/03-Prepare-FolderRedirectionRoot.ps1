param(
    [string]$ShareName = "Shared",
    [string]$NewFolderName = "Redirected",
    [string]$DomainNetbiosName = "NOVATRIX"
)

Write-Host "=== Förbereder Folder Redirection-root ===" -ForegroundColor Cyan
Write-Host "Share: $ShareName"
Write-Host "Ny undermapp: $NewFolderName"
Write-Host ""

Import-Module SmbShare

# 1. Hitta fysisk sökväg till sharen "Shared"
$share = Get-SmbShare -Name $ShareName -ErrorAction Stop
$sharePath = $share.Path
Write-Host "Share '$ShareName' pekar på: $sharePath"

# 2. Bygg sökvägen till Redirected
$rootPath = Join-Path -Path $sharePath -ChildPath $NewFolderName
Write-Host "Folder Redirection-root blir: $rootPath"

# 3. Skapa mappen om den inte finns
if (-not (Test-Path $rootPath)) {
    Write-Host "Mappen finns inte. Skapar..." -ForegroundColor Yellow
    New-Item -Path $rootPath -ItemType Directory -Force | Out-Null
} else {
    Write-Host "Mappen finns redan." -ForegroundColor Green
}

# 4. Sätt NTFS-rättigheter
Write-Host "Sätter NTFS-rättigheter..." -ForegroundColor Cyan

# Hämta nuvarande ACL
$acl = Get-Acl -Path $rootPath

# Stäng av ärvning och ta bort befintliga regler
$acl.SetAccessRuleProtection($true, $false)  # disable inheritance, don't keep inherited rules
foreach ($rule in $acl.Access) {
    $acl.RemoveAccessRule($rule) | Out-Null
}

# Hjälpvariabler för rättigheter
$fsRightFull        = [System.Security.AccessControl.FileSystemRights]::FullControl
$fsRightReadExec    = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
$fsRightCreateDir   = [System.Security.AccessControl.FileSystemRights]::CreateDirectories

$inheritContainerObject = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
$inheritNone            = [System.Security.AccessControl.InheritanceFlags]::None

$propNone = [System.Security.AccessControl.PropagationFlags]::None
$propInheritOnly = [System.Security.AccessControl.PropagationFlags]::InheritOnly

$allow = [System.Security.AccessControl.AccessControlType]::Allow

# Konton/grupper
$domainAdmins = "$DomainNetbiosName\Domain Admins"
$system       = "NT AUTHORITY\SYSTEM"
$creatorOwner = "CREATOR OWNER"
$authUsers    = "Authenticated Users"

# SYSTEM – Full Control på allt under
$ruleSystem = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $system, $fsRightFull, $inheritContainerObject, $propNone, $allow
)
$acl.AddAccessRule($ruleSystem) | Out-Null

# Domain Admins – Full Control på allt under
$ruleDA = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $domainAdmins, $fsRightFull, $inheritContainerObject, $propNone, $allow
)
$acl.AddAccessRule($ruleDA) | Out-Null

# CREATOR OWNER – Full Control på underobjekt (inte på rotmappen själv)
$ruleCreator = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $creatorOwner, $fsRightFull, $inheritContainerObject, $propInheritOnly, $allow
)
$acl.AddAccessRule($ruleCreator) | Out-Null

# Authenticated Users – Read & Execute på själva rotmappen (This folder only)
$ruleAuthRead = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $authUsers, $fsRightReadExec, $inheritNone, $propNone, $allow
)
$acl.AddAccessRule($ruleAuthRead) | Out-Null

# Authenticated Users – CreateDirectories på rotmappen (så de kan skapa sin egen mapp)
$ruleAuthCreateDir = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $authUsers, $fsRightCreateDir, $inheritNone, $propNone, $allow
)
$acl.AddAccessRule($ruleAuthCreateDir) | Out-Null

# Skriv tillbaka ACL
Set-Acl -Path $rootPath -AclObject $acl

Write-Host ""
Write-Host "Klart! NTFS-rättigheter satta på $rootPath" -ForegroundColor Green
Write-Host "Kontrollera gärna i GUI att det ser ut som du förväntar dig."
