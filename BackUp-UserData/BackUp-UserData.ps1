
<#
.SYNOPSIS
    Backup user data and eventlog to syslog

.DESCRIPTION
    Backup custom folders in user profile which specified in 'sources.bsf' file,
    located in backup destination and eventlogging into system log with.
    Register backup event details (date, compname, username) into SQL DB.
    Uses native MS 'robocopy' utility under the hood.

.EXAMPLE
    In the main, not for interactive use.
    Link it with PC GPO, for example.

.NOTES
    02.04.2019 - public version
#>

$Date = Get-Date -Format yyyy-MM-dd
$EventLogName = 'UserBackUp'
$EventLogSource = $env:USERNAME
$SqlServer = 'sql-server'
$BackUpDestinationServer = '\\backup-servrer'
$BackUpDestinationPlace = 'backup$'
$SourceListFile = 'sources.bsf'
$BackUpSourcesList = "$BackUpDestinationServer\$BackUpDestinationPlace\$env:USERNAME\settings\$SourceListFile"
$BackupSpecs = '/MIR /COPY:DATSO /R:0 /W:0 /Z /V' #/NOOFFLOAD /ZB /MT:128

function Test-DBConnection{

    $select_query = "SELECT *
                    FROM [backup].[dbo].[nstu]
                    ORDER BY [id]"

    $invoke_params = @{
        Query = $select_query;
        ServerInstance = $SqlServer;
        Database = 'credentials';
    }
    
    $module_params = @{
        Name = 'sqlserver';
        Force = $true;
    }
    try{
        Invoke-Sqlcmd @invoke_params |
            Out-Null
    }catch{
        Import-Module @module_params -NoClobber -ErrorAction Ignore
    }
    try{
        Invoke-Sqlcmd @invoke_params |
            Out-Null
    }catch{
        Install-module @module_params -AllowClobber
    }
}

function Register-BackupEventToDB{

    Test-DBConnection

    $select_query = "SELECT [id]
                     FROM [backups].[dbo].[users]
                     WHERE [computer_name] = '$env:COMPUTERNAME'
                     AND [user_name] = '$env:USERNAME'"

    $invoke_params = @{
        Query = $select_query;
        ServerInstance = $SqlServer;
        Database = 'backups';
    }
    $SQLRecord = (Invoke-Sqlcmd @invoke_params).id

    if (-not $SQLRecord){
        $query = "INSERT INTO [backups].[dbo].[users]
                 (last_backup, first_backup, user_name, computer_name)
                 VALUES ('$Date', '$Date', '$env:USERNAME', '$env:COMPUTERNAME')"           
    }else{
        $query = "UPDATE [backups].[dbo].[users]
                        SET last_backup='$Date'
                        WHERE id='$SQLRecord'"
    }

    $invoke_params = @{
        Query = $query;
        ServerInstance = $SqlServer;
        Database = 'backups';
    }
    Invoke-Sqlcmd @invoke_params
}

function Register-BackupEventToEventLog{

    $new_eventlog = @{
        LogName = $EventLogName;
        Source = $EventLogSource;
        ErrorAction = 'SilentlyContinue';
    }
    New-EventLog @new_eventlog

    $EventLogMessage = "The $EventLogSource was finished BACKUP work at $Date"

    $write_eventlog = @{
        LogName = $EventLogName;
        Source = $EventLogSource;
        Message = $EventLogMessage;
        EventId = '0';
        EntryType = 'Information';
    }
    Write-EventLog @write_eventlog
}

function Backup-UserSpace{

    if (Test-Path $BackUpSourcesList){

        $BackUpDestination = "$BackUpDestinationServer\$BackUpDestinationPlace\$env:USERNAME\$env:COMPUTERNAME"
        $BackUpSource = $env:USERPROFILE
        $FoldersToBackup = Get-Content $BackUpSourcesList

        foreach ($folder in $FoldersToBackup){

            if (-not (Test-Path $BackUpDestination\$folder)){

                New-Item $BackUpDestination\$folder -Type Directory
            }

            $BackupLog = "/UNILOG+:$BackUpDestination\backup.log"
            $BackupParams = "$BackupSpecs $BackupLog"
            $BackupArguments = "$BackUpSource\$folder $BackUpDestination\$folder $BackupParams"

            $start_process = @{
                FilePath = 'robocopy.exe';
                ArgumentList = $BackupArguments;
                Wait = $true;
            }
            Start-Process @start_process
        }
        Register-BackupEventToDB
        Register-BackupEventToEventLog
    }
}

Backup-UserSpace