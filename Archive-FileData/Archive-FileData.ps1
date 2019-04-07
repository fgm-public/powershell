
<#
.SYNOPSIS
    Archive custom filesystem location

.DESCRIPTION
    Archive custom folder specified in $periodicity parameter passed from outside the script

.PARAMETER periodicity
    Specifies filesystem path, located in root of logical disk, where will be archived from/to 

.EXAMPLE
    Not for interactive use.
    Schedule it with Windows Task Scheduler, for example:

        Powershell.exe -Command "& 'C:\backup_scripts\Archive-Data.ps1' -periodicity 'monthly'"
        
.NOTES
    17.01.2019 - public version
#>

Param(
      [Parameter (Mandatory=$True, Position=0)] [string] $periodicity,
      [Parameter (Mandatory=$True, Position=1)] [string] $BackupLogName
      )


$EventLogName = 'MyBackup'
$EventLogSource = $BackupLogName

$LogPath = 'C:\adm_stuff\backup\logs'
$LogName = "$BackupLogName-$periodicity.log"
$ArchiveLog = "/UNILOG:$LogPath\$LogName"
$ArchiveLogPath = "$LogPath\$LogName"

$ArchiveSourceDrive = 'B:'
$ArchiveDestinationDrive = 'A:'
$ArchiveSource = "$ArchiveSourceDrive\$periodicity"
$ArchiveDestination = "$ArchiveDestinationDrive\$periodicity"
$ArchiveSpecs = '/MIR /Z /COPY:DATSO /MT /R:4 /W:10 /V'
$ArchiveParams = "$ArchiveSpecs $ArchiveLog"
$ArchiveArguments = "$ArchiveSource $ArchiveDestination $ArchiveParams"

$ArchiveDisk = (Get-Disk |
                    Where-Object -Property BusType -eq iSCSI)

if ($ArchiveDisk.OfflineReason -ne "Policy"){

    if ($ArchiveDisk.IsOffline -eq $true){

        $ArchiveDisk |
            Set-Disk -IsOffline $false

        $ArchiveDisk |
            Set-Disk -IsReadOnly $false

        Start-Sleep -Seconds 10
    }

    if (Get-ChildItem $ArchiveSource ){

        $RunTime = Measure-Command -Expression {
            Start-Process -FilePath robocopy.exe -ArgumentList "$ArchiveArguments"
        }
    }

    $ArchiveDisk |
        Set-Disk -IsOffline $true

    . "C:\adm_stuff\backup\logs\Write-ScriptLog.ps1"

    if ($RunTime.Seconds -gt 5){

        $write_scriptlog = @{
            LogName = $EventLogName;
            SourceName = $EventLogSource;
            BackupParams = $ArchiveArguments;
        }
        Write-ScriptLog @write_scriptlog
    }
    else{

        Write-ScriptLog @write_scriptlog -Idle
    }
}