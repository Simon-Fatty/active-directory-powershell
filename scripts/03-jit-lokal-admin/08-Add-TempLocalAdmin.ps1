Add-ADGroupMember -Identity "GG_LocalAdmins" -Members "test.user"
Start-Sleep -Seconds (60*60)
Remove-ADGroupMember -Identity "GG_LocalAdmins" -Members "test.user" -Confirm:$false
