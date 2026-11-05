param(
    [string]$GroupName = "GG_LocalAdmins",
    [string]$LogPath   = "C:\JIT-Logs"
)

Import-Module ActiveDirectory

# Kontrollera att loggmappen finns
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory | Out-Null
}

Write-Host "=== JIT: Tillfällig lokal admin ===" -ForegroundColor Cyan

# --- Välj användare ---
$userSam = Read-Host "Ange användarnamn (SamAccountName), t.ex. test.user"
if (-not $userSam) {
    Write-Warning "Inget användarnamn angivet. Avbryter."
    exit
}

$user = Get-ADUser -Filter "SamAccountName -eq '$userSam'" -ErrorAction SilentlyContinue
if (-not $user) {
    Write-Error "Hittar ingen användare med SamAccountName '$userSam'"
    exit
}

Write-Host "Vald användare: $($user.SamAccountName) ($($user.Name))" -ForegroundColor Green

# --- Välj antal minuter ---
$minutes = Read-Host "Hur många minuter ska användaren vara lokal admin?"
if (-not ($minutes -as [int]) -or $minutes -le 0) {
    Write-Warning "Ogiltigt värde. Avbryter."
    exit
}
# Read-Host returnerar en sträng; utan omvandling till heltal kraschar $i-- i nedräkningen
$minutes = [int]$minutes

# --- Hämta gruppen ---
$group = Get-ADGroup -Filter "SamAccountName -eq '$GroupName'" -ErrorAction SilentlyContinue
if (-not $group) {
    Write-Error "Gruppen $GroupName finns inte! Skapa den först."
    exit
}

# --- Lägg till användaren ---
try {
    Add-ADGroupMember -Identity $group -Members $user -ErrorAction Stop
    Write-Host "`n>>> $userSam lades till i $GroupName" -ForegroundColor Green

    # Logging
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp : ADDED $userSam to $GroupName for $minutes minutes" |
        Out-File "$LogPath\JIT-Log.txt" -Append
}
catch {
    if ($_.Exception.Message -like "*is already a member*") {
        Write-Host "`n$userSam är redan medlem i $GroupName." -ForegroundColor Yellow
    }
    else {
        Write-Error "Kunde inte lägga till användaren: $($_.Exception.Message)"
        exit
    }
}

Write-Host "`nVäntar i $minutes minuter..." -ForegroundColor Cyan

# --- Nedräkning ---
for ($i = $minutes; $i -gt 0; $i--) {
    Write-Progress -Activity "JIT Local Admin" `
        -Status "$i minuter kvar" `
        -PercentComplete ((($minutes - $i) / $minutes) * 100)
    Start-Sleep -Seconds 60
}

# --- Ta bort användaren igen ---
try {
    Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false -ErrorAction Stop
    Write-Host "`n>>> $userSam har tagits bort från $GroupName" -ForegroundColor Green

    # Logging
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp : REMOVED $userSam from $GroupName" |
        Out-File "$LogPath\JIT-Log.txt" -Append
}
catch {
    Write-Warning "Kunde inte ta bort användaren automatiskt: $($_.Exception.Message)"
}

Write-Host "`nJIT-perioden är avslutad." -ForegroundColor Cyan
