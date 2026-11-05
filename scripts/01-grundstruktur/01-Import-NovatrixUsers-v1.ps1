param(
    [string]$CsvPath = "C:\Temp\novatrix_users.csv"
)

Import-Module ActiveDirectory

# --- Inställningar för din miljö ---
$DomainName      = "novatrix.se"
$UsersOU         = "OU=Standard,OU=Users,OU=Novatrix,DC=novatrix,DC=se"
$GroupsOU        = "OU=Security,OU=Groups,OU=Novatrix,DC=novatrix,DC=se"
# Startlösenordet anges vid körning i stället för att stå i klartext i skriptet.
# Användaren måste byta det vid första inloggning (-ChangePasswordAtLogon).
$securePassword  = Read-Host -AsSecureString "Startlösenord för nya användare"

# --- Hjälpfunktion: ta bort åäö/accents etc ---
function Remove-Diacritics {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )

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

# --- Hjälpfunktion: skapa unikt samAccountName ---
function Get-UniqueSamAccountName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BaseSam
    )

    $sam = $BaseSam
    $i = 1
    while (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        $sam = "$BaseSam$i"
        $i++
    }
    return $sam
}

# --- Läs in CSV ---
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV-fil hittas inte: $CsvPath"
    exit 1
}

$users = Import-Csv -Path $CsvPath

foreach ($row in $users) {
    # Anpassa dessa tre rader om dina kolumnnamn skiljer sig:
    $givenName  = $row.GivenName
    $surname    = $row.Surname
    $department = $row.Department

    if (-not $givenName -or -not $surname) {
        Write-Warning "Rad saknar förnamn eller efternamn, hoppar över: $($row | Out-String)"
        continue
    }

    # Rensa bort diakritiska tecken (åäö osv) för användarnamn
    $cleanGiven  = Remove-Diacritics $givenName
    $cleanSurname = Remove-Diacritics $surname

    # Bygg användarnamn: förnamn.efternamn, små bokstäver, bara a-z0-9 och punkt
    $baseSam = ("{0}.{1}" -f $cleanGiven, $cleanSurname).ToLower()
    $baseSam = $baseSam -replace '[^a-z0-9\.]', ''  # ta bort mellanslag, bindestreck osv

    if (-not $baseSam) {
        Write-Warning "Kunde inte skapa samAccountName för rad: $($row | Out-String)"
        continue
    }

    $samAccountName = Get-UniqueSamAccountName -BaseSam $baseSam
    $userPrincipalName = "$samAccountName@$DomainName"
    $displayName = "$givenName $surname"
    $name        = $displayName  # CN

    # Skapa användaren om den inte redan finns
    $existingUser = Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Warning "Användare med samAccountName '$samAccountName' finns redan. Hoppar över."
    }
    else {
        Write-Host "Skapar användare: $displayName ($samAccountName)"

        New-ADUser `
            -Name $name `
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

    # --- Hantera avdelningsgrupp ---
    if ($department) {
        # Ta bort diakritik och gör ett "snyggt" gruppnamn
        $cleanDept = Remove-Diacritics $department
        $cleanDept = $cleanDept.Trim()
        # Ersätt mellanslag med underscore och plocka bort konstiga tecken
        $cleanDeptId = $cleanDept -replace '\s+', '_' -replace '[^a-zA-Z0-9_]', ''

        if (-not $cleanDeptId) {
            Write-Warning "Kunde inte skapa gruppnamn från avdelning '$department' för användare $displayName"
            continue
        }

        $groupName = "GG_$cleanDeptId"         # t.ex. GG_IT, GG_Ekonomi
        $groupSam  = $groupName
        $groupPath = $GroupsOU

        # Finns gruppen redan?
        $group = Get-ADGroup -Filter "SamAccountName -eq '$groupSam'" -ErrorAction SilentlyContinue
        if (-not $group) {
            Write-Host "Skapar grupp: $groupName i $groupPath (Department: $department)"

            $group = New-ADGroup `
                -Name $groupName `
                -SamAccountName $groupSam `
                -GroupScope Global `
                -GroupCategory Security `
                -Path $groupPath `
                -Description "Avdelningsgrupp för $department"
        }

        # Lägg användaren i gruppen
        $user = Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue
        if ($user) {
            try {
                Add-ADGroupMember -Identity $group.DistinguishedName -Members $user.DistinguishedName -ErrorAction Stop
                Write-Host "Lade till $($user.SamAccountName) i gruppen $groupName"
            }
            catch {
                if ($_.Exception.Message -like "*is already a member*") {
                    Write-Host "$($user.SamAccountName) är redan medlem i $groupName"
                }
                else {
                    Write-Warning "Kunde inte lägga till $($user.SamAccountName) i ${groupName}: $($_.Exception.Message)"
                }
            }
        }
        else {
            Write-Warning "Hittar inte användare $samAccountName när gruppmedlemskap skulle sättas."
        }
    }
    else {
        Write-Warning "Ingen avdelning angiven för användare $displayName – ingen grupp sätts."
    }
}
