Import-Module GroupPolicy

# Namn på GPO:er
$gpoFrName      = "NOV-FR-Users"
$gpoBgUserName  = "NOV-Wallpaper-Users"
$gpoBgAdminName = "NOV-Wallpaper-Admins"

# DN för OU:er
$ouUsersStandard = "OU=Standard,OU=Users,OU=Novatrix,DC=novatrix,DC=se"
$ouAdmins        = "OU=Admins,OU=Users,OU=Novatrix,DC=novatrix,DC=se"  # <-- rättad

function Link-GPO-ToOU {
    param(
        [Parameter(Mandatory=$true)][string]$GpoName,
        [Parameter(Mandatory=$true)][string]$OuDn,
        [int]$LinkOrder = 1
    )

    $gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        Write-Warning "GPO '$GpoName' hittades inte. Har du kört steg 1?"
        return
    }

    Write-Host "Länkar GPO '$GpoName' till '$OuDn'..." -ForegroundColor Cyan

    $existingLink = (Get-GPInheritance -Target $OuDn).GpoLinks |
                    Where-Object { $_.DisplayName -eq $GpoName }

    if ($existingLink) {
        Write-Host "Länk fanns redan. Justerar ev. ordning..." -ForegroundColor Yellow
        Set-GPLink -Name $GpoName -Target $OuDn -Order $LinkOrder
    }
    else {
        New-GPLink -Name $GpoName -Target $OuDn -LinkEnabled Yes -Order $LinkOrder
    }
}

# ===== Länka användargrejer =====
Link-GPO-ToOU -GpoName $gpoFrName     -OuDn $ouUsersStandard -LinkOrder 1
Link-GPO-ToOU -GpoName $gpoBgUserName -OuDn $ouUsersStandard -LinkOrder 2

# ===== Länka admin-bakgrund till Users\Admins =====
Link-GPO-ToOU -GpoName $gpoBgAdminName -OuDn $ouAdmins -LinkOrder 1

Write-Host ""
Write-Host "Klart med steg 2 (GPO-länkning)." -ForegroundColor Green
Write-Host " - '$gpoFrName' + '$gpoBgUserName' länkat till $ouUsersStandard"
Write-Host " - '$gpoBgAdminName' länkat till $ouAdmins"
