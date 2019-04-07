
<#
.SYNOPSIS
    Backup custom filesystem location

.DESCRIPTION
    Backup custom filesystem location specified in $BackupSource parameter
    to filesystem location specified in $BackupDestination parameter passed from outside the script.
    Uses native MS 'robocopy' utility under the hood.
    Optionally can eventlogging into system log with 'Write-ScriptLog.ps1' adjunct.
    Handle (turn online/offline) disk access status based on disk 'OperationalStatus'
    to prevent malware activity when backup disk is idle

.PARAMETER BackupSource
    Specifies filesystem location, where backup stuff will come from.

.PARAMETER BackupDestination
    Specifies filesystem location, where backup stuff will be placed.

.PARAMETER BackupExcludeList
    Specifies nested filesystem location, which will be exclude from $BackupSource in the backup process.

.PARAMETER BackupLogName
    Specifies 'robocopy' backup log name and EventLog source.

.EXAMPLE
    In the main, not for interactive use.
    Schedule it with Windows Task Scheduler and get profit.
    For example:

        Program/script: Powershell.exe
        Add arguments (optional): -Command "& 'C:\adm_stuff\backup\BackUp-FileData.ps1'
                                  -BackupSource 'F:\'
                                  -BackupDestination 'H:\'
                                  -BackupExcludeList 'F:\fb_backup\USMT\Migration'
                                  -BackupLogName 'auto-F2H'
                                  -VerifySuccess"

        Program/script: Powershell.exe
        Add arguments (optional): -Command "& 'C:\adm_stuff\backup\BackUp-FileData.ps1'
                                  -BackupSource '\\fb-lks-mssql\backup'
                                  -BackupDestination 'F:\fb_backup\lks\SQL\fb-lks-mssql'
                                  -BackupLogName 'fb-mssql_backup'
                                  -VerifySuccess"        

.NOTES
    28.03.2019 - private version
#>

Param (
    [Parameter (Mandatory=$True, Position=0)] [string] $BackupSource,
    [Parameter (Mandatory=$True, Position=1)] [string] $BackupDestination,
    [Parameter (Mandatory=$False, Position=2)] [string] $BackupExcludeList,
    [Parameter (Mandatory=$False, Position=3)] [string] $BackupLogName,
    [Parameter (Mandatory=$False, Position=4)] [switch] $VerifySuccess
    )

$EventLogSource = $BackupLogName
$EventLogName = 'MyBackup'

$BackupDiskGUID = '{50504040-d1a0-438d-b7a8-240bb69983cb}'
$BackupDisk = Get-Disk |
                Where-Object -Property Guid -eq $BackupDiskGUID

$BackupSpecs = '/MIR /Z /COPY:DATSO /MT /R:4 /W:10 /V'

if ($BackupLogName){
    $BackupLog = "/UNILOG:C:\adm_stuff\backup\logs\$BackupLogName.log"
}
else{
    $BackupLog = ""
}

if ($BackupExcludeList){
    $BackupExclude = "/XD '$BackupExcludeList'"
}
else{
    $BackupExclude = ""
}

$BackupParams = "$BackupExclude $BackupSpecs $BackupLog"
$BackupArguments = "$BackupSource $BackupDestination $BackupParams"

. "C:\adm_stuff\backup\logs\Write-ScriptLog.ps1"

if ($BackupDisk.IsOffline -eq $true){

    $BackupDisk |
        Set-Disk -IsOffline $false

    $BackupDisk |
        Set-Disk -IsReadOnly $false

    Start-Sleep -Seconds 10
}

if ($VerifySuccess){

    $BeforeCast = (Get-ChildItem $BackupDestination -Recurse).Count

    if (Get-ChildItem $BackupSource){
        $start_process = @{
             FilePath = 'robocopy.exe';
             ArgumentList = $BackupArguments;
             Wait = $true;
        }
        Start-Process @start_process
    }

    $AfterCast = (Get-ChildItem $BackupDestination -Recurse).Count

    if ($BeforeCast -ne $AfterCast){

        $write_scriptlog = @{
            LogName = $EventLogName;
            SourceName = $EventLogSource;
            BackupParams = $BackupArguments;
        }
        Write-ScriptLog @write_scriptlog
    }
    else{
        Write-ScriptLog @write_scriptlog -Idle
    }
}
else{
        if (Get-ChildItem $BackupSource){

            Start-Process @start_process
        }

        Write-ScriptLog @write_scriptlog
}

$BackupDisk |
    Set-Disk -IsOffline $true
