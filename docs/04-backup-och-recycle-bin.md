# Backup och AD Recycle Bin

**Typ:** gemensamt grupparbete (Novatrix Secure Directory, dec 2025). Det finns inga skärmbilder av backup-schemat eller Recycle Bin-testet; beskrivningen bygger på rapporten.

## System State-backup

Domänkontrollanten (en VM i Hyper-V) säkerhetskopieras med Windows Server Backup:

1. Öppna Windows Server Backup på domänkontrollanten och välj **Backup Schedule**.
2. Välj **Custom**, klicka **Add Items** och markera **System State**.
3. Välj hur ofta backupen ska köras, till exempel dagligen klockan 02:00.
4. Välj mål: en lokal disk eller en nätverksplats.
5. Slutför guiden och kontrollera att schemat syns i Windows Server Backup.

Enligt gruppens slutreflektion gick schemat att lägga upp utan problem och verifierades via loggarna.

**Loggning:** Event Viewer → `Applications and Services Logs → Microsoft → Windows → Backup` visar när backupen startade och slutade, om den lyckades och eventuella fel.

**Återställning av Active Directory:**

1. Starta om domänkontrollanten i Directory Services Restore Mode (DSRM).
2. Logga in med DSRM-lösenordet.
3. Öppna Windows Server Backup, välj **Recover** och rätt backup.
4. Välj **System State** som återställningstyp och slutför.
5. Starta om normalt och kontrollera att AD DS, SYSVOL och DNS fungerar.

> **Tillägg vid portföljarbetet:** en sådan återställning är icke-auktoritativ – domänkontrollanten tar emot nyare ändringar från andra DC:er efteråt. För att återställa objekt som raderats på alla DC:er krävs en auktoritativ återställning med `ntdsutil`, eller enklare: AD Recycle Bin nedan.

## AD Recycle Bin

AD Recycle Bin låter en administratör återställa raderade objekt med alla attribut kvar, till exempel gruppmedlemskap. Funktionen kräver forest functional level Windows Server 2008 R2 eller högre och går inte att stänga av när den väl är aktiverad.

Aktivering (rättad stavning jämfört med rapporten):

```powershell
Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target 'novatrix.se'

# Kontrollera att funktionen är aktiv
Get-ADOptionalFeature -Filter "Name -like 'Recycle Bin Feature'"
```

Funktionen kan också slås på i Active Directory Administrative Center (ADAC) under **Enable Recycle Bin**.

**Test:** en användare raderades i Active Directory Users and Computers. I ADAC → **Deleted Objects** syns användaren med sin tidigare plats. **Restore** lade tillbaka den där den låg; **Restore To** kan välja en annan OU.

Ett raderat objekt kan återställas med alla attribut under *deleted object lifetime*, som standard 180 dagar. Utan Recycle Bin blir objektet en tombstone där de flesta attributen redan är borttagna.
