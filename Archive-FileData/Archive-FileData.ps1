
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

        Powershell.exe -Command "& 'C:\backup_scripts\Archive-FileData.ps1' -periodicity 'monthly'"
        
.NOTES
    17.01.2019 - public version
#>

Param ([Parameter (Mandatory=$True, Position=0)] [string] $periodicity)


$ArchiveSourceDrive = 'B:'
$ArchiveDestinationDrive = 'A:'

$ArchiveSource = "$ArchiveSourceDrive\$periodicity"
$ArchiveDestination = "$ArchiveDestinationDrive\$periodicity"

$ArchiveSpecs = '/MIR /Z /COPY:DATSO /MT /R:4 /W:10 /V'

$ArchiveLog = "/UNILOG+:C:\backup_scripts\logs\archive-$periodicity.log"

$ArchiveParams = "$ArchiveSpecs $ArchiveLog"

$ArchiveArguments = "$ArchiveSource $ArchiveDestination $ArchiveParams"


$ArchiveDisk = (Get-Disk | Where-Object -Property BusType -eq iSCSI)

#if ($ArchiveDisk.OfflineReason -eq "Policy")

if ($ArchiveDisk.IsOffline -eq $true){

    $ArchiveDisk | Set-Disk -IsOffline $false

    $ArchiveDisk | Set-Disk -IsReadOnly $false
}

if (Get-ChildItem $ArchiveSource){

    Start-Process -FilePath Robocopy -ArgumentList $ArchiveArguments
}

$ArchiveDisk | Set-Disk -IsOffline $true
