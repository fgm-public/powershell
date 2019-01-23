function Get-ADUsers{
    
    <#
    .SYNOPSIS
        Request UPNs from certain OU and stores them in custom location

    .DESCRIPTION
        Request UPNs from certain OU with domain suffix trimming.
        Then stores them in custom location with file 'accounts_count-leaf_OU-date.txt' name.
        
    .EXAMPLE
        Get-ADUsers
    
    .NOTES
        19.01.2019 - public version
    #>

    $Date = Get-Date -Format 'dd-MM-yyyy'

    $ADusersPath = "C:\AD\accounts"

    $DomainSuffix = '@[ -~]*'

    $ADUsersSearchBase = 'OU=Accounting,OU=Departments,OU=Staff,OU=Company,DC=fabrikam,DC=com'

    $SimpleOUName = ($ADUsersSearchBase.Split(',') | Select-Object -First 1).split('=')[1]

    $UPNs = Get-ADUser -filter * -SearchBase $ADUsersSearchBase | Select-Object UserPrincipalName

    $FolderNames = $UPNs | ForEach-Object {$_.UserPrincipalName -replace $DomainSuffix}

    $FoldersAmount = ($FolderNames | Measure-Object).Count
    
    $FolderNames = $FolderNames | Sort-Object

    Add-Content -Path "$ADusersPath\$FoldersAmount-$SimpleOUName-$Date.txt" -Value $FolderNames
}
