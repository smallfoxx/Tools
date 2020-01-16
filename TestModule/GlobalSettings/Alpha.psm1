if (Test-Path "$PSScriptRoot\Classes.psm1") {
    #this is to get the class definitions shared between modules
    $useBlock = [ScriptBlock]::Create("using module '$PSScriptRoot\Classes.psm1'")
    . $useBlock
}

$AlphaSettings = New-Object cSettings

Function Get-Alpha {
    param([switch]$NoEcho)
    If ($NoEcho) {
        $AlphaSettings
    } else {
        Write-Host "Script Shared: $SharedValue"
        Write-Host "Script Scope: $script:SharedValue"
        Write-Host 'Alpha'
        Write-Host "`tMyValue: $($AlphaSettings.MyValue)"
        Write-Host "`tShared: $($AlphaSettings.SharedValue)"
        Write-Host 'Beta'
        Write-Host "`tMyValue: $($BetaSettings.MyValue)"
        Write-Host "`tShared: $($BetaSettings.SharedValue)"
        Write-Host ''
        ForEach ($var in (Get-Variable)) {
            Write-Host "`t[$($var.Name)]: $($var.Value)"
        }
    }
}

Function Set-Alpha {
    param($Value)

    $AlphaSettings.SharedValue = $Value
    $AlphaSettings.MyValue = $Value
    #$AlphaSettings.SharedValue = $Value
}

