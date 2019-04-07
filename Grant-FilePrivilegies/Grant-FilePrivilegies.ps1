function Grant-FilePrivilegies{
    <#
    .SYNOPSIS
        Creates personal folders for AD accounts with custom privilegies, located in file.

    .DESCRIPTION
        Creates personal folders for AD accounts listed in file.
        Folders creates in custom location with custom privilegies.
    
    .EXAMPLE
        Grant-FilePrivilegies

        Starts interactive session with some questions

    .NOTES
        19.01.2019 - public version
    #>

    #------------------------------------------------------------------------------------------------
    #Global data
    #------------------------------------------------------------------------------------------------
    $ADusersFile = 'C:\AD\ad.txt'
    $ADusers = Get-Content $ADusersFile
    $Domain = "FABRIKAM\"

    $FoldersPaths = [ordered]@{
        Backup = 'B:\backup\'
        Home = 'S:\home\'
    }
    
    $Privilegies = @{
        IdentityReference = ''
        FileSystemRights = "FullControl"
        InheritanceFlags = "ContainerInherit, ObjectInherit"
        PropagationFlags = "None"
        AccessControlType = "Allow"
    }
        
    #------------------------------------------------------------------------------------------------
    #Supplementary functions
    #------------------------------------------------------------------------------------------------
    function Enumerate-Collection{
        param(
            [Parameter(Mandatory=$true, Position=0)]
            $collection
        )
        ($array=$collection -as [array]) |
            ForEach-Object {
                -join (($array.IndexOf($_)+1), ". $_")
            }
    }
    
    #------------------------------------------------------------------------------------------------
    #Common functions
    #------------------------------------------------------------------------------------------------
    function Grant-FoldersAcls{

         foreach ($folder in $NewUsers){
            New-Item -Name $folder -Path $FoldersPath -ItemType Directory

            $acl = Get-Acl "$FoldersPath\$folder"
            $Account = $Domain + $folder
            $Privilegies['IdentityReference'] = $Account

            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $Privilegies.IdentityReference, 
                $Privilegies.FileSystemRights, 
                $Privilegies.InheritanceFlags, 
                $Privilegies.PropagationFlags, 
                $Privilegies.AccessControlType
            )
            $acl.AddAccessRule($accessRule)
            Set-Acl "$FoldersPath\$folder" -AclObject $acl
        }
    }
    
    #------------------------------------------------------------------------------------------------
    #Main function
    #------------------------------------------------------------------------------------------------
    Clear-Host
    $answer = Read-Host `n "Retrieve user accounts from AD? (Y-'yes', N-'no')"

    if ($answer -eq 'y'){
        if (Test-Path $ADusersFile){

            Write-Host -BackgroundColor DarkGreen `n "AD users retrieved" `n`n
            $answer = Read-Host "Go to folders creation? (Y-'yes', N-'no')"

            if ($answer -eq 'y'){
                Clear-Host
                Write-Host -BackgroundColor DarkBlue `n "Available locations:" `n

                Enumerate-Collection -Collection $FoldersPaths.Keys

                $answer = Read-Host `n "Please select location type"

                $FoldersPath = $FoldersPaths[$answer-1]
                $FolderNames = (Get-ChildItem $FoldersPath).name
                $NewUsers = $ADusers |
                    Where-Object {
                        $_ -notin $FolderNames
                    }

                if($NewUsers){

                    $NewUsersAmount = ($NewUsers |
                        Measure-Object).Count

                    Write-Host -BackgroundColor DarkBlue `n`n "There are $NewUsersAmount new users presented in AD but not having appropriate folders in '$FoldersPath':" `n

                    $NewUsers

                    $answer = Read-Host `n`n 'Create new folders and grant specified privilegies to them? (Y-'yes', N-'no')'

                    if ($answer -eq 'y'){
                        Grant-FoldersAcls
                    }
                }else{
                    Clear-Host
                    Write-Host -BackgroundColor DarkGreen `n "There are no new users without personal folders in '$FoldersPath'" `n
                }
            }
        }
    }
}