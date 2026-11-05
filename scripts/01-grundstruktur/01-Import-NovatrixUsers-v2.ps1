param( #har rätt path
    [string]$CsvPath = "C:\Temp\novatrix_users.csv"
)

Import-Module ActiveDirectory

# --- Inställningar för din miljö ---
$DomainName      = "dindomän.local" # KOM IHÅG: Ändra till ditt domännamn!
$UsersOU         = "OU=Standard,OU=Users,OU=TempAD,DC=dindomän,DC=local"
$GroupsOU        = "OU=Security,OU=Groups,OU=TempAD,DC=dindomän,DC=local"
# Startlösenordet anges vid körning i stället för att stå i klartext i skriptet.
$securePassword  = Read-Host -AsSecureString "Startlösenord för nya användare"

# --- Hjälpfunktioner (Samma som innan) ---
function Remove-Diacritics {
    param([string]$Text)
    if (-not $Text) { return $Text }
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($c)
        }
    }
    return $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function Get-UniqueSamAccountName {
    param([string]$BaseSam)
    $sam = $BaseSam
    $i = 1
    while (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        $sam = "$BaseSam$i"
        $i++
    }
    return $sam
}

# --- Läs in CSV med rätt separator (SEMIKOLON) ---
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV-fil hittas inte: $CsvPath"
    exit 1
}

# HÄR ÄR FIXEN: Vi lägger till -Delimiter ';'
$users = Import-Csv -Path $CsvPath -Delimiter ';'

foreach ($row in $users) {
    # HÄR ÄR FIXEN: Vi mappar om rubrikerna från din CSV (Förnamn, Efternamn, Avdelning)
    $givenName  = $row.Förnamn
    $surname    = $row.Efternamn
    $department = $row.Avdelning

    if (-not $givenName -or -not $surname) {
        Write-Warning "Rad saknar förnamn eller efternamn, hoppar över. Kontrollera rubrikerna i CSV-filen."
        continue
    }

    $cleanGiven  = Remove-Diacritics $givenName
    $cleanSurname = Remove-Diacritics $surname
    $baseSam = ("{0}.{1}" -f $cleanGiven, $cleanSurname).ToLower()
    $baseSam = $baseSam -replace '[^a-z0-9\.]', ''

    $samAccountName = Get-UniqueSamAccountName -BaseSam $baseSam
    $userPrincipalName = "$samAccountName@$DomainName"
    $displayName = "$givenName $surname"

    if (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) {
        Write-Warning "Användare '$samAccountName' finns redan."
    }
    else {
        Write-Host "Skapar användare: $displayName ($samAccountName)"

        New-ADUser `
            -Name $displayName `
            -GivenName $givenName `
            -Surname $surname `
            -SamAccountName $samAccountName `
            -UserPrincipalName $userPrincipalName `
            -DisplayName $displayName `
            -Path $UsersOU `
            -AccountPassword $securePassword `
            -Enabled $true `
            -ChangePasswordAtLogon $true
    }

    # --- Grupphantering ---
    if ($department) {
        $cleanDept = Remove-Diacritics $department
        $groupName = "GG_$($cleanDept.Trim() -replace '\s+', '_')"

        if (-not (Get-ADGroup -Filter "SamAccountName -eq '$groupName'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $groupName -SamAccountName $groupName -GroupScope Global -GroupCategory Security -Path $GroupsOU -Description "Avdelning $department"
            Write-Host "Skapade gruppen $groupName"
        }

        Add-ADGroupMember -Identity $groupName -Members $samAccountName -ErrorAction SilentlyContinue
    }
}