<#
.SYNOPSIS
Create skeleton GPOs and link them to the child domain Users OU.
This script creates:
 - V49_Wallpaper (sets user wallpaper via registry policy)
 - V49_DriveMappings (creates a linked GPO which you can use to run a logon script for drive mapping)
 - V49_FolderRedirection (GPO placeholder - final folder redirection should be set via GPO GUI or by importing a configured GPO backup)

NOTE: Group Policy Preferences (Drive Maps / Folder Redirection) are easiest to configure via the GPO MMC GUI.
This script will:
 - Create GPOs
 - Link them to OU=Users,OU=<department>,... (we will link to the parent OU Users)
 - Set wallpaper registry policy to point to \\ad02\NETLOGON\bg_user.jpg

USAGE
Run from a management server with GroupPolicy module and as a user with permissions to create/link GPOs.
#>

Import-Module GroupPolicy -ErrorAction Stop

$Domain = "child.novatrix.se"
$BaseOUDN = "OU=Users,DC=child,DC=novatrix,DC=se"
$WallpaperPath = "\\ad02\NETLOGON\bg_user.jpg"

# Create GPOs
$gpoWallpaper = New-GPO -Name "V49_Wallpaper" -Domain $Domain -Comment "User wallpaper for V49 project" -ErrorAction SilentlyContinue
$gpoDrives = New-GPO -Name "V49_DriveMappings" -Domain $Domain -Comment "Logon script for drive mappings" -ErrorAction SilentlyContinue
$gpoFR = New-GPO -Name "V49_FolderRedirection" -Domain $Domain -Comment "Folder Redirection placeholder (configure via GPO GUI)" -ErrorAction SilentlyContinue

# Link GPOs
New-GPLink -Name $gpoWallpaper.DisplayName -Target $BaseOUDN -Order 1 -Enforced:$false -ErrorAction SilentlyContinue
New-GPLink -Name $gpoDrives.DisplayName -Target $BaseOUDN -Order 2 -Enforced:$false -ErrorAction SilentlyContinue
New-GPLink -Name $gpoFR.DisplayName -Target $BaseOUDN -Order 3 -Enforced:$false -ErrorAction SilentlyContinue

# Configure wallpaper via User registry policy
# HKCU\Control Panel\Desktop\Wallpaper = path
# WallpaperStyle = 2 (stretched) or 10 (fill) depending on preference
Set-GPRegistryValue -Name $gpoWallpaper.DisplayName -Key "HKCU\Control Panel\Desktop" -ValueName "Wallpaper" -Type String -Value $WallpaperPath
Set-GPRegistryValue -Name $gpoWallpaper.DisplayName -Key "HKCU\Control Panel\Desktop" -ValueName "WallpaperStyle" -Type String -Value "2"

Write-Host "Created and linked GPOs. Wallpaper set to $WallpaperPath via registry policy." -ForegroundColor Green

Write-Host "`nIMPORTANT:"
Write-Host " - Folder Redirection requires configuration via GPO GUI (User Configuration -> Policies -> Windows Settings -> Folder Redirection)." -ForegroundColor Yellow
Write-Host " - Drive mappings are implemented here using a logon script (see 04_MapDrives_LogonScript.ps1). Place that script into NETLOGON or SYSVOL and configure V49_DriveMappings GPO to run it at user logon." -ForegroundColor Yellow
