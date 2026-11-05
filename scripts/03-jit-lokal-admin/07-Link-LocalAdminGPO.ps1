Import-Module GroupPolicy

$gpoName = "NOV-LocalAdmins-Clients"
$targetOu = "OU=Workstations,OU=Clients,OU=Novatrix,DC=novatrix,DC=se"

# Skapa GPO om det saknas
$gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
if (-not $gpo) {
    Write-Host "Skapar GPO '$gpoName'..." -ForegroundColor Cyan
    $gpo = New-GPO -Name $gpoName -Comment "Sätter GG_LocalAdmins som lokal admin på klienter"
} else {
    Write-Host "GPO '$gpoName' finns redan." -ForegroundColor Yellow
}

# Länka till OU=Workstations
New-GPLink -Name $gpoName -Target $targetOu -Enforced No -LinkEnabled Yes
Write-Host "Länkade GPO '$gpoName' till $targetOu." -ForegroundColor Green





# In GPMC, Open the GPO NOV-LocalAdmins-Clients
# Browse to path
#   Computer Configuration → Preferences → Control Panel Settings → Local Users and Groups
#
# Add new local group
# Select Action Update and choose Administrators (built-in)
#
# Add NOVATRIX\GG_LocalAdmins
#
