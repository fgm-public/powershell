$Date = (Get-Date).ToString('dd.MM.yyyy')
$RetainBackupsCount = 3
$TasksPath = "\MyTasks\*"
$BackUpDestination = "c:\adm_stuff\tasks\backup"

function Retain-BackupsQuantity{

    if (Test-Path -Path $BackUpDestination){

        $Backups = Get-ChildItem $BackUpDestination
        $BackupsToDelete = $Backups.count - $RetainBackupsCount

        if ($BackupsToDelete -gt 0){

            $BackupsList = $Backups |
                Sort-Object CreationTime |
                    Select-Object -Last $BackupsToDelete

            $BackupsList |
                Remove-Item -Recurse -Force
        }
    }
}

function BackUp-Tasks{

    if (-not (Test-Path -Path "$BackUpDestination\$Date")){
        New-Item -Path "$BackUpDestination\$Date" -Type Directory
	    $BackUpDestination = Join-Path $BackUpDestination $Date
    }

    Get-ScheduledTask -TaskPath $TasksPath |
        ForEach-Object {
            Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath |
                Out-File (Join-Path $BackUpDestination "$($_.TaskName).xml")
        }
}