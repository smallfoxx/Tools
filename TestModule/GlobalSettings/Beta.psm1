if (Test-Path "$PSScriptRoot\Classes.psm1") {
    #this is to get the class definitions shared between modules
    $useBlock = [ScriptBlock]::Create("using module '$PSScriptRoot\Classes.psm1'")
    . $useBlock
}

$BetaSettings = New-Object cSettings

Function Get-Beta {
    param([switch]$NoEcho)
    If ($NoEcho) {
        $BetaSettings
    } else {
        Write-Host "Script Shared: $SharedValue"
        Write-Host 'Alpha'
        Write-Host "`tMyValue: $($AlphaSettings.MyValue)"
        Write-Host "`tShared: $($AlphaSettings.SharedValue)"
        Write-Host 'Beta'
        Write-Host "`tMyValue: $($BetaSettings.MyValue)"
        Write-Host "`tShared: $($BetaSettings.SharedValue)"
    }
}

Function Set-Beta {
    param($Value)

    #$BetaSettings.SetData($Value)
    $BetaSettings.MyValue = $Value
    $BetaSettings.SharedValue = $Value
}
