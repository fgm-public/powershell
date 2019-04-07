
function Sign-Script{
<#
    .SYNOPSIS
        Sign powershell scripts.

    .DESCRIPTION
        Sign single or multiple powershell sripts with code signing certificate.

    .PARAMETER ScriptPath
        Point to folder with scripts to be signed

    .PARAMETER Cert
        Code signing certificate

    .EXAMPLE
        Sign-Script -ScriptPath 'C:\my_scripts' -Cert $MyCert
        
        Sign all scripts located in C:\my_scripts folder with code signing certificate stored in $MyCert
    
    .NOTES
        02.04.2019 - public version
    #>

    param(
        [Parameter (Mandatory=$false, Position=0)] [string] $ScriptPath,
        [Parameter (Mandatory=$false, Position=1)] $Cert
    )
    
    $TimeServer = 'http://timestamp.comodoca.com/authenticode'

    if (-not $Cert){
        $Cert = @(Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert)[0]
    }

    if (-not $ScriptPath){
        $ScriptPath = Read-Host `n "Please enter path to script"
    }

    $Scripts = Get-ChildItem $ScriptPath -Recurse |
                    Where-Object {-not $_.psiscontainer} |
                        ForEach-Object {$_.fullname}

    foreach ($Script in $Scripts){
        $set_authenticodeSignature = @{
            Certificate = $Cert;
            FilePath = $Script;
            TimestampServer = $TimeServer;
        }
        Set-AuthenticodeSignature @set_authenticodeSignature
    }
}