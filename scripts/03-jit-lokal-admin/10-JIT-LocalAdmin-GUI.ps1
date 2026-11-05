Add-Type -AssemblyName PresentationFramework
Import-Module ActiveDirectory -ErrorAction Stop

# ===================== Inställningar =====================
$Global:JitGroupName      = "GG_LocalAdmins"   # Domängrupp som via GPO är lokal admin
$Global:SearchBaseUsers   = "OU=Standard,OU=Users,OU=Novatrix,DC=novatrix,DC=se"
$Global:LogDirectory      = "C:\JIT-Logs"
$Global:LogFile           = Join-Path $Global:LogDirectory "JIT-Log.txt"

# Skapa loggmapp om den saknas
if (-not (Test-Path $Global:LogDirectory)) {
    New-Item -Path $Global:LogDirectory -ItemType Directory -Force | Out-Null
}

# ===================== XAML GUI ==========================
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Novatrix JIT Local Admin" Height="460" Width="720"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResize">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>

    <!-- Rad 0: Användare + uppdatera -->
    <TextBlock Grid.Row="0" Grid.Column="0"
               Text="Användare:"
               Margin="0,0,10,5"
               VerticalAlignment="Center"/>
    <ComboBox Grid.Row="0" Grid.Column="1"
              x:Name="UserCombo"
              Margin="0,0,10,5"
              HorizontalAlignment="Stretch"
              MinWidth="250"/>
    <Button Grid.Row="0" Grid.Column="2"
            x:Name="RefreshButton"
            Content="Uppdatera lista"
            Padding="10,3"
            Margin="0,0,0,5"/>

    <!-- Rad 1: Tid -->
    <TextBlock Grid.Row="1" Grid.Column="0"
               Text="Tid (minuter):"
               Margin="0,0,10,5"
               VerticalAlignment="Center"/>
    <TextBox Grid.Row="1" Grid.Column="1"
             x:Name="MinutesBox"
             Text="30"
             Margin="0,0,10,5"
             Width="80"/>

    <!-- Rad 2: Knappar -->
    <StackPanel Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3"
                Orientation="Horizontal"
                Margin="0,5,0,5">
      <Button x:Name="GrantButton"
              Content="Ge JIT admin"
              Padding="10,5"
              Margin="0,0,10,0"/>
      <Button x:Name="RemoveNowButton"
              Content="Ta bort JIT nu"
              Padding="10,5"
              Margin="0,0,10,0"/>
      <Button x:Name="ShowMembersButton"
              Content="Visa aktuella JIT-medlemmar"
              Padding="10,5"
              Margin="0,0,10,0"/>
      <Button x:Name="CloseButton"
              Content="Stäng"
              Padding="10,5"/>
    </StackPanel>

    <!-- Rad 3: Logg -->
    <GroupBox Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="3"
              Header="Logg"
              Margin="0,5,0,5">
      <TextBox x:Name="LogBox"
               Margin="5"
               AcceptsReturn="True"
               VerticalScrollBarVisibility="Auto"
               HorizontalScrollBarVisibility="Auto"
               IsReadOnly="True"
               TextWrapping="Wrap"/>
    </GroupBox>

    <!-- Rad 4: Info -->
    <TextBlock Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="3"
               FontSize="10"
               Foreground="Gray"
               Text="Obs: PowerShell-fönstret bör vara öppet tills JIT-tiden gått ut, så att borttagnings-jobbet kan köras klart. Händelser loggas även till C:\JIT-Logs\JIT-Log.txt."/>
  </Grid>
</Window>
"@

# ===================== Ladda XAML ========================
$xmlReader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window    = [Windows.Markup.XamlReader]::Load($xmlReader)

# Hämta kontroller
$UserCombo         = $window.FindName("UserCombo")
$RefreshButton     = $window.FindName("RefreshButton")
$GrantButton       = $window.FindName("GrantButton")
$RemoveNowButton   = $window.FindName("RemoveNowButton")
$ShowMembersButton = $window.FindName("ShowMembersButton")
$CloseButton       = $window.FindName("CloseButton")
$MinutesBox        = $window.FindName("MinutesBox")
$LogBox            = $window.FindName("LogBox")

# ===================== Hjälpfunktioner ===================
function Add-Log {
    param([string]$Text)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Text"

    # Till GUI
    $LogBox.AppendText("$line`r`n")
    $LogBox.ScrollToEnd()

    # Till fil
    try {
        Add-Content -Path $Global:LogFile -Value $line
    } catch {
        # Om logg till fil misslyckas vill vi inte krascha GUI:t
    }
}

function Load-Users {
    try {
        Add-Log "Hämtar användare från AD (SearchBase: $($Global:SearchBaseUsers))..."

        $UserCombo.Items.Clear()

        $filter = "Enabled -eq `$true"
        if ([string]::IsNullOrWhiteSpace($Global:SearchBaseUsers)) {
            $users = Get-ADUser -Filter $filter -Properties DisplayName,SamAccountName |
                     Sort-Object DisplayName
        } else {
            $users = Get-ADUser -Filter $filter -SearchBase $Global:SearchBaseUsers -Properties DisplayName,SamAccountName |
                     Sort-Object DisplayName
        }

        foreach ($u in $users) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = "{0} ({1})" -f $u.DisplayName, $u.SamAccountName
            $item.Tag     = $u.SamAccountName
            [void]$UserCombo.Items.Add($item)
        }

        if ($UserCombo.Items.Count -gt 0) {
            $UserCombo.SelectedIndex = 0
        }

        Add-Log "Laddade $($UserCombo.Items.Count) användare."
    }
    catch {
        Add-Log "Fel vid hämtning av användare: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Fel vid hämtning av användare:`n$($_.Exception.Message)","Fel")
    }
}

function Show-CurrentMembers {
    try {
        $group = Get-ADGroup -Identity $Global:JitGroupName -ErrorAction Stop
    }
    catch {
        Add-Log "Gruppen $($Global:JitGroupName) finns inte: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Gruppen $($Global:JitGroupName) finns inte.","Fel")
        return
    }

    Add-Log "Hämtar aktuella medlemmar i $($Global:JitGroupName)..."

    $members = Get-ADGroupMember -Identity $group -Recursive -ErrorAction SilentlyContinue |
               Where-Object { $_.ObjectClass -eq 'user' } |
               ForEach-Object { Get-ADUser $_.DistinguishedName -Properties DisplayName,SamAccountName } |
               Sort-Object DisplayName

    if (-not $members -or $members.Count -eq 0) {
        Add-Log "Inga användare är JIT-admin just nu."
        [System.Windows.MessageBox]::Show("Inga användare är JIT-admin just nu.","Info")
        return
    }

    $msg = "Aktuella JIT-medlemmar i $($Global:JitGroupName):`n"
    foreach ($m in $members) {
        $line = "{0} ({1})" -f $m.DisplayName, $m.SamAccountName
        Add-Log "JIT-medlem: $line"
        $msg += " - $line`n"
    }

    [System.Windows.MessageBox]::Show($msg, "Aktuella JIT-medlemmar")
}

function Get-SelectedUserSam {
    $selectedItem = $UserCombo.SelectedItem
    if (-not $selectedItem) {
        [System.Windows.MessageBox]::Show("Välj en användare först.","Info")
        return $null
    }
    return $selectedItem.Tag
}

function Start-JitForUser {
    $userSam = Get-SelectedUserSam
    if (-not $userSam) { return }

    # Tid i minuter
    $minutesText = $MinutesBox.Text.Trim()
    if (-not ($minutesText -as [int])) {
        [System.Windows.MessageBox]::Show("Tid måste vara ett heltal (minuter).","Fel")
        return
    }

    $minutes = [int]$minutesText
    if ($minutes -le 0) {
        [System.Windows.MessageBox]::Show("Tid måste vara större än 0 minuter.","Fel")
        return
    }

    # Kolla grupp
    try {
        $group = Get-ADGroup -Identity $Global:JitGroupName -ErrorAction Stop
    }
    catch {
        Add-Log "Gruppen $($Global:JitGroupName) finns inte: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Gruppen $($Global:JitGroupName) finns inte.","Fel")
        return
    }

    # Kolla användare
    $user = Get-ADUser -Filter "SamAccountName -eq '$userSam'" -ErrorAction SilentlyContinue
    if (-not $user) {
        Add-Log "Hittar inte användare $userSam."
        [System.Windows.MessageBox]::Show("Hittar inte användare $userSam.","Fel")
        return
    }

    # Lägg till användaren i gruppen
    try {
        Add-ADGroupMember -Identity $group -Members $user -ErrorAction Stop
        Add-Log "LADE TILL $($user.SamAccountName) i $($Global:JitGroupName) för $minutes minuter."
        [System.Windows.MessageBox]::Show("$($user.SamAccountName) fick JIT-admin i $minutes minuter.","JIT aktiverad")
    }
    catch {
        if ($_.Exception.Message -like "*is already a member*") {
            Add-Log "$($user.SamAccountName) är redan medlem i $($Global:JitGroupName)."
            [System.Windows.MessageBox]::Show("$($user.SamAccountName) är redan JIT-admin.","Info")
        } else {
            Add-Log "Fel vid tillägg: $($_.Exception.Message)"
            [System.Windows.MessageBox]::Show("Fel vid tillägg:`n$($_.Exception.Message)","Fel")
            return
        }
    }

    # Starta bakgrundsjobb som tar bort användaren efter X minuter
    Add-Log "Startar bakgrundsjobb som tar bort $($user.SamAccountName) om $minutes minuter."

    $jobScript = {
        param($GroupName, $UserSam, $Minutes, $LogFilePath)

        try {
            Import-Module ActiveDirectory -ErrorAction Stop

            Start-Sleep -Seconds (60 * $Minutes)

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $linePrefix = "[$timestamp]"

            $user = Get-ADUser -Filter "SamAccountName -eq '$UserSam'" -ErrorAction SilentlyContinue
            if ($user) {
                Remove-ADGroupMember -Identity $GroupName -Members $user -Confirm:$false -ErrorAction SilentlyContinue
                $msg = "$linePrefix AUTOMATISKT: Tog bort $UserSam från $GroupName efter $Minutes minuter."
            } else {
                $msg = "$linePrefix AUTOMATISKT: Kunde inte hitta användaren $UserSam vid borttagning."
            }

            try {
                Add-Content -Path $LogFilePath -Value $msg
            } catch {
                # ignorera loggfel i bakgrundsjobbet
            }
        }
        catch {
            try {
                $timestamp2 = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $errLine = "[$timestamp2] AUTOMATISKT: Fel i JIT-jobb för ${UserSam}: $($_.Exception.Message)"
                Add-Content -Path $LogFilePath -Value $errLine
            } catch {
                # ignorera
            }
        }
    }

    Start-Job -ScriptBlock $jobScript -ArgumentList $Global:JitGroupName, $userSam, $minutes, $Global:LogFile | Out-Null
}

function Remove-JitNow {
    $userSam = Get-SelectedUserSam
    if (-not $userSam) { return }

    try {
        $group = Get-ADGroup -Identity $Global:JitGroupName -ErrorAction Stop
    }
    catch {
        Add-Log "Gruppen $($Global:JitGroupName) finns inte: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Gruppen $($Global:JitGroupName) finns inte.","Fel")
        return
    }

    $user = Get-ADUser -Filter "SamAccountName -eq '$userSam'" -ErrorAction SilentlyContinue
    if (-not $user) {
        Add-Log "Hittar inte användare $userSam vid manuell borttagning."
        [System.Windows.MessageBox]::Show("Hittar inte användare $userSam.","Fel")
        return
    }

    try {
        Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false -ErrorAction Stop
        Add-Log "MANUELLT: Tog bort $($user.SamAccountName) från $($Global:JitGroupName)."
        [System.Windows.MessageBox]::Show("$($user.SamAccountName) är inte längre JIT-admin.","JIT borttagen")
    }
    catch {
        Add-Log "Fel vid manuell borttagning: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Fel vid borttagning:`n$($_.Exception.Message)","Fel")
    }
}

# ===================== Event handlers ====================
$RefreshButton.Add_Click({ Load-Users })
$ShowMembersButton.Add_Click({ Show-CurrentMembers })
$GrantButton.Add_Click({ Start-JitForUser })
$RemoveNowButton.Add_Click({ Remove-JitNow })
$CloseButton.Add_Click({ $window.Close() })

# ===================== Init & start ======================
Add-Log "Novatrix JIT Local Admin GUI startas..."
Load-Users

# Visa fönstret (blockerar tills stängt)
$window.ShowDialog() | Out-Null
