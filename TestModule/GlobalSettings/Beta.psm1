if (Test-Path "$PSScriptRoot\Classes.psm1") {
    #this is to get the class definitions shared between modules
    $script = [ScriptBlock]::Create("using module '$PSScriptRoot\Classes.psm1'")
    . $script
}

$BetaTest = New-Object TestClass

Function GetBeta {
    Write-Host "Script TestThis: $script:TestThis"
    Write-Host 'Alpha'
    Write-Host "`tMyValue: $($AlphaTest.MyValue)"
    Write-Host "`tTestThis: $($AlphaTest.TestThis)"
    Write-Host 'Beta'
    Write-Host "`tMyValue: $($BetaTest.MyValue)"
    Write-Host "`tTestThis: $($BetaTest.TestThis)"
}

Function SetBeta {
    param($Value)

    $BetaTest.MyValue = $Value
    $BetaTest.TestThis = $Value
}
