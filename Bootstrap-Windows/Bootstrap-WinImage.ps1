
$Password = ConvertTo-SecureString "password" -Asplaintext -Force

$new_localUser = @{
    Description = 'Temporary bootstrap technical account';
    Name = 'Ansible';
    Password = $Password;
    PasswordNeverExpires = $true;
    UserMayNotChangePassword = $true;
    AccountNeverExpires = $true;
}
New-LocalUser @new_localUser

Add-LocalGroupMember -Group "Administrators" -Member "ansoper"

Set-NetConnectionProfile -NetworkCategory Private

Enable-PSRemoting
