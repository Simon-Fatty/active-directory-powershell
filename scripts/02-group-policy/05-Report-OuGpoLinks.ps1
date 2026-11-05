param(
    [string]$RootOuDn = "OU=Novatrix,DC=novatrix,DC=se",
    [string]$ReportPath = "C:\Temp\Novatrix_GpoLinks.csv"
)

Import-Module ActiveDirectory
Import-Module GroupPolicy

Write-Host "=== GPO-länkar per OU under $RootOuDn ===" -ForegroundColor Cyan

# Se till att katalogen för rapporten finns
$reportDir = Split-Path -Path $ReportPath -Parent
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

# Hämta root-OU + alla underliggande OU:er
$rootOu = Get-ADOrganizationalUnit -Identity $RootOuDn -ErrorAction Stop
$subOus = Get-ADOrganizationalUnit -SearchBase $RootOuDn -SearchScope Subtree -Filter *

$allOus = @($rootOu) + $subOus | Sort-Object DistinguishedName

$result = @()

foreach ($ou in $allOus) {
    Write-Host ""
    Write-Host "OU: $($ou.Name)  ($($ou.DistinguishedName))" -ForegroundColor Yellow

    $inheritance = Get-GPInheritance -Target $ou.DistinguishedName

    if (-not $inheritance.GpoLinks -or $inheritance.GpoLinks.Count -eq 0) {
        Write-Host "  Inga GPO-länkar." -ForegroundColor DarkGray
        continue
    }

    $inheritance.GpoLinks |
        Sort-Object Order |
        ForEach-Object {
            $linkInfo = [PSCustomObject]@{
                OU_Name        = $ou.Name
                OU_DN          = $ou.DistinguishedName
                GPO_DisplayName= $_.DisplayName
                GPO_Enabled    = $_.Enabled
                GPO_Enforced   = $_.Enforced
                Link_Order     = $_.Order
            }

            $result += $linkInfo

            Write-Host ("  [{0}] GPO: {1} (Enabled={2}, Enforced={3})" -f `
                $_.Order, $_.DisplayName, $_.Enabled, $_.Enforced)
        }
}

# Exportera till CSV
$result | Sort-Object OU_DN, Link_Order | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Rapport klar: $ReportPath" -ForegroundColor Green
Write-Host "Öppna i Excel för att få en bra översikt."
