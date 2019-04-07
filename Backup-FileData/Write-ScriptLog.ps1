function Write-ScriptLog{
    <#
    .SYNOPSIS
        Syslogged Backup results

    .DESCRIPTION
        Eventlogging into system log results and detailes of backup procedure

    .PARAMETER LogName
        Specifies log name in EventLog namespace.

    .PARAMETER SourceName
        Specifies SourceName in certain log.
        
    .PARAMETER BackupParams
        Specifies backup parameters passed from outside the script.

    .PARAMETER Idle
        Specifies whether backuped something or not.

    .EXAMPLE
        In the main, not for interactive use.
        Invoke this script from BackUp-FileData.ps1 and get profit.
        For example:

            . ".\logs\Write-ScriptLog.ps1"

            Write-ScriptLog -LogName $EventLogName `
                            -SourceName $EventLogSource `
                            -BackupParams $BackupArguments
            
    .NOTES
        21.03.2019 - public version
    #>    
    param(
          [Parameter (Mandatory=$True, Position=0)][string]$LogName,
          [Parameter (Mandatory=$True, Position=1)][string]$SourceName,
          [Parameter (Mandatory=$True, Position=2)][string]$BackupParams,
          [Parameter (Mandatory=$False, Position=3)][switch]$Idle
          )
    
    $Date = Get-Date

    New-EventLog -LogName $LogName -Source $SourceName -ErrorAction SilentlyContinue
    
    if ($Idle){
    
        Write-EventLog -LogName $LogName `
                       -Source $SourceName `
                       -Message "The $SourceName was finished IDLE work at $Date. `n Details:  $BackupParams" `
                       -EventId 1 `
                       -EntryType Information
    }else{
    
        Write-EventLog -LogName $LogName `
                       -Source $SourceName `
                       -Message "The $SourceName was finished BACKUP work at $Date. `n Details:  $BackupParams" `
                       -EventId 0 `
                       -EntryType Information
    }
}