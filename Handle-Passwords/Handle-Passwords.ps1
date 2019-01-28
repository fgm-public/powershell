function Handle-Passwords{
    
    <#
    .SYNOPSIS
        Encrypt/decrypt passwords.

    .DESCRIPTION
        Handle specified credentials which includes:
        - Storing credentials in file
        - Generating encryption cipher key, storing/restoring it in/from file        
        - Encrypt password from credentials file (using custom cipher key or default OS token) and store credentials to file or SQL database
        - Decrypt password from credentials (using custom cipher key or default OS token) restored from file or SQL database

        Folder specified by user will containing stuff: 
            username.acn - contains username and password (plaintext)
            keyname.key - cipher key used to encryption/decryption
            username.OS-key.psw - contains username and password (encrypted with default OS encryption token)
            username.keyname-key.psw - contains username and password (encrypted with custom encryption token)


    .PARAMETER WorkingDirectory
        Filesystem path to custom location, where processing with passwords and encryption keys will take place (creation, receipt, encryption, decryption) (optional)

    .EXAMPLE
        Handle-Passwords

        Starts interactive session intended to credentials encryption/decryption process

    .EXAMPLE
        Handle-Passwords -WorkingDirectory 'c:\my_creds\'

        Starts interactive session intended to credentials encryption/decryption process with straightway working folder designation
    
    .NOTES
        28.01.2019 - public version
    #>

    param(
        [Parameter (Mandatory=$False, Position=0)] [string] $WorkingDirectory
    )

    #------------------------------------------------------------------------------------------------
    #Global data
    #------------------------------------------------------------------------------------------------
    
    $SqlServer = 'my_mssql'
    
    $MenuOptions = [ordered]@{

        "1. Create file containing passwords (plain text)" = $True; 
        "2. Generate encryption keyfile" = $True;
        "3. Encrypt passwords (using keyfile)" = $True;
        "4. Decrypt passwords (using keyfile)" = $True;
    }

    #------------------------------------------------------------------------------------------------
    #Common functions
    #------------------------------------------------------------------------------------------------
    #------------------------------------------------------------------------------------------------
    function Store-PasswordsToFile{
        
        param(
            [Parameter (Mandatory=$True, Position=0)] [hashtable] $AccountsPlain,
            [Parameter (Mandatory=$True, Position=1)] [string] $StorePath,
            [Parameter (Mandatory=$False, Position=2)] [byte[]] $CipherKey,
            [Parameter (Mandatory=$False, Position=3)] [string] $CipherKeyName
        )

        $AccountsSecure = $AccountsPlain.Clone()

        if ($CipherKey){
        
            $AccountsPlain.GetEnumerator() | ForEach-Object {
    
                $FileName = -join ($_.key, '.', $CipherKeyName.Replace('.', '-'), '.psw')

                $AccountsSecure[$_.key] = ConvertTo-SecureString $_.value -AsplainText -Force
            
                ConvertFrom-SecureString -SecureString $AccountsSecure[$_.key] -Key $CipherKey |
                Set-Content $StorePath\$FileName
            }
        }

        else{

            $AccountsPlain.GetEnumerator() | ForEach-Object {
    
                $FileName = -join ($_.key, '.', 'OS-key', '.psw')
                
                $AccountsSecure[$_.key] = ConvertTo-SecureString $_.value -AsplainText -Force
                
                ConvertFrom-SecureString -SecureString $AccountsSecure[$_.key] |
                Set-Content "$StorePath\$FileName"
            }
        }
    }

    #------------------------------------------------------------------------------------------------
    function Store-PasswordsToDb{
        
        param(
            [Parameter (Mandatory=$True, Position=0)] [hashtable] $AccountsPlain,
            [Parameter (Mandatory=$True, Position=1)] [string] $SqlServer,
            [Parameter (Mandatory=$False, Position=2)] [byte[]] $CipherKey,
            [Parameter (Mandatory=$False, Position=3)] [string] $CipherKeyName
        )
        
        Prepare-DBConnection

        $User_Name = $AccountsPlain.Keys
        $PlainPassword = $AccountsPlain.Values
        $SecurePassword = ConvertTo-SecureString $PlainPassword -AsplainText -Force

        if ($CipherKey){
    
            $PasswordToStore = ConvertFrom-SecureString -SecureString $SecurePassword -Key $CipherKey

            $insert_query = "INSERT INTO [credentials].[dbo].[domain] `
                                    (username, password, cipher_key)`
                            VALUES ('$User_Name', '$PasswordToStore', '$CipherKeyName')"                 

            Invoke-Sqlcmd -Query $insert_query -ServerInstance $SqlServer -Database credentials
        }

        else{

            $PasswordToStore = ConvertFrom-SecureString -SecureString $SecurePassword

            $insert_query = "INSERT INTO [credentials].[dbo].[domain] `
                                    (username, password, cipher_key)`
                            VALUES ('$User_Name', '$PasswordToStore', 'OS')"                 

            Invoke-Sqlcmd -Query $insert_query -ServerInstance $SqlServer -Database credentials
        }
    }

    #------------------------------------------------------------------------------------------------
    function Generate-Key{
        
        param(
            [Parameter (Mandatory=$False)] [string] $FileName
            )

        if ($FileName){
        
            $Key = Import-Clixml "$WorkingDirectory\$FileName"

            return $Key
        }

        else{
        
            Write-Host `n "Key generation" `n`n -BackgroundColor DarkBlue
            
            $FileName = Read-Host -Prompt "Specify the keyfile name"
        
            Clear-Host
                
            [byte[]]$Key = Get-Random -InputObject (0..255) -Count 32
        
            $Key | Export-Clixml "$WorkingDirectory\$FileName.key"

            Write-Host `n "Encryption key saved to $WorkingDirectory\$FileName.key" -BackgroundColor DarkGreen `n`n
        }
    }

    #------------------------------------------------------------------------------------------------
    function Create-PassFile{

        $answer = Read-Host `n "Create file with passwords? (Y-yes, N-no)"

        if ($answer -eq 'y'){

            $UserName = Read-Host `n "Enter username"
            $Password = Read-Host `n "Enter password "
            
            $PlainCredentials = @{$UserName = $Password}

            if ((-not $UserName) -or (-not $Password)){
            
                Write-Host `n
                Write-Warning "You did not specify a username and password. A test pair will be used."
                Write-Host `n
                
                $PlainCredentials = @{

                    "user1" = "password1";
                    "user2" = "password2";
                }
            }

            $PlainCredentials | Export-Clixml -Path "$WorkingDirectory\$UserName.acn"
                    
            Clear-Host
            Write-Host `n "File with passwords saved in " $WorkingDirectory -BackgroundColor DarkGreen `n`n
        }
    }

    #------------------------------------------------------------------------------------------------
    function Encrypt-Password{
        
        Write-Host `n "Available credentials store destinations:" -BackgroundColor Blue `n`n
        Write-Host '1. File' `n
        Write-Host '2. Database' `n
        
        $CredentialsSource = Read-Host `n "Please select credentials store destination:"

        Clear-Host

        Write-Host `n "List of files containing credentials:" -BackgroundColor Blue `n

        $AccountsFiles = List-Files -FileExtension ".acn"
                
        $FileName = Read-Host `n "Specify the file number containing the credentials in need of encryption"

        $FileName = ($AccountsFiles[$FileName-1]).name

        $answer = Read-Host `n "Use custom encryption key (Y-yes, N-no)"

        $PlainCredentials = Import-Clixml "$WorkingDirectory\$FileName"
        
        Clear-Host

        if ($answer -eq 'y'){

            Write-Host `n "List of files containing encryption keys:" -BackgroundColor Blue `n

            $KeyFiles = List-Files -FileExtension ".key"

            $KeyFile = Read-Host `n "Specify the file number containing the required encryption key"

            $KeyFile = ($KeyFiles[$KeyFile-1]).name
                
            $Key = Generate-Key -FileName $KeyFile

            Clear-Host

            switch ($CredentialsSource) {

                1 {
                    Store-PasswordsToFile -AccountsPlain $PlainCredentials -StorePath $WorkingDirectory -CipherKey $Key -CipherKeyName $KeyFile

                    Write-Host `n -BackgroundColor DarkGreen "Files with encrypted passwords are saved in " $WorkingDirectory `n`n
                }
                2 {
                    Store-PasswordsToDb -AccountsPlain $PlainCredentials -SqlServer $SqlServer -CipherKey $Key -CipherKeyName $KeyFile

                    Write-Host `n -BackgroundColor DarkGreen "Files with encrypted passwords are saved to $SqlServer" `n`n
                }
            }

            Write-Host `n -BackgroundColor DarkGray "An encryption key specified by the user was used" `n`n
        }

        else{

            Clear-Host

            switch ($CredentialsSource) {

                1 {
                    Store-PasswordsToFile -AccountsPlain $PlainCredentials -StorePath $WorkingDirectory

                    Write-Host `n -BackgroundColor DarkGreen "Files with encrypted passwords are saved in " $WorkingDirectory `n`n
                }

                2 {
                    Store-PasswordsToDb -AccountsPlain $PlainCredentials -SqlServer $SqlServer

                    Write-Host `n -BackgroundColor DarkGreen "Files with encrypted passwords are saved to $SqlServer" `n`n
                }
            }
            
            Write-Host -BackgroundColor DarkGray "The OS default encryption key was used" `n`n
        }
    }

    #------------------------------------------------------------------------------------------------
    function Decrypt-Password{

        Write-Host `n "Available credentials sources:" -BackgroundColor Blue `n`n
        Write-Host '1. File' `n
        Write-Host '2. Database' `n
        
        $CredentialsSource = Read-Host `n "Please select credentials source:"

        Clear-Host

        switch ($CredentialsSource) {

            1 {
                Write-Host `n "List of files containing encrypted passwords:" -BackgroundColor Blue `n

                $AccountsFiles = List-Files -FileExtension ".psw"
                        
                Write-Host `n
                        
                $FileName = Read-Host -Prompt "Specify the file number containing the required password"
        
                Write-Host `n
        
                $FileName = ($AccountsFiles[$FileName-1]).name
        
                if ($FileName.Contains('OS-key')){
        
                    $RestoredPassword = Get-Content $WorkingDirectory\$FileName | ConvertTo-SecureString
        
                    $CurrentCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $FileName, $RestoredPassword
                                
                    Clear-Host
                    Write-Host `n -BackgroundColor DarkBlue "Your username : password is: " `n
                    Write-Host ($FileName.split(".") | Select-Object -First 1) " : " $CurrentCredential.GetNetworkCredential().Password `n`n
                    Write-Host -BackgroundColor DarkGray "The OS default encryption key was used" `n`n
                }
        
                else{
        
                    Write-Host `n "List of files containing encryption keys:" -BackgroundColor Blue `n
        
                    $KeyFiles = List-Files -FileExtension ".key"
                            
                    $KeyFile = Read-Host `n "Specify the file number containing the encryption key"
        
                    $KeyFile = ($KeyFiles[$KeyFile-1]).name
        
                    $Key = Generate-Key -FileName $KeyFile
                            
                    $RestoredPassword = Get-Content $WorkingDirectory\$FileName | ConvertTo-SecureString -Key $Key
        
                    $CurrentCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $FileName, $RestoredPassword
                                
                    Clear-Host
                    Write-Host `n -BackgroundColor DarkBlue "Your username : password is: " `n
                    Write-Host `n ($FileName.split(".") | Select-Object -First 1) " : " $CurrentCredential.GetNetworkCredential().Password `n`n
                    Write-Host -BackgroundColor DarkGray "An encryption key specified by the user was used" `n`n
        
                }
            }

            2 {

                Prepare-DBConnection

                $select_query = "SELECT [username]
                                FROM [credentials].[dbo].[domain]"

                $UsersList = Invoke-Sqlcmd -Query $select_query -ServerInstance $SqlServer -Database credentials

                $UsersList = $UsersList.username
                
                Write-Host `n "List of usernames corresponding to encrypted passwords:" -BackgroundColor Blue `n

                Enumerate-Collection -Collection $UsersList

                $UserName = Read-Host -Prompt "Specify the username which correspond to required password"

                $UserName = $UsersList[$UserName-1]

                $select_query = "SELECT [password]
                                FROM [credentials].[dbo].[domain]
                                WHERE [username] = '$UserName' AND [cipher_key] = 'OS'"

                $Password = Invoke-Sqlcmd -Query $select_query -ServerInstance $SqlServer -Database credentials

                $Password = $Password.password

                if ($Password){

                    $Password

                    $RestoredPassword = $Password | ConvertTo-SecureString

                    $CurrentCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $RestoredPassword

                    Clear-Host
                    Write-Host `n -BackgroundColor DarkBlue "Your username: $UserName, your password:" $CurrentCredential.GetNetworkCredential().Password `n
                    Write-Host -BackgroundColor DarkGray "The OS default encryption key was used" `n`n
                }

                else {
                    
                    $select_query = "SELECT [password]
                                    FROM [credentials].[dbo].[domain]
                                    WHERE [username] = '$UserName' AND [cipher_key] != 'OS'"

                    $Password = (Invoke-Sqlcmd -Query $select_query -ServerInstance $SqlServer -Database credentials).password
                            
                    Write-Host `n`n "List of files containing encryption keys:" -BackgroundColor Blue `n
        
                    $KeyFiles = List-Files -FileExtension ".key"
                            
                    $KeyFile = Read-Host `n "Specify the file number containing the encryption key"
        
                    $KeyFile = ($KeyFiles[$KeyFile-1]).name
        
                    $Key = Generate-Key -FileName $KeyFile

                    $RestoredPassword = $Password | ConvertTo-SecureString -Key $Key
        
                    $CurrentCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $RestoredPassword
                                
                    Clear-Host
                    Write-Host `n -BackgroundColor DarkBlue "Your username: $UserName, your password:" $CurrentCredential.GetNetworkCredential().Password `n
                    Write-Host -BackgroundColor DarkGray "An encryption key specified by the user was used" `n`n
                }
            }
        }
    }

    #------------------------------------------------------------------------------------------------
    #Supplementary functions
    #------------------------------------------------------------------------------------------------

    function Prepare-DBConnection{

        $select_query ="SELECT *
                        FROM [credentials].[dbo].[domain]
                        ORDER BY [id]"
    
        try{
            $tmp = Invoke-Sqlcmd -Query $select_query -ServerInstance $SqlServer -Database credentials
        }
        catch{
            Import-Module sqlserver -NoClobber -Force -ErrorAction SilentlyContinue
        }
    
        try{
            $tmp = Invoke-Sqlcmd -Query $select_query -ServerInstance $SqlServer -Database credentials
        }
        catch{
        
            Install-module -Name sqlserver -AllowClobber -Force
        }
    }

    #Shows user tasks menu
    #------------------------------------------------------------------------------------------------
    function Show-Menu{

        Write-Host `n "Available actions:" `n -BackgroundColor DarkBlue

        foreach ($Option in $MenuOptions.GetEnumerator()){
            
            if ($Option.value -eq $True){
                
                Write-Host $Option.key
            }
            
            else{
            
                Write-Host $Option.key -ForegroundColor DarkGray
            }
        }
        
        Write-Host `n

        $OptionNumber = Read-host "Please select required action ('q' - quit)"

        return $OptionNumber
    }

    #------------------------------------------------------------------------------------------------
    function Select-Task{

        $deal = 0

        while ($deal -ne 'q'){

            Clear-Host

            $deal = Show-Menu
        
            Clear-Host

            switch($deal){

                1 {Create-PassFile; pause; Clear-Host}
                2 {Generate-Key; pause; Clear-Host}
                3 {Encrypt-Password; pause; Clear-Host}
                4 {Decrypt-Password; pause; Clear-Host}

                'q' {break}
            }
        }
    }
    
    #------------------------------------------------------------------------------------------------
    function List-Files{

        param ([Parameter (Mandatory=$True, Position=0)] [string] $FileExtension)
    
        $Files = $WorkingDirectory | Get-ChildItem |
        Where-Object -Property Extension -EQ $FileExtension |
        Select-Object -Property Name
    
        $number = 1
    
        foreach ($File in $Files){
        
            Write-Host "$number. " $File.Name
        
            $number++
        }
    
        return $Files
    }

    #------------------------------------------------------------------------------------------------
    function Enumerate-Collection{

        param([Parameter (Mandatory=$True, Position=0)] $Collection)
    
        $index = 1
    
        foreach ($Element in $Collection){
    
            Write-Host $index'.' $Element
    
            $index++
        }
    
        Write-Host `n    
    }

    #------------------------------------------------------------------------------------------------
    #Main function
    #------------------------------------------------------------------------------------------------

    Clear-Host
    Write-Host `n "In the working folder, processing with passwords and encryption keys will take place (creation, receipt, encryption, decryption)" `n -BackgroundColor DarkBlue

    if (-not $WorkingDirectory){

        $WorkingDirectory = Read-Host -Prompt "Please specify a working folder (format: X:\my\directory)"
    }

    if (-not (Test-Path $WorkingDirectory)){

        New-Item -Path $WorkingDirectory -ItemType Directory | Out-Null
    }

    Select-Task
}
