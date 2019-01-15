<#
.SYNOPSIS
    Deploy tpd distro from web location to custom workstations

.DESCRIPTION
    1. Download zip archive with tpd distro, unzip it, then placed distro in custom location.
    2. Set parent folder permissions properly.
    3. Puts tpd.exe symlink to all users.

.EXAMPLE
    Not for interactive use.
    Link it with PC GPO, for example.

.NOTES
    27.12.2018 - public version
#>

$SourcePath = 'path_to_distro_web_location'

$DeploymentPath = 'path_to_local_place_deployed_to'


if(-not (Test-Path $DeploymentPath)){
    
    New-Item -Path $DeploymentPath -ItemType Directory
}


$folder_acl = Get-Acl $DeploymentPath

$users_permissions = ($folder_acl.Access | Where-Object -Property IdentityReference -eq 'BUILTIN\Users').FileSystemRights


if ($users_permissions -ne 'FullControl'){

    $permissions = New-Object System.Security.AccessControl.FileSystemAccessRule ("Users", "FullControl", "Allow")

    $folder_acl.SetAccessRule($permissions)

    $folder_acl | Set-Acl $DeploymentPath
}


Invoke-WebRequest -Uri $SourcePath -OutFile "$DeploymentPath\tpd.zip"

Expand-Archive -Path "$DeploymentPath\tpd.zip" -DestinationPath $DeploymentPath -Force


if(Test-Path "$DeploymentPath\tpd.exe"){

    Remove-Item "$DeploymentPath\tpd.zip"
}

New-Item -ItemType SymbolicLink -Path "$env:PUBLIC\Desktop" -Name "tpd" -Value "$DeploymentPath\tpd.exe"