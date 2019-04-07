
function Invoke-Remote{
    <#
    .SYNOPSIS
        Invoke 'ps1' scenario on remote hosts (with blackjack and hookers).

    .DESCRIPTION
        Invoke scenario located in 'ps1' file on remote hosts with logging.
        Previously, checks connectivity wia WSMan and ICMP, with reports and logging on issues encountered on the way.
        
        Folders containing stuff: 
            
            - clients:
                my_workstations.txt:
                    mypc1
                    mypc2
                    ...
                    mypcN
        
            - scenarios:
                get_ps_version.ps1:
                    $PSVersionTable.PSVersion
                
                reboot.ps1:
                    shutdown /r /t 0

            - domains:
                corp.fabrikam.com:
                    user@corp.fabrikam.com

                contoso.local:
                    admin@contoso.local

    .PARAMETER StuffFolder
        Filesystem path to custom location with clients, scenarios, domains and logs folders (optional)

    .EXAMPLE
        Invoke-Remote
        Starts interactive script invocation session with default clients, scenarios, domains and log sources, located in $PSScriptRoot

    .EXAMPLE
        Invoke-Remote -StuffFolder 'c:\my_sripts\IR_stuff'
        Starts interactive script invocation session with custom clients, scenarios, domains and log sources
    
    .NOTES
        14.01.2019 - public version
    #>

    param(
        [Parameter(Mandatory=$False, Position=0)]
        [string] $StuffFolder
    )

    #------------------------------------------------------------------------------------------------
    #Global initialization
    #------------------------------------------------------------------------------------------------
    if ($StuffFolder){
        Set-Location -Path $StuffFolder
    }else{
        Set-Location -Path $PSScriptRoot
    }

    $WSManAuthType = 'Kerberos'

    #------------------------------------------------------------------------------------------------
    #Global data
    #------------------------------------------------------------------------------------------------
    $ClientsFolder = 'clients'
    $ScenariosFolder = 'scenarios'
    $DomainsFolder = 'domains'
    $LogsFolder = 'logs'

    #------------------------------------------------------------------------------------------------
    #Supplementary functions
    #------------------------------------------------------------------------------------------------
    function Write-Stage{
        param(
            [Parameter(Mandatory=$True, Position=0)]
            [string] $Message
        )
        Write-Host `n $Message
        Write-Host ("-" * 75) `n
    }

    #------------------------------------------------------------------------------------------------
    function Prepare-Log{
        param(
            [Parameter(Mandatory=$True, Position=0)]
            [string] $LogItem
        )

        $NewLogsFolder = $LogsFolder + $LogItem
        Set-Variable -Name LogsFolder -Value $NewLogsFolder -Scope 2

        if(-not (Test-Path $LogsFolder)){
            New-Item -ItemType Directory -Path $LogsFolder
        }
    }

    #Get suitable credentials required for remote scenario invocation based on 'domains' folder files content
    #------------------------------------------------------------------------------------------------
    function Request-Credentials{
        
        if (-not $Credentials){
            Clear-Host
            Write-Host -BackgroundColor Blue `n "Available domains:" `n
            Enumerate-Items -Folder $DomainsFolder
            $DomainFiles = Read-Host `n`n "Please select domain"
            $Domain = (Enumerate-Items -Folder $DomainsFolder -FilePosition $DomainFiles)
            $AdminLogin = Get-Content "$DomainsFolder\$Domain"
        
            Clear-Host
            Write-Stage "1. Requesting credentials . . ."
            $Credentials = Get-Credential -Credential $AdminLogin
            Write-Host -BackgroundColor DarkGreen "Credantials recieved succsessfully" `n`n

            return $Credentials
        }
        else{
            Clear-Host
            Write-Stage "1. Requesting credentials . . ."
            Write-Host -BackgroundColor DarkGreen "Credantials recieved succsessfully" `n`n
        }
    }

    #Enumerate files with scenarios and computers
    #------------------------------------------------------------------------------------------------
    function Enumerate-Items{
        param(
            [Parameter (Mandatory=$True, Position=0)]
            [string] $Folder,
            [Parameter (Mandatory=$False, Position=1)]
            [int] $FilePosition=0
        )

        $number=0
        
        $Items = (Get-ChildItem $Folder |
            Select-Object -Property Name)
        
        foreach ($Item in $Items){
            if ($FilePosition-1 -eq $number){
                return $Item.Name
            }
            $number++
            
            if (-not $FilePosition){
                $NumberedItem = -join($number, '. ', $Item.Name)
                Write-Host $NumberedItem
            }
        }
    }

    #------------------------------------------------------------------------------------------------
    #Common functions
    #------------------------------------------------------------------------------------------------
    #Collect necessary data of remote computers and scenario to be invoked
    #------------------------------------------------------------------------------------------------
    function Collect-Data{

        Clear-Host
        Write-Host -BackgroundColor Blue `n "Available computers:" `n
        Enumerate-Items -Folder $ClientsFolder
        $ComputersListNumber = Read-Host `n`n "Please select computers"
        $ComputersFile = (Enumerate-Items -Folder $ClientsFolder -FilePosition $ComputersListNumber)
        Set-Variable -Name ComputersList -Value $ComputersFile -Scope 1
        Prepare-Log -LogItem (-join('\', $ComputersList.Replace('.txt', '')))
        [System.Collections.ArrayList]$Computers = (Get-Content "$ClientsFolder\$ComputersList")
        Set-Variable -Name Computers -Value $Computers -Scope 1

        Clear-Host
        Write-Host -BackgroundColor Blue `n "Available scenarios:" `n
        Enumerate-Items -Folder $ScenariosFolder
        $ScenarioFile = Read-Host `n`n "Please select scenario"
        $Scenario = (Enumerate-Items -Folder $ScenariosFolder -FilePosition $ScenarioFile)
        Set-Variable -Name Scenario -Value $Scenario -Scope 1
        Prepare-Log -LogItem (-join('\', $Scenario.Replace('.ps1', '')))
        $Credentials = Request-Credentials
        Set-Variable -Name Credentials -Value $Credentials -Scope 1
    }
    
    #Сonsistently checks WinRM and network connectivity with logging
    #------------------------------------------------------------------------------------------------
    function Touch-Connection{

        Write-Stage "2. Initial WinRM and network check is performed now . . ."
        
        $FailList = @()

        $AuthLogFile = "$LogsFolder\auth_issues.log"
        $WSManLogFile = "$LogsFolder\wsman_issues.log"
        $PingLogFile = "$LogsFolder\ping_issues.log"

        foreach ($Computer in $Computers){
            $part = (100 / $Computers.Count)
            $complete = [math]::Round($part * ($Computers.IndexOf($Computer)))

            $write_progress = @{
                Activity = "Checking...";
                Status = "$complete% complete:";
                PercentComplete = $complete;
            }
            Write-Progress @write_progress

            try{
                #Test-Connection -WsmanAuthentication
                $test_wsman = @{
                    ComputerName = $Computer;
                    Authentication = $WSManAuthType;
                    Credential = $Credentials;
                    ErrorAction = 'Stop';
                }
                Test-WSMan @test_wsman |
                    Out-Null
            }
            catch{
                <#[System.InvalidOperationException]#>
                Write-Host -BackgroundColor Red "Probably you provide wrong credentials on $Computer. try WSMan..." `n
                Add-Content -Value $Computer -Path $AuthLogFile

                $FailList += $Computer

                try{
                    Test-WSMan $Computer -ErrorAction Stop |
                        Out-Null
                }
                catch{
                    Write-Host -BackgroundColor DarkRed "Some issues with WinRM on $Computer. try ping..." `n
                    Add-Content -Value $Computer -Path $WSManLogFile

                    if (-not (Test-Connection -ComputerName $Computer -Quiet -Count 1)){
                        Write-Host -BackgroundColor Black "Host $Computer unavailable" `n
                        Add-Content -Value $Computer -Path $PingLogFile
                    }else{
                        Write-Host -BackgroundColor Gray "Ping $Computer success" `n
                    }
                }    
            }
        }

        $Computers = $Computers |
            Where-Object {$_ -notin $FailList}

        Set-Variable Computers -Value $Computers -Scope 1
        #Write-Progress -Activity "Checking..." -Status "100% complete:" -PercentComplete 100;

        if (-not $FailList){
            Write-Host -BackgroundColor DarkGreen "Network check complete successfully" `n`n
        }
    }

    #Invoke $Scenario ps script on $Computers and write log to $LogFile
    #------------------------------------------------------------------------------------------------
    function Invoke-Scenario{
        
        Write-Stage "3. Proceed scenario on remotes . . ."
        
        $LogFile = -join($ComputersList.Replace('.txt', '-'),
                         $Scenario.Replace('.ps1', '.log'))
        Set-Variable -Name LogFile -Value $LogFile -Scope 1
        
        if($Computers){
            try{
                $invoke_command = @{
                    ComputerName = $Computers;
                    FilePath = "$ScenariosFolder\$Scenario";
                    credential = $Credentials;
                }
                Invoke-Command @invoke_command |
                    Out-File -FilePath "$LogsFolder\$LogFile"

                Write-Host -BackgroundColor DarkGreen "Scenario invocation complete successfully" `n`n
            }
            catch [System.Management.Automation.Remoting.PSRemotingTransportException]{
                Write-Host -BackgroundColor DarkYellow 'Probably credentials was incorrect, please retry invocation' `n`n
                Set-Variable -Name Credentials -Value $null -Scope 1
            }
        }else{
            Write-Host -BackgroundColor DarkRed "There are no available computers to run scenario" `n`n
        }
    }

    #Detailing scenario invokation results
    #------------------------------------------------------------------------------------------------
    function Report-Result{

        Write-Stage "4. Scenario play complete"

        if (Test-Path "$LogsFolder\$LogFile"){
            Write-Host -BackgroundColor DarkGreen `n "Log located in: $PsScriptRoot\$LogsFolder\$LogFile :" `n`n
            $Log = Get-Content "$LogsFolder\$LogFile"

            if ($Log.Length -le 200){
                Write-Host $Log
            }
        }else{
            Write-Host -BackgroundColor DarkRed "Log not found, probably scenario play couldn't complete"
        }    
        Write-Host `n`n
    }

    #------------------------------------------------------------------------------------------------
    #Common functions
    #------------------------------------------------------------------------------------------------
    Clear-Host
    Collect-Data
    Touch-Connection
    Invoke-Scenario
    Report-Result
}