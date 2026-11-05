Import-Module ActiveDirectory

# Var gruppen ska ligga
$groupsOu = "OU=Security,OU=Groups,OU=Novatrix,DC=novatrix,DC=se"

# Gruppnamn
$groupName = "GG_LocalAdmins"
$groupSam  = $groupName

# Skapa gruppen om den inte finns
$group = Get-ADGroup -Filter "SamAccountName -eq '$groupSam'" -ErrorAction SilentlyContinue
if (-not $group) {
    Write-Host "Skapar grupp: $groupName i $groupsOu..." -ForegroundColor Cyan
    $group = New-ADGroup `
        -Name $groupName `
        -SamAccountName $groupSam `
        -GroupScope Global `
        -GroupCategory Security `
        -Path $groupsOu `
        -Description "Domängrupp för lokala Administrators på klienter"
}
else {
    Write-Host "Gruppen $groupName finns redan." -ForegroundColor Yellow
}

# Lägg in kontot local.admin i gruppen
$userSam = "local.admin"   # domänkontot

$user = Get-ADUser -Filter "SamAccountName -eq '$userSam'" -ErrorAction SilentlyContinue
if ($user) {
    try {
        Add-ADGroupMember -Identity $group -Members $user -ErrorAction Stop
        Write-Host "Lade till $userSam i $groupName." -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -like "*is already a member*") {
            Write-Host "$userSam är redan medlem i $groupName." -ForegroundColor Yellow
        }
        else {
            Write-Warning "Kunde inte lägga till $userSam i ${groupName}: $($_.Exception.Message)"
        }
    }
}
else {
    Write-Warning "Hittar inte användare med SamAccountName '$userSam'."
}
