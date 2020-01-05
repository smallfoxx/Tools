if (Test-Path "$PSScriptRoot\Classes.psm1") {
    #this is to get the class definitions shared between modules
    $script = [ScriptBlock]::Create("using module '$PSScriptRoot\Classes.psm1'")
    . $script
}

$AlphaTest = New-Object TestClass

Function GetAlpha {
    Write-Host "Script TestThis: $script:TestThis"
    Write-Host 'Alpha'
    $AlphaTest
    Write-Host 'Beta'
    $BetaTest
}

Function SetAlpha {
    param($Value)

    $AlphaTest.MyValue = $Value
    $AlphaTest.TestThis = $Value
}
