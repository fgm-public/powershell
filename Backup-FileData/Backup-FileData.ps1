
<#
.SYNOPSIS
    Backup custom filesystem location

.DESCRIPTION
    Backup custom folder specified in $periodicity parameter passed from outside the script

.PARAMETER periodicity
    Specifies filesystem path, located in root of logical disk, where will be backuped to 

.EXAMPLE
    Not for interactive use.
    Schedule it with Windows Task Scheduler, for example:

        Powershell.exe -Command "& 'C:\backup_scripts\Backup-FileData.ps1' -periodicity 'daily'"
        
.NOTES
    17.01.2019 - public version
#>

Param ([Parameter (Mandatory=$True, Position=0)] [string] $periodicity)

$BackupSourceDrive = 'B:'
$BackupDestinationDrive = 'A:'

$ArchivaPath = '\work\all'

$BackupSource = "$BackupSourceDrive\$ArchivaPath"
$BackupDestination = "$BackupDestinationDrive\$periodicity\$ArchivaPath"

$BackupSpecs = '/MIR /Z /COPY:DATSO /MT /R:4 /W:10 /V'

$BackupLog = "/UNILOG+:C:\backup_scripts\logs\backup-$periodicity.log"

$BackupParams = "$BackupSpecs $BackupLog"

$BackupArguments = "$BackupSource $BackupDestination $BackupParams"

if (Get-ChildItem $BackupSource){

    Start-Process -FilePath Robocopy -ArgumentList $BackupArguments
}
