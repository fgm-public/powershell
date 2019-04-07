function Test-PSRemote{
    
    <#
    .SYNOPSIS
        Test local workstation for psremoting readiness.

    .DESCRIPTION
        Checks that WinRM service and firewall settings on local workstation was configured properly for WinRM operation.

    .EXAMPLE
        Test-PSRemote
        Simply checks WinRM prerequisites on local workstation and message short report

    .NOTES
        Note, that KES checking works, only if KES firewall policies was configured properly.
    
        14.01.2019 - public version
    #>
    
    Clear-Host

    if ((Get-Service -Name WinRM).Status -eq "Running"){
        Write-Host `n "WinRM service is running" -BackgroundColor DarkGreen `n
    }else{
        Write-Host `n "WinRM service is not working" -BackgroundColor DarkRed `n
    }

    if ((Get-Service -Name AVP).Status -eq "Running"){
        Write-Host "Kaspersky firewall allows to open connections for WinRM" -BackgroundColor DarkGreen `n
    }else{
        if ((Get-NetFirewallRule |
                Where-Object {$_.DisplayName -match "Удалённое управление Windows*"}).name -eq 4){
            Write-Host "Windows firewall allows to open connections for WinRM" -BackgroundColor DarkGreen `n
        }else{
            Write-Host "Windows Firewall does not allow opening connections for WinRM" -BackgroundColor DarkRed `n
        }
    }
}
