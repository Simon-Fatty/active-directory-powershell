<#
.SYNOPSIS
Logon script to map G: to Gemensam and map a department specific drive for the current user based on AD Department attribute.

COPY THIS SCRIPT to \\child.novatrix.se\NETLOGON or the GPO's script location and configure the V49_DriveMappings GPO to execute it at user logon.

The script assumes:
 - File server is \\CH-DC01
 - Gemensam share name: Gemensam
 - Department shares are named like grp_business_development (matching the group name created) but this script derives folder names from the AD user's Department attribute.
#>

# Parameters
$FileServer = "CH-DC01"
$Gemensam = "\\$FileServer\Gemensam"

try {
    $username = $env:USERNAME
    $user = Get-ADUser -Identity $username -Properties Department -ErrorAction Stop
    $dept = $user.Department
    if ([string]::IsNullOrWhiteSpace($dept)) { $dept = "General" }

    # Map G: -> Gemensam
    if (-not (Get-PSDrive -Name G -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name G -PSProvider FileSystem -Root $Gemensam -Persist -ErrorAction SilentlyContinue | Out-Null
    }

    # Derive share folder name from department (same logic as in server script)
    $deptShare = ($dept -replace '[^a-zA-Z0-9]','' -replace '\s+','_')
    $deptShareUNC = "\\$FileServer\$deptShare"
    $letter = "H:"  # Default dept drive letter; you may adjust per department mapping preferences

    # Map department drive if the share exists
    if (Test-Path $deptShareUNC) {
        # Remove mapping if exists
        if (Test-Path "$($letter)\") { Remove-PSDrive -Name $letter.TrimEnd(':') -Force -ErrorAction SilentlyContinue }
        New-PSDrive -Name $letter.TrimEnd(':') -PSProvider FileSystem -Root $deptShareUNC -Persist -ErrorAction SilentlyContinue | Out-Null
    }

} catch {
    # Silently ignore or write to eventlog if desired
    Write-EventLog -LogName Application -Source "V49LogonScript" -EntryType Warning -EventId 4000 -Message "MapDrives logon script error: $_" -ErrorAction SilentlyContinue
}
