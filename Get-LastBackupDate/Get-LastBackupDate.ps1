
<#
.SYNOPSIS
    Reports on userspace backup status

.DESCRIPTION
    Gets information about last date of userspace backups.
    Groups users according to the time since last backup was.
    Forms HTML report based on the above facts and email it.
    Well bound with 'BackUp-UserData' script

.EXAMPLE
    In the main, not for interactive use.
    Schedule it with Windows Task Scheduler and get profit.
    For example:

        Program/script: Powershell.exe
        Add arguments (optional): -Command "& 'C:\adm_stuff\backup\Report-LastBackupDate.ps1'

.NOTES
    02.04.2019 - public version
#>

#$VerbosePreference = 'Continue'

$report_style = @'
<style>
body {background-color:#dddddd;font-family:Tahoma;font-size:12pt;}
td, th {border:1px solid black;border-collapse:collapse;}
th {color:white;background-color:black;}
table, tr, td, th {padding: 2px; margin: 0px}
table {margin-left:50px;}
</style>
'@

$BackupPath = '\\Backup\Path'
$SqlServer = 'sql-server'
$KeyStore = '\\Shielded\Store\CipherKeys'
$ReportSource = 'admin@corp.contoso.com'
$ReportDestination = 'admin@corp.contoso.com'
$Key = Import-Clixml "$KeyStore\$ReportSource.key"

function Get-LastBackupDate{

    $Script:LastBackupByUser = [ordered]@{}

    $BackupLogs = Get-ChildItem $BackupPath -Depth 2 |
        Where-Object {$_.name -eq 'backup.log'}

    Get-Item -Path $BackupLogs.FullName |
       Sort-Object LastWriteTime -Descending |
            ForEach-Object {
                $LastBackupByUser.Add($_.FullName.TrimEnd('\backup.log').Substring($BackupPath.Length),
                $_.LastWriteTime)
            }
    Write-Verbose ($LastBackupByUser | Out-String)
}
 
 function Get-BackupedUsers{
 
    Get-ChildItem $BackupPath |
    ForEach-Object {
        if (Test-Path (Join-Path $_.FullName '\settings')){
            $Script:BackupedUsers += -join $_.Name, "`n"
        }
    }
    Write-Verbose $BackupedUsers
}

function Group-UsersByLastBackupDate{

    $Script:BackupedLastWeek = [ordered]@{}
    $Script:BackupedLongAgo =  [ordered]@{}

    $LastBackupByUser.GetEnumerator() |
        ForEach-Object {
            if ($_.Value -gt (Get-Date).AddDays(-7)){
                $BackupedLastWeek.Add($_.key, $_.Value)
            }else{
                $BackupedLongAgo.Add($_.key, $_.Value)
            }
        }

    Write-Verbose ($BackupedLastWeek | Out-String)
    Write-Verbose ($BackupedLongAgo | Out-String)
}

function Test-DBConnection{

    $select_query = "SELECT *
                    FROM [credentials].[dbo].[contoso]
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
        Invoke-Sqlcmd @invoke_params | Out-Null
    }catch{
        Import-Module @module_params -NoClobber -ErrorAction Ignore
    }

    try{
        Invoke-Sqlcmd @invoke_params | Out-Null
    }catch{
        Install-module @module_params -AllowClobber
    }
}

function Request-Credentials{
    
    Test-DBConnection
    
    $select_query = "SELECT [password]
                    FROM [credentials].[dbo].[contoso]
                    WHERE [username] = '$ReportSource'
                    AND [cipher_key] != 'OS'"

    $invoke_params = @{
        Query = $select_query;
        ServerInstance = $SqlServer;
        Database = 'credentials';
    }
    $Password = (Invoke-Sqlcmd @invoke_params).Password

    $RestoredPassword = $Password |
        ConvertTo-SecureString -Key $Key

    $params = @{
        TypeName = 'System.Management.Automation.PSCredential';
        ArgumentList = $ReportSource, $RestoredPassword;
    }
    $Script:Credentials = New-Object @params
    
    Write-Verbose $Credentials.Username
}

function Set-BackupReport{

    Get-LastBackupDate

    Group-UsersByLastBackupDate

    $last_week = @{
        TypeName = 'PSObject';
        Property = $BackupedLastWeek
    }
    $last_convert = @{
        Fragment = $true
        PreContent = '<h2>Last week backuped</h2><br>';
        As = 'List'
    }
    $LastWeek = New-Object @last_week |
                    ConvertTo-Html @last_convert |
                        Out-String

    $ago_week = @{
        TypeName = 'PSObject';
        Property = $BackupedLongAgo
    }
    $ago_convert = @{
        Fragment = $true
        PreContent = '<h2>More than a week ago</h2><br>';
        As = 'List'
    }
    $AgoWeek = New-Object @ago_week |
                    ConvertTo-Html @ago_convert |
                        Out-String

    $content = @{
        Head = $report_style;
        PostContent = $LastWeek, $AgoWeek;
        Title = '<h2>Userspace backups weekly summary</h2><br>';
        As = 'List'
    }
    $Script:Report = ConvertTo-Html @content |
                        Out-String

}

function Send-BackupReport{

    Request-Credentials
    Set-BackupReport
    
    $message = @{
        From = $ReportSource;
        To = $ReportDestination;
        SmtpServer = 'mail.contoso.com';
        Credential = $Credentials;
        Subject = 'Userspace backups weekly summary';
        Body = $Report;
        BodyAsHTML = $true;
    }
    Send-MailMessage @message
    
    Write-Verbose $Report
}

Send-BackupReport