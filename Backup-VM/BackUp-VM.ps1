function BackUp-VM{
    
    <#
    .SYNOPSIS
        Backup VM with some extra preparations

    .DESCRIPTION
        Backup VM, in particular:
            
            - Offers VHDs deattaching
            - Delete excess backups
            - Stop VM
            - Backup VM
            - Offers VHDs deattaching

        
        Some configuration stuff located in below folders : 
            
            - \settings\:
                VM_intended_to_back_name.txt:
                    
                    Extra_disk_in_need_of_deattach_before_backup_1.vhdx
                    Extra_disk_in_need_of_deattach_before_backup_2.vhdx
                    ...
                    Extra_disk_in_need_of_deattach_before_backup_N.vhdx
        
    .EXAMPLE
        BackUp-VM

        Starts interactive backup session with some questions

    .NOTES
        17.01.2019 - public version
    #>

    #------------------------------------------------------------------------------------------------
    #Global initialization
    #------------------------------------------------------------------------------------------------

    Set-Location $PSScriptRoot

    #------------------------------------------------------------------------------------------------
    #Global data
    #------------------------------------------------------------------------------------------------

    $BackUpDestination = "B:\BackUp\Hyper-V\$env:Computername"

    $BackUpList = ".\settings"

    $VMsSysDisksStorage = 'C:'

    $RetainBackupsCount = 4

    #------------------------------------------------------------------------------------------------
    #Supplementary functions
    #------------------------------------------------------------------------------------------------
    
    #Enumerate VMs or return VM name by position in enumerated VMs list
    #------------------------------------------------------------------------------------------------
    function Enumerate-Items{

        param(
            [Parameter (Mandatory=$False, Position=0)] [int] $FilePosition=0
        )

        $number=0
        
        $items = (Get-ChildItem $BackUpList | Select-Object -Property Name)
        
        foreach ($item in $items){

            $item.Name = $item.Name.TrimEnd('.txt')

            if ($FilePosition-1 -eq $number){
            
                return $item.Name 
            }
            
            $number++
            
            if (-not $FilePosition){
            
                $NumberedItem = -join($number, '. ', $item.Name)
                
                Write-Host $NumberedItem
            }
        }
    }

    #Retain VM backups amount refered to $RetainBackupsCount
    #------------------------------------------------------------------------------------------------
    function Retain-BackupsQuantity{

        foreach ($VM in $VMName){
            
            if (Test-Path -Path "$BackUpDestination\$VM"){

                $Backups = Get-ChildItem "$BackUpDestination\$VM"

                $BackupsToDelete = $Backups.count - $RetainBackupsCount

                if ($BackupsToDelete -gt 0){

                    #Sort by real datestamp folder attributes, not by folder name
                    $BackupsList = $Backups | Sort-Object CreationTime | Select-Object -Last $BackupsToDelete

                    $BackupsList | Remove-Item -Recurse -Force
                }
            }
        }
    }

    #Softly stops VM with prompt
    #------------------------------------------------------------------------------------------------
    function Lull-VM{

        while ($deal -ne 'q'){

            Clear-Host
        
            Write-Host `n "Virtual machine $VM is running, it is recommended to turn off the virtual machine." -BackgroundColor Red `n
            
            $answer = Read-Host "Turn it off (Y-yes, N-no, Q-quit)?"

            if ($answer -eq 'y'){

                Stop-VM -Name $VM -AsJob

                Get-Job | Where-Object -Property Command -Like "*$VM*" | Wait-Job

                if ((Get-VM | Where-Object -Property Name -eq $VM).State -eq "off"){
                
                    Write-Host `n`n "Virtual machine $VM stopped" -BackgroundColor Darkblue
                }
                
                $deal = 'q'
            }
        }
    }

    #BackUp VMs from $VMsToBackup list to $BackUpDestination
    #------------------------------------------------------------------------------------------------
    function Start-BackUp{

        if (-not (Test-Path -Path "$BackUpDestination\$VM\$date")){
            
            New-Item -Path "$BackUpDestination\$VM\$date" -Type Directory
        }

        Export-VM -Name $VM -Path "$BackUpDestination\$VM\$date"
    }

    #------------------------------------------------------------------------------------------------
    #Common functions
    #------------------------------------------------------------------------------------------------

    #Attach or deattach .vhdx disks to/from $VMName
    #------------------------------------------------------------------------------------------------
    function Attach-Disk{

        param([Parameter (Mandatory=$False, Position=0)] [switch] $Deattach)

        if ($Deattach){

            $VMStorages = Get-VMHardDiskDrive -VMName $VMName | Where-Object -Property Path -NotLike "*$VMsSysDisksStorage\*"
            
            $VMStorages | Remove-VMHardDiskDrive
        }

        else{

            $VHDXDisks = Get-Content "$BackUpList\$VMName.txt"

            foreach ($VHDXDisk in $VHDXDisks){
        
                Add-VMHardDiskDrive -VMName $VMName -Path $VHDXDisk
            }
        }
    }

    #Prepare VM to backup and makes it
    #------------------------------------------------------------------------------------------------
    function Handle-BackUp{

        Retain-BackupsQuantity

        $date = (Get-Date).ToString('dd.MM.yyyy')

        if ($VMName){

            if (Test-Path -Path $BackUpDestination){

                foreach ($VM in $VMName){

                    if ((Get-VM | Where-Object -Property Name -eq $VM).State -eq "Running"){

                        Lull-VM
                    }

                    Start-BackUp
                }
            }
        }
    }

    #------------------------------------------------------------------------------------------------
    #Main function
    #------------------------------------------------------------------------------------------------

    while ($answer -ne 'q'){

        Clear-Host

        Write-Host `n "VMs which are available for backup operation:" -BackgroundColor Darkblue `n

        Enumerate-Items

        $VMNumber = Read-Host `n "Select VM"

        $VMName = Enumerate-Items -FilePosition $VMNumber

        Clear-Host
        
        Write-Host `n "Disks connected to the '$VMName' VM at the moment:" -BackgroundColor Darkblue `n`n

        (Get-VMHardDiskDrive -VMName $VMName).Path


        Write-Host `n`n "VM '$VMName' backup list:" -BackgroundColor Darkblue `n

        try{
            
            (Get-ChildItem -Path "$BackUpDestination\$VMName").Name
        }
        
        catch{
            
            [System.Management.Automation.ItemNotFoundException]
            Write-Host "VM does not have backup"
        }

        Write-Host `n`n "Available actions:" -BackgroundColor Darkblue `n`n

        Write-Host "1. Attach disks to VM '$VMName'" `n
        Write-Host "2. Deattach disks from VM '$VMName'" `n
        Write-Host "3. Backup VM '$VMName'" `n
        Write-Host -BackgroundColor DarkGray "q. Exit" `n`n

        $answer = Read-Host "Please select action"

        switch ($answer){

            1 {Attach-Disk}
            2 {Attach-Disk -Deattach}
            3 {Handle-BackUp}
        }

        Clear-Host
    }
}