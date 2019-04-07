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
    07.03.2019 - public version
#>

$SourcePath = 'path_to_distro_web_location'
$DeploymentPath = 'path_to_local_place_deployed_to'

$necessary_permissions = "Users",
 		                 "FullControl",
		                 "ContainerInherit,ObjectInherit",
		                 "None",
		                 "Allow"
$permissions = New-Object System.Security.AccessControl.FileSystemAccessRule($necessary_permissions)

if(-not (Test-Path $DeploymentPath)){
    
    New-Item -Path $DeploymentPath -ItemType Directory
}

$folder_acl = Get-Acl $DeploymentPath

$users_permissions = $folder_acl.Access |
                        Where-Object -Property IdentityReference -eq 'BUILTIN\Users'

if ($users_permissions.FileSystemRights -ne 'FullControl'){

    $folder_acl.SetAccessRule($permissions)

    Set-Acl -Path $DeploymentPath -AclObject $folder_acl
}

Invoke-WebRequest -Uri $SourcePath -OutFile "$DeploymentPath\tpd.zip"

$expand_archive = @{
     Path = "$DeploymentPath\tpd.zip";
     DestinationPath = $DeploymentPath;
     Force = $true;
}
Expand-Archive @expand_archive


if(Test-Path "$DeploymentPath\tpd.exe"){

    Remove-Item "$DeploymentPath\tpd.zip"
}

$new_item = @{
     ItemType = 'SymbolicLink';
     Path = "$env:PUBLIC\Desktop";
     Name = 'tpd'
     Value = "$DeploymentPath\tpd.exe";
}
New-Item @new_item
