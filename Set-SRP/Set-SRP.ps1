function Set-SRP{
    <#
    .SYNOPSIS
        Get and Set SRP Policy.

    .DESCRIPTION
        Get current SRP policy and optionally set it at will

    .PARAMETER Enable
        Enable SRP if $true, disable if $false

    .EXAMPLE
        Set-SRP

        Starts interactive Get/Set session 

    .EXAMPLE
        Set-SRP -Enable $true

        Enable SRP
    
    .NOTES
        17.01.2019 - public version
    #>

    param(
        [Parameter(Mandatory=$False, Position=0)]
        [string] $Enable
    )

    #------------------------------------------------------------------------------------------------
    #Global initialization
    #------------------------------------------------------------------------------------------------
    $CurrentWindowsUserId = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $CurrentWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($CurrentWindowsUserId)
    $AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    $IsAdmin = $CurrentWindowsPrincipal.IsInRole($AdminRole)

    #------------------------------------------------------------------------------------------------
    #Global data
    #------------------------------------------------------------------------------------------------
    $SRPSwitchPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers\'

    $SRPSwitch = @{
                    On = '00000000'
                    Off = '00040000'
                }

    $enable_srp = @{
        Path = $SRPSwitchPath;
        Name = 'DefaultLevel';
        Value = $SRPSwitch['On']
    }

    $disable_srp = @{
        Path = $SRPSwitchPath;
        Name = 'DefaultLevel';
        Value = $SRPSwitch['Off']
    }

    #------------------------------------------------------------------------------------------------
    #Common functions
    #------------------------------------------------------------------------------------------------
    function Get-SRP{
        param(
            [Parameter(Mandatory=$False, Position=0)]
            [switch] $Report
        )

        $presence = (Get-ItemProperty -Path $SRPSwitchPath -Name DefaultLevel).DefaultLevel -eq 0
        
        if($Report){
            if ($presence){
                Write-Host `n "SRP works!" -BackgroundColor Green `n`n
            }else{
                Write-Host `n "SRP disabled!" -BackgroundColor DarkRed `n`n
            }
        }else{
            return $presence
        }
    }
        
    #------------------------------------------------------------------------------------------------
    #Main function
    #------------------------------------------------------------------------------------------------
    if (-not $IsAdmin){
        Write-Warning "Current shell operate in restricted mode. Administrator privileges required"
        Write-Host `n
        break
    }

    if ($Enable){
        switch ($Enable){
            'Yes'{
                Set-ItemProperty @enable_srp
                Get-SRP -Report
            }
            'No'{
                Set-ItemProperty @disable_srp
                Get-SRP -Report
            }
        }
    }else{
        while ($answer -ne 'q'){
            Clear-Host
    
            if (Get-SRP){
                Write-Host `n "SRP works!" -BackgroundColor Green `n`n
                $answer = Read-Host -Prompt "Disable SRP? (Y-'Yes', N-'No', Q-'Quit')"
    
                if ($answer -eq "y"){
                    Set-ItemProperty @disable_srp
                }
            }else{
    
                Write-Host `n "SRP disabled!" -BackgroundColor DarkRed `n`n
                $answer = Read-Host -Prompt "Enable SRP? (Y-'Yes', N-'No', Q-'Quit')"
    
                if ($answer -eq "y"){
                    Set-ItemProperty @enable_srp
                }
            }
        }
        Write-Host `n
    }
}