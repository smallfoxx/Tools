$script:TestThis = 'I am testing this'
Function GetClass {
    $script:TestThis
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