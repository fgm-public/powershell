function Elevate-Shell{
    <#
    .SYNOPSIS
        Elevates powershell command shell privileges to administrator, if not yet.

    .DESCRIPTION
        When called without '-ScriptFile' parameter, run new powershell console with administrator privileges, if current isn't privileged.
        When called with '-ScriptFile' parameter, run powershell script with administrator privileges in new console, if current isn't privileged. Or in current console, if it already elevated.

    .PARAMETER ScriptFile
        Filesystem path to powershell script to be executed (optional)

    .EXAMPLE
        Elevate-Shell

        Simply open new elevated powershell window, if current is not privileged, else message that current shell is already elevated

    .EXAMPLE
        Elevate-Shell -ScriptFile 'c:\my_sripts\ms_favorite_script.ps1'

        Run powershell 'ms_favorite_script' ps1 script located in 'c:\my_sripts' folder in current command shell, if current shell is privileged.
        Else, run powershell 'ms_favorite_script' ps1 script located in 'c:\my_sripts' folder in new elevated command shell.
    
    .NOTES
        14.01.2019 - public version
    #>

    param(
          [Parameter(Mandatory=$False, Position=0)]
          [string] $ScriptFile
	)

    $CurrentWindowsUserId = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $CurrentWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($CurrentWindowsUserId)
    $AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    $IsAdmin = $CurrentWindowsPrincipal.IsInRole($AdminRole)

    if (-not $IsAdmin){
        if ($ScriptFile){
            Write-Host `n "Run $ScriptFile scenario in elevated mode . . . "
            
            $start_process = @{
                FilePath = 'powershell.exe';
                Verb = 'runas';
                WindowStyle = 'Maximized';
            }
            Start-Process @start_process -ArgumentList $ScriptFile
        }
        else {
            Write-Host -BackgroundColor DarkRed `n "Current shell operate in restricted mode" `n
            $answer = Read-Host -Prompt "Elevate shell? (y-yes, n-no)"

            if ($answer -eq "y"){
                Start-Process @start_process
            }
        }
    }else {
        if ($ScriptFile){
            Write-Host `n
            Write-Warning "Can't elevate. Current shell already operate in unrestricted mode"
            Write-Host `n "Attempt to run $ScriptFile scenario in elevated mode . . . " `n
            Start-Process -FilePath 'powershell.exe' -ArgumentList $ScriptFile -NoNewWindow
        }else {
            Write-Host `n
            Write-Warning "Can't elevate. Current shell already operate in unrestricted mode"
        }
    }
    Write-Host `n
}