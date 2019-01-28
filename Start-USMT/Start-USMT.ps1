function Start-USMT{
   
    <#
    .SYNOPSIS
        Complex binding for User State Migration Tool utility

    .DESCRIPTION
        Automatically formulate scanstate/loadstate USMT options based on information retrieved from user.
        Start archivation/restoration process.
        Create expository configured location on SMB fileshare, where store/restore user profiles.
        Store migration conditions and some information to SQL database.

    .EXAMPLE
        Start-USMT

        Starts interactive session intended to user profiles archiving/restoring process

    .NOTES
        28.01.2019 - public version
    #>

    #--------------------------------------------------------------------------------------------------------------------------
    #Global data
    #--------------------------------------------------------------------------------------------------------------------------

    $Domain = "CONTOSO"

    $USMTStoragePrivilegedUser = 'contoso.tech.backup'

    $DomainList = @("$Domain\", "$env:COMPUTERNAME\")

    $OSversion = [System.Environment]::OSVersion.Version.Major

    $USMTDistroSourcePath = "\\contoso-filestore\USMT$\amd64"

    $USMTDistroDestPath = "$env:SystemDrive\adm_stuff\USMT\"

    $USMTBackupStorage = "\\contoso-filestore\USMT$"

    $MigrationDirecory = "$USMTBackupStorage\Migration"

    $SqlServer = 'contoso-mssql'

    $LocalProfiles = Split-Path $env:PUBLIC

    $LocalProfilesList = Get-ChildItem $LocalProfiles | ForEach-Object Name

    #------------------------------------------------------------------------------------------------
    #Common functions
    #------------------------------------------------------------------------------------------------

    #Scan user state and store it
    #--------------------------------------------------------------------------------------------------------------------------
    function Scan-State {

        Clear-Host
        Write-Host `n 'Available account backup types:' `n -BackgroundColor Blue
        Write-Host "1. All $Domain domain accounts" `n
        Write-Host '2. All active local users excluding local admins' `n
        Write-Host '3. Custom account' `n`n
            
        $answer = Read-Host -Prompt 'Please select activity'

        switch ($answer){
            
            1 {
            
                $UserInclude = "/ui:$Domain\*"
                
                $UserExclude = '/ue:*\*'
                
                $MigrationDirecory = "$USMTBackupStorage\Migration\$env:computername\$Domain"

                New-Item -ItemType Directory $MigrationDirecory

                $old_domain = $Domain

                $old_name = 'ALL'
                
                $single_profile = 0
            }

            2 {

                $ActiveProfiles = (Get-LocalUser | Where-Object -Property enabled -eq true).name
                $ActiveProfiles = $ActiveProfiles | Where-Object {$_ -NotMatch 'Aдм'}
                $LocalProfilesList = $LocalProfilesList | Where-Object {$_ -in $ActiveProfiles}

                if (-not $LocalProfilesList){
                
                    Clear-Host
                    Write-Host `n "Can't find local accounts suitable for backup" -BackgroundColor Red `n`n

                    Pause

                    Clear-Host

                    Start-USMT
                }

                foreach ($profile in $LocalProfilesList){

                        $UserInclude += "/ui:$env:computername\$profile "
                }

                $UserInclude = $UserInclude.TrimEnd()

                $UserExclude = '/ue:*\*'

                $MigrationDirecory = "$USMTBackupStorage\Migration\$env:computername\$env:computername"
                
                New-Item -ItemType Directory $MigrationDirecory

                $old_domain = $env:COMPUTERNAME

                $old_name = 'ALL'

                $single_profile = 0
            }

            3 {
            
                Clear-Host
                Write-Host `n 'Suitable account list:' `n -BackgroundColor Blue

                Enumerate-Collection -Collection $LocalProfilesList

                $ProfileToMigrate = Read-Host -Prompt 'Please select account to backup it'

                $ProfileToMigrate = $LocalProfilesList[$ProfileToMigrate-1]

                Clear-Host
                Write-Host `n

                $MigrationDirecory = "$USMTBackupStorage\Migration\$env:computername\$ProfileToMigrate"

                if (-not (Test-Path $MigrationDirecory)){
                
                        New-Item -ItemType Directory $MigrationDirecory
                }
            
                Set-Content -Value $ProfileToMigrate -Path ("$MigrationDirecory\native_profile_name.npn")

                Clear-Host
                Write-Host `n 'Available domains list:' `n -BackgroundColor Blue
            
                Enumerate-Collection -Collection $DomainList
            
                $DomainName = Read-Host -Prompt 'Please select the number of the domain in which user account located'

                $DomainName = $DomainList[$DomainName-1]

                switch ($DomainName){
                        
                        $DomainList[0] {$old_domain = $Domain}
                        $DomainList[1] {$old_domain = $env:COMPUTERNAME}
                }

                Set-Content -Value $DomainName -Path "$MigrationDirecory\old_domain_name.odn"

                $UserInclude = "/ui:$DomainName$ProfileToMigrate"
                
                $UserExclude = '/ue:*\*'
                
                $single_profile = 1
                
                $old_name = $ProfileToMigrate
            }
        }
        
        Clear-Host

        $MigrationRules = "$MigrationDirecory /i:miguser.xml /i:migapp.xml /localonly /v:13 $UserInclude $UserExclude /l:$MigrationDirecory\scan.log /listfiles:filelist"
        
        $ConfigOut = $MigrationRules.replace(' ', "`r`n")

        Write-Host "`n`nProfiles '$UserInclude $UserExclude' will be saved into '$MigrationDirecory' in configuration:`r`n`r`n" -BackgroundColor DarkBlue
        Write-Host $ConfigOut`n
        Write-Host ('-' * 150)
        Write-Host "`r`n`r`nRaw USMT scanstate command:`r`n`r`n" -BackgroundColor DarkBlue
        Write-Host $MigrationRules`r`n
        Write-Host ('-' * 150)`n`n
        
        if($UserInclude){
        
            Set-Content -Value $ConfigOut -Path ("$MigrationDirecory\scan_config.cnf")
        }

        if ((Get-PSDrive | Where-Object -Property Provider -match 'FileSystem').count -gt 1){
        
            Write-Host "There are local disk drives besides 'C:\' be attentive!"`
            -BackgroundColor DarkRed `n`n
        }

        $answer = Read-Host -Prompt "Start archiving process with the settings listed above? (Y-yes, N-no)"
        
        if ($answer -eq 'y'){

            Set-Location "$USMTDistroDestPath\amd64"

            Clear-Host
            Write-Host `n 'Accounts backup in progress...' -BackgroundColor Blue
            Write-Host `n 'Please be patient'

            Start-Process -FilePath "$USMTDistroDestPath\amd64\scanstate.exe" -ArgumentList $MigrationRules -Verb 'runas' -Wait

            Clear-Host

            if (Test-Path -Path $MigrationDirecory){
            
                Clear-Host
                Write-Host `n 'Accounts backup completed succsessfully' -BackgroundColor DarkGreen `n

                $scan_date = Get-Date -Format yyyy-MM-dd

                $old_os = $OSversion

                $old_workstation = $env:COMPUTERNAME

                Prepare-DBConnection

                $insert_query = "INSERT INTO [profile_migration].[dbo].[windows] `
                                        (single_profile, scan_date, old_domain, old_name, old_os, old_workstation)`
                                VALUES ($single_profile, '$scan_date', '$old_domain', '$old_name', '$old_os', '$old_workstation')"                 
        
                Invoke-Sqlcmd -Query $insert_query -ServerInstance $SqlServer -Database profile_migration
            }

            else {

                Clear-Host
                Write-Host `n 'There were some issues, when saving your accounts' -BackgroundColor Red `n
            }

            Pause
        }
        
        Start-USMT
    }

    #Load user state from store to local comp
    #--------------------------------------------------------------------------------------------------------------------------
    function Load-State {

        $ArchiveList = (Get-ChildItem $MigrationDirecory).Name
        
        Clear-Host
        Write-Host `n 'List of archives that contents profiles:' `n -BackgroundColor Blue

        Enumerate-Collection -Collection $ArchiveList
        
        $ArchiveToRestore = Read-Host -Prompt 'Please select archive'

        $ArchiveName = $ArchiveList[$ArchiveToRestore-1]
        
        $ArchiveToRestore = "$MigrationDirecory\$ArchiveName"

        Prepare-DBConnection

        $select_query = "SELECT [id]
                        FROM [profile_migration].[dbo].[windows]
                        WHERE [old_workstation] = '$ArchiveName'"
        
        $ArchiveDbRecordsIDs = (Invoke-Sqlcmd -Query $select_query -ServerInstance $SqlServer -Database profile_migration).id
        
        foreach ($id in $ArchiveDbRecordsIDs){

            $RecordIdToUpdate = $id
        
            $select_query = "SELECT [old_domain], [old_name]
                            FROM [profile_migration].[dbo].[windows]
                            WHERE [id] = '$id'"

            $old_domain, $old_name = (Invoke-Sqlcmd -Query $select_query -ServerInstance fb-lks-mssql -Database profile_migration).ItemArray

            if ($old_name -eq 'ALL'){
            
                $ArchiveType += "Backup contains multiple accounts from the '$old_domain' domain`r`n`r`n"
            }

            else{
            
                $ArchiveType += "Backup contains single account '$old_name' from the '$old_domain' domain`r`n`r`n"
            }
        }

        Clear-Host
        Write-Host `n "Contents of the archive $ArchiveName :" -BackgroundColor Blue `n`n    
        Write-Host $ArchiveType `n`n
        Write-Host `n 'Available account restore types:' `n -BackgroundColor Blue
        Write-Host "1. All $Domain domain accounts" `n
        Write-Host "2. All active local users excluding local admins" `n
        Write-Host "3. Single accounts" `n`n

        $answer = Read-Host -Prompt "Please select proper recovery type"
        
        switch ($answer){
            
            1{
                $MigrationFlags = "/ui:$Domain\* /ue:*\*"
                
                $NativeDomainName = $Domain
            }
            
            2{
                $MigrationFlags = "/ui:$ArchiveName\* /ue:*\*"
            
                $NativeDomainName = $ArchiveToRestore
            }
            
            3{
                Clear-Host 
            
                $NativeDomainName = $old_name
            
                Write-Host `n            
                
                $answer = Read-Host -Prompt "Do you want to move archive into new account or account type (local/domain)? (Y-yes, N-no)"

                if ($answer -eq 'y'){

                    Write-Host `n

                    $new_name = Read-Host -Prompt "Please enter account name in which current local account archive will be restored"

                    $MoveUser += $new_name

                    $MigrationFlags = "/mu:$old_domain\${old_name}:$Domain\$new_name"
                }
            
                else{

                    $new_name = $old_name
                    
                    $MigrationFlags = "/ui:$old_domain\$old_name /ue:*\*"
                }
            }
        }

        $MigrationRules = "/c $ArchiveToRestore\$NativeDomainName /i:miguser.xml /i:migapp.xml /v:13 $MigrationFlags /l:$ArchiveToRestore\$NativeDomainName\load.log "

        $ConfigOut = $MigrationRules.replace(' ', "`r`n")

        Write-Host "`n`n Profiles '$old_domain\$old_name' will be restored from '$ArchiveToRestore\$NativeDomainName' in the following configuration:`n`n" -BackgroundColor DarkBlue
        Write-Host $ConfigOut`n
        Write-Host ('-' * 150)
        Write-Host "`r`n`r`nRaw USMT scanstate command:`r`n`r`n" -BackgroundColor DarkBlue
        Write-Host $MigrationRules`r`n
        Write-Host ('-' * 150)`n`n

        Set-Content -Value $ConfigOut -Path ("$ArchiveToRestore\$NativeDomainName\load_config.cnf")

        $answer = Read-Host -Prompt "Proceed to restore with the parameters listed above? (Y-yes, N-no)"

        if ($answer -eq 'y'){

            Set-Location "$USMTDistroDestPath\amd64"

            Clear-Host
            Write-Host `n 'Accounts restoration in progress...' -BackgroundColor Blue
            Write-Host `n 'Please be patient...'

            $OldLocalProfiles = (Get-ChildItem $LocalProfiles).Name

            Start-Process -FilePath "$USMTDistroDestPath\amd64\loadstate.exe" -ArgumentList $MigrationRules -Verb 'runas' -Wait

            $NewLocalProfiles = (Get-ChildItem $LocalProfiles).Name

            Pause

            $NewProfileFolders = Compare-Object -ReferenceObject $OldLocalProfiles -DifferenceObject $NewLocalProfiles

            if ($NewProfileFolders){

                $load_date = Get-Date -Format yyyy-MM-dd

                Prepare-DBConnection

                $update_query = "UPDATE [profile_migration].[dbo].[windows]
                                SET migration_status=1, load_date='$load_date', new_domain='$Domain', new_name='$new_name', new_os='$OSversion', new_workstation='$env:COMPUTERNAME'
                                WHERE id='$RecordIdToUpdate'"

                Invoke-Sqlcmd -Query $update_query -ServerInstance $SqlServer -Database profile_migration

                Clear-Host
                Write-Host `n 'Profile restoration completed succsessfully' -BackgroundColor Green `n
            }

            else {

                Clear-Host
                Write-Host `n 'There were some issues, when restoring your profiles' -BackgroundColor Red `n
            }
        
            Pause
        }
        
        Start-USMT
    }

    #------------------------------------------------------------------------------------------------
    #Supplementary functions
    #------------------------------------------------------------------------------------------------

    #Test PS version
    #--------------------------------------------------------------------------------------------------------------------------
    function Test-PSVersion{

        $PSVersion = -join $PSVersionTable.PSVersion.ToString()[0..2]

        if ($PSVersion -lt 5.1){
        
            Write-Host `n
            Write-Warning 'It is strictly recomended to use PS version 5.1 or higher'
            Write-Host `n
            Write-Warning 'Some issues may discovered in progress'
            Write-Host `n`n
            Pause
            Clear-Host
        }
    }

    #Test Windows architecture
    #--------------------------------------------------------------------------------------------------------------------------
    function Test-OSArchitecture{

        if (-not [environment]::Is64BitOperatingSystem){
            
            Write-Host `n 'Sorry, this utility works only on Windows x64' `n -BackgroundColor Red
            Pause
            Clear-Host

            Exit
        }
    }    

    #Elevate shell process if not admin rights
    #------------------------------------------------------------------------------------------------
    function Elevate-Shell{

        $CurrentWindowsUserId = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $CurrentWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($CurrentWindowsUserId)
        $AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
        $IsAdmin = $CurrentWindowsPrincipal.IsInRole($AdminRole)

        if (-not $IsAdmin){

            Write-Host `n "The script is running in a shell with user rights. Some tools may not work properly." -BackgroundColor Magenta
            Write-Host `n "Privilege elevation recommended." `n`n
        
            $answer = Read-Host -Prompt "Elevate shell? (Y-yes, N-no)"

            if ($answer -eq "y"){

                Start-Process -FilePath 'powershell.exe' -Verb runas -WindowStyle Maximized

                exit
            }
        }
    }

    #Deploy USMT distro on local comp
    #--------------------------------------------------------------------------------------------------------------------------
    function Deploy-USMTDistro{
            
        New-Item $USMTDistroDestPath -ItemType Directory

        Copy-Item -Path $USMTDistroSourcePath -Destination $USMTDistroDestPath -Recurse

        if (Test-Path -Path "$USMTDistroDestPath\amd64"){
            
            Clear-Host
            Write-Host -BackgroundColor Green `n 'USMT utility succsessfully deployed to ' $USMTDistroDestPath `n`n

            Pause
        }
    }

    #Get access to USMT storage if necessary
    #------------------------------------------------------------------------------------------------
    function Get-USMTStorageAccess{

        if (-not (Test-Path -Path $USMTBackupStorage -ErrorAction SilentlyContinue)){

            Write-Host `n "To run the script, you need to access the backup storage, otherwise the script can not work." -BackgroundColor Blue
            Write-Host  `n "Please enter proper credentials"
        
            New-PSDrive -Name USMT$ `
                        -PSProvider FileSystem `
                        -Root $USMTBackupStorage `
                        -Credential (Get-Credential -Credential $Domain\$USMTStoragePrivilegedUser) `
                        -scope script
        }
    }
    #--------------------------------------------------------------------------------------------------------------------------
    function Enumerate-Collection{

        param([Parameter (Mandatory=$True, Position=0)] $Collection)

        $index = 1

        foreach ($Element in $Collection){

            Write-Host $index'.' $Element

            $index++
        }

        Write-Host `n    
    }

    #--------------------------------------------------------------------------------------------------------------------------   
    function Prepare-DBConnection{

        $select_query ="SELECT *
                        FROM [profile_migration].[dbo].[windows]
                        ORDER BY [id]"

        try{
            $tmp = Invoke-Sqlcmd -Query $select_query -ServerInstance $SqlServer -Database profile_migration
        }
        catch{
            Import-Module sqlserver -NoClobber -Force -ErrorAction SilentlyContinue
        }

        try{
            $tmp = Invoke-Sqlcmd -Query $select_query -ServerInstance $SqlServer -Database profile_migration
        }
        catch{
        
            Install-module -Name sqlserver -AllowClobber -Force
        }
    }

    #--------------------------------------------------------------------------------------------------------------------------   
    #Main function
    #--------------------------------------------------------------------------------------------------------------------------

    Clear-Host

    Elevate-Shell

    Get-USMTStorageAccess

    Clear-Host

    Write-Host `n 'USER STATE MIGRATION TOOL. VERSION 10.0' -BackgroundColor Blue

    Test-OSArchitecture

    Test-PSversion

    $answer = Read-Host `n "Start profile migration process? (Y-yes, N-no)"

    if ($answer -eq 'y'){

        Clear-Host

        if (-not (Test-Path -Path "$USMTDistroDestPath\amd64")){

            Write-Host `n 'Can`t find USMT distro on local computer. Would you like to copy it to "' $USMTDistroDestPath '" ?' -BackgroundColor Red `n
        
            $answer = Read-Host '(Y-yes, N-no)'

            if ($answer -eq 'y'){

                Deploy-USMTDistro
            }

            else {

                Clear-Host
            
                Write-Host `n 'Profile migration can`t process without USMT distro!' -BackgroundColor Red `n

                Pause

                Clear-Host

                Exit
            }
        }
    
        Clear-Host
    
        Write-Host `n 'Available actions:' `n -BackgroundColor Blue
        Write-Host '1. Archive profiles' `n
        Write-Host '2. Restore profiles' `n`n

        $answer = Read-Host 'Please select required action'
    
        switch ($answer){
        
            1 {Scan-State}

            2 {Load-State}
        }

        Clear-Host
    }
}
