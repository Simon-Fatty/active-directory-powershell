Import-Module GroupPolicy

# ===== Grunddata =====
$domainName = "novatrix.se"

# Namn på GPO:er
$gpoFrName        = "NOV-FR-Users"          # Folder Redirection
$gpoBgUserName    = "NOV-Wallpaper-Users"   # Bakgrund för standardanvändare
$gpoBgAdminName   = "NOV-Wallpaper-Admins"  # Bakgrund för admins

# Sökvägar till bakgrundsbilder
$bgUserPath  = "\\novatrix.se\NETLOGON\bg_user.jpg"
$bgAdminPath = "\\novatrix.se\NETLOGON\bg_admin.jpg"

# ===== Funktion: skapa GPO om det saknas =====
function New-OrGet-GPO {
    param(
        [Parameter(Mandatory=$true)][string]$Name
    )
    $existing = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "GPO '$Name' finns redan. Använder befintligt." -ForegroundColor Yellow
        return $existing
    }
    else {
        Write-Host "Skapar GPO '$Name'..." -ForegroundColor Cyan
        return New-GPO -Name $Name -Comment "Skapad via script för Novatrix"
    }
}

# ===== 1) Skapa Folder Redirection-GPO =====
$gpoFr = New-OrGet-GPO -Name $gpoFrName
Write-Host "OBS: Själva Folder Redirection-inställningarna ställer du in i GPMC på GPO '$gpoFrName'." -ForegroundColor Magenta

# ===== 2) Skapa GPO för användarbakgrund =====
$gpoBgUser = New-OrGet-GPO -Name $gpoBgUserName

# Sätt policy: User Configuration -> Administrative Templates -> Desktop -> Desktop -> Desktop Wallpaper
# Motsvaras av reg-nyckel: HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System
$regKey = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System"

Write-Host "Konfigurerar bakgrundsbild för användare i GPO '$gpoBgUserName'..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $gpoBgUserName -Key $regKey -ValueName "Wallpaper" -Type String -Value $bgUserPath
# WallpaperStyle: 0 = Centered, 2 = Stretched (vanligast)
Set-GPRegistryValue -Name $gpoBgUserName -Key $regKey -ValueName "WallpaperStyle" -Type String -Value "2"
# TileWallpaper: 0 = No tiling
Set-GPRegistryValue -Name $gpoBgUserName -Key $regKey -ValueName "TileWallpaper" -Type String -Value "0"

# ===== 3) Skapa GPO för adminbakgrund =====
$gpoBgAdmin = New-OrGet-GPO -Name $gpoBgAdminName

Write-Host "Konfigurerar bakgrundsbild för admins i GPO '$gpoBgAdminName'..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $gpoBgAdminName -Key $regKey -ValueName "Wallpaper" -Type String -Value $bgAdminPath
Set-GPRegistryValue -Name $gpoBgAdminName -Key $regKey -ValueName "WallpaperStyle" -Type String -Value "2"
Set-GPRegistryValue -Name $gpoBgAdminName -Key $regKey -ValueName "TileWallpaper" -Type String -Value "0"

Write-Host ""
Write-Host "Klart med steg 1:" -ForegroundColor Green
Write-Host " - GPO '$gpoFrName' skapat (Folder Redirection – konfigurera i GPMC)."
Write-Host " - GPO '$gpoBgUserName' skapat + konfigurerat med $bgUserPath."
Write-Host " - GPO '$gpoBgAdminName' skapat + konfigurerat med $bgAdminPath."
