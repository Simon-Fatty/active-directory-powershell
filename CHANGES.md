# Ändringar vid portföljarbetet

Repot byggdes i oktober 2026 av mitt material från Active Directory-kursen (nov–dec 2025). Den här filen skiljer det ursprungliga arbetet från det som ändrats efteråt.

## 1. Sanering

Skripten är mina original med bara dessa ändringar:

- Hårdkodade startlösenord i tre importskript ersattes med `Read-Host -AsSecureString`.
- Ett personnamn i skript 08 och 09 ersattes med `test.user`.
- Filerna sparades som UTF-8 med BOM, så att å, ä och ö visas rätt i Windows PowerShell 5.1.

Rapporterna publiceras inte som de är. Innehållet är omskrivet till Markdown utan gruppmedlemmarnas namn, lösenord eller lärarens uppgiftstext.

Skärmbilderna är tagna ur grupprapporten. I tre av dem har jag beskurit eller maskerat:

- värddatorns namn i en titelrad (04)
- ett mappnamn (07)
- gruppens SID (15)

## 2. Ny mappstruktur

Skripten flyttades och döptes om. Innehållet ändrades inte i det steget.

| Ursprungligt namn | Nytt namn |
| --- | --- |
| `00 - Create_OUs.ps1` | `scripts/01-grundstruktur/00-Create-OUs.ps1` |
| `01 - Import-NovatrixUsers.ps1` | `scripts/01-grundstruktur/01-Import-NovatrixUsers-v1.ps1` |
| `01 - Import-NovatrixUsers - V2.ps1` | `scripts/01-grundstruktur/01-Import-NovatrixUsers-v2.ps1` |
| `Join-NOVATRIX-Auto.ps1` | `scripts/01-grundstruktur/Join-NovatrixDomain.ps1` |
| `02 - Create_Novatrix_GPOs.ps1` | `scripts/02-group-policy/02-Create-NovatrixGPOs.ps1` |
| `03 - Prepare_FolderRedirectionRoot.ps1` | `scripts/02-group-policy/03-Prepare-FolderRedirectionRoot.ps1` |
| `04 - Link_Novatrix_GPOs.ps1` | `scripts/02-group-policy/04-Link-NovatrixGPOs.ps1` |
| `05 - Report_OU_GpoLinks.ps1` | `scripts/02-group-policy/05-Report-OuGpoLinks.ps1` |
| `06 - Create_LocalAdmin_Group.ps1` | `scripts/03-jit-lokal-admin/06-Create-LocalAdminGroup.ps1` |
| `07 - Link_LocalAdminGPO_to_clients.ps1` | `scripts/03-jit-lokal-admin/07-Link-LocalAdminGPO.ps1` |
| `08 - AddUserToLocalAdminFor60minutes.ps1` | `scripts/03-jit-lokal-admin/08-Add-TempLocalAdmin.ps1` |
| `09 - JIT-LocalAdmin.ps1` | `scripts/03-jit-lokal-admin/09-JIT-LocalAdmin.ps1` |
| `10 - Novatrix-JIT-LocalAdmin-GUI.ps1` | `scripts/03-jit-lokal-admin/10-JIT-LocalAdmin-GUI.ps1` |
| `01_Create_OUs_Groups_Users.ps1` | `scripts/04-child-domain/01-Create-OUsGroupsUsers.ps1` |
| `02_Create_Shares_Folders.ps1` | `scripts/04-child-domain/02-Create-SharesFolders.ps1` |
| `03_Create_GPOs_and_Link.ps1` | `scripts/04-child-domain/03-Create-GPOsAndLink.ps1` |
| `04_MapDrives_LogonScript.ps1` | `scripts/04-child-domain/04-MapDrives-LogonScript.ps1` |

## 3. Rättade fel i skripten

Alla skript kontrollerades med PowerShells parser (PowerShell 7.4). Logiken i JIT-nedräkningen kördes separat. Inget skript har körts mot Active Directory vid portföljarbetet.

| Fel | Skript | Rättning |
| --- | --- | --- |
| `"$variabel:"` i en sträng gav parserfel, så skripten gick inte att starta | 01-Import-NovatrixUsers-v1, Join-NovatrixDomain, 06-Create-LocalAdminGroup, 10-JIT-LocalAdmin-GUI, 01-Create-OUsGroupsUsers | `"${variabel}:"` |
| Nedräkningen avbröts efter första minuten, så användaren togs bort efter ungefär en minut | 09-JIT-LocalAdmin | `$minutes = [int]$minutes` efter valideringen |
| Den bokstavliga platshållaren `DOMAIN\` i gruppnamnen | 02-Create-SharesFolders | Variabeln `$DomainNetBIOS` |

Kända begränsningar som inte är åtgärdade finns i [docs/felsokning.md](docs/felsokning.md).

## 4. Rättelser och tillägg i dokumentationen

| Var | Ändring |
| --- | --- |
| Kontrollpanels-GPO:n | Rapporten beskrev både "Prohibit access to Control Panel" och "Show only specified Control Panel items". Texten följer nu skärmbilden: Show only specified Control Panel items. |
| Gruppnamn | `GG_Lager_RW` och `GG_Sälj_RW` i rapportens AGDLP-tabell heter `DL_Lager_RW` och `DL_Sälj_RW`, som i resten av rapporten. |
| Recycle Bin-kommandon | Stavfelen i `Enable-ADOptionalFeature` och `Get-ADOptionalFeature` är rättade. |
| Recycle Bin, livslängd | Formuleringen om 180 dagar är förtydligad till *deleted object lifetime*. |
| Byte av DC | Tillägg om Global Catalog och DNS på AD02, ompekning av DNS före demotion, `dcdiag`, `repadmin /replsummary` och `Export-DhcpServer`. |
| Byte av DC | Rättelse: `-LocalAdministratorPassword` är det nya lokala administratörslösenordet, inte DSRM-lösenordet. |
| System State-återställning | Tillägg om icke-auktoritativ och auktoritativ återställning. |
| JIT | Begränsningar och förslaget om tidsbegränsat gruppmedlemskap (PAM) är skrivna vid portföljarbetet. |
