# Felsökning

Problem från labbarna och från genomgången av skripten inför portföljen. Kolumnen Källa visar var problemet uppstod.

| Problem | Orsak | Lösning | Källa |
| --- | --- | --- | --- |
| FSMO-rollerna gick inte att flytta till AD02 | Administratörskontot saknade rätt gruppmedlemskap | Kontrollerade gruppmedlemskapen; flytten kräver Enterprise Admins och för Schema Master även Schema Admins | Byte av DC |
| GPO:er applicerades inte på klienten | Klienten hade inte hämtat de nya inställningarna | `gpresult /r` för att se vilka GPO:er som gällde, sedan `gpupdate /force /logoff` | Byte av DC |
| Små fel i GPO:er fick stor påverkan | Oftast bristande noggrannhet, till exempel i vilken GPO en inställning sparades | Testa GPO:er i en test-OU och ta en snapshot före ändringar | Secure Directory |
| Fem skript gick inte att köra alls: `Variable reference is not valid` | `"$variabel:"` i en sträng tolkas som en variabel med scope-prefix | Avgränsa namnet: `"${variabel}:"` | Portföljgenomgång |
| JIT-skriptet tog bort användaren efter ungefär en minut oavsett vald tid | `Read-Host` ger en sträng, och `$i--` fungerar bara på tal, så loopen avbröts | Omvandla till heltal: `$minutes = [int]$minutes` | Portföljgenomgång |
| Utdelningsskriptet för child-domänen skulle misslyckas | Den bokstavliga platshållaren `DOMAIN\` stod kvar i gruppnamnen | Domänens NetBIOS-namn i variabeln `$DomainNetBIOS` | Portföljgenomgång |

## Felsökningskommandon jag använt

```powershell
gpresult /r                  # vilka GPO:er gäller för användare och dator
gpupdate /force /logoff      # hämta GPO:er igen och logga ut
repadmin /showrepl           # replikering mellan domänkontrollanter
netdom query fsmo            # vem har FSMO-rollerna
```

## Kända begränsningar som inte är åtgärdade

| Skript | Begränsning |
| --- | --- |
| `04-Link-NovatrixGPOs.ps1` | Förutsätter `OU=Admins` under `OU=Users`, medan `00-Create-OUs.ps1` skapar `Admins` direkt under `OU=Novatrix`. Sökvägen måste stämma med den struktur som faktiskt finns. |
| `04-MapDrives-LogonScript.ps1` | Använder `Get-ADUser`, som kräver RSAT på klienten. `Write-EventLog` kräver att händelsekällan är registrerad, annars loggas felet aldrig. Drive Maps med targeting, som i Secure Directory, är ett robustare val. |
| `03-Create-GPOsAndLink.ps1` | Kan inte köras två gånger: om GPO:erna redan finns blir variablerna tomma och länkningen misslyckas tyst. Bakgrunden skrivs till `HKCU\Control Panel\Desktop`, som inte är en policynyckel och därför ligger kvar även om GPO:n tas bort. |
| `08-Add-TempLocalAdmin.ps1` | Låser konsolen i 60 minuter. Ersatt av version 09 och 10. |
| JIT-verktyget | Behörigheten slår igenom först vid nästa inloggning och försvinner först vid utloggning. Se [JIT – tillfällig lokal admin](06-jit-lokal-admin.md). |
