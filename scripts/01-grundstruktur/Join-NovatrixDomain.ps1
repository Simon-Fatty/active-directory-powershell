param(
    [string]$DomainName = "novatrix.se",
    [string]$DomainUser = "NOVATRIX\domainadmin"
)

Write-Host "=== Joinar dator till domänen $DomainName ===" -ForegroundColor Cyan

# Hämta datorinfo
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem

# Kontroll 1: redan i domän?
if ($cs.PartOfDomain -eq $true) {
    Write-Warning "Datorn är redan medlem i domänen: $($cs.Domain). Avbryter."
    return
}

# Avgör om det är klient eller server
$isClient = $os.Caption -match "Windows 10|Windows 11"
$isServer = $os.Caption -match "Windows Server"

if ($isClient) {
    Write-Host "Identifierad som klient-OS: $($os.Caption)" -ForegroundColor Yellow
    $OuPath = "OU=Workstations,OU=Clients,OU=Novatrix,DC=novatrix,DC=se"
}
elseif ($isServer) {
    Write-Host "Identifierad som server-OS: $($os.Caption)" -ForegroundColor Yellow
    $OuPath = "OU=Servers,OU=Clients,OU=Novatrix,DC=novatrix,DC=se"
}
else {
    Write-Host "OS kunde inte identifieras säkert. Antar att det är ett klient-OS." -ForegroundColor Yellow
    $OuPath = "OU=Workstations,OU=Clients,OU=Novatrix,DC=novatrix,DC=se"
}

Write-Host "Dator kommer placeras i OU:" -ForegroundColor Cyan
Write-Host "  $OuPath"

# ===== Fråga om namnbyte =====
$currentName = $env:COMPUTERNAME
Write-Host "`nNuvarande datornamn är: $currentName" -ForegroundColor Cyan
$rename = Read-Host "Vill du döpa om datorn? (J/N)"

if ($rename -match '^[Jj]') {
    $newName = Read-Host "Skriv in nytt datornamn"
    if (-not $newName -or $newName.Trim().Length -eq 0) {
        Write-Host "Inget nytt namn angavs. Behåller nuvarande namn." -ForegroundColor Yellow
        $newName = $currentName
    }
    else {
        Write-Host "Datorn kommer döpas om till: $newName" -ForegroundColor Green
    }
}
else {
    Write-Host "Behåller nuvarande namn." -ForegroundColor Yellow
    $newName = $currentName
}

# ===== Ber om lösenord =====
Write-Host "`nAnge lösenord för ${DomainUser}:" -ForegroundColor Yellow
$securePassword = Read-Host -AsSecureString "Lösenord"
$cred = New-Object System.Management.Automation.PSCredential($DomainUser, $securePassword)

# ===== Join the domain =====
try {
    Write-Host "`nFörsöker joina $DomainName..." -ForegroundColor Cyan
    Add-Computer `
        -DomainName $DomainName `
        -OUPath $OuPath `
        -Credential $cred `
        -NewName $newName `
        -ErrorAction Stop

    Write-Host "`nDatorn är nu ansluten till domänen och placerad i:" -ForegroundColor Green
    Write-Host "  $OuPath"
    Write-Host "`nEn omstart krävs för att slutföra." -ForegroundColor Yellow

    $restart = Read-Host "Vill du starta om nu? (J/N)"

    if ($restart -match '^[Jj]') {
        Restart-Computer -Force
    }
    else {
        Write-Host "OK, starta om manuellt senare." -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Misslyckades med att joina domänen: $($_.Exception.Message)"
}
