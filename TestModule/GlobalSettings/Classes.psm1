$TestThis = 'I am testing this'
Function GetClass {
    Write-Host "Script TestThis: $script:TestThis"
    Write-Host 'Alpha'
    Write-Host "`tMyValue: $($AlphaTest.MyValue)"
    Write-Host "`tTestThis: $($AlphaTest.TestThis)"
    Write-Host 'Beta'
    Write-Host "`tMyValue: $($BetaTest.MyValue)"
    Write-Host "`tTestThis: $($BetaTest.TestThis)"
}
Function SetClass {
    Param($Value)

    $script:TestThis = $Value
}
#region Classes
class TestClass {

    [string] $MyValue

    TestClass () {
        $this | Add-Member ScriptProperty TestThis { $script:TestThis } { $script:TestThis = $args[0] }
        $this.MyValue = $script:TestThis
    }

}