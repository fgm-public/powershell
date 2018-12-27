
#27.12.2018 - public

$SourcePath = 'path_to_distro_web_location'

$DeploymentPath = 'path_to_distro_local_location'


if(!(Test-Path $DeploymentPath)){
    
    New-Item -Path $DeploymentPath -ItemType Directory
}


$folder_acl = Get-Acl $DeploymentPath

$users_permissions = ($folder_acl.Access | Where-Object -Property IdentityReference -eq 'BUILTIN\Пользователи').FileSystemRights


if ($users_permissions -ne 'FullControl'){

    $permissions = New-Object System.Security.AccessControl.FileSystemAccessRule ("Пользователи", "FullControl", "Allow")

    $folder_acl.SetAccessRule($permissions)

    $folder_acl | Set-Acl $DeploymentPath
}


Invoke-WebRequest -Uri  -OutFile "$DeploymentPath\tpd.zip"

Expand-Archive -Path "$DeploymentPath\tpd.zip" -DestinationPath $DeploymentPath -Force


if(Test-Path "$DeploymentPath\tpd.exe"){

    Remove-Item "$DeploymentPath\tpd.zip"
}

New-Item -ItemType SymbolicLink -Path "$env:PUBLIC\Desktop" -Name "tpd.lnk" -Value "$DeploymentPath\tpd.exe"
