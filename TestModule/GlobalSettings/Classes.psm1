$SharedValue = 'SharedValue between classes'
Function Get-Class {
    param([switch]$NoEcho)
    If ($NoEcho) {
        $script:SharedValue
    } else {
        Write-Host "Script Shared: $script:SharedValue"
        Write-Host 'Alpha'
        Write-Host "`tMyValue: $($AlphaSettings.MyValue)"
        Write-Host "`tShared: $($AlphaSettings.SharedValue)"
        Write-Host 'Beta'
        Write-Host "`tMyValue: $($BetaSettings.MyValue)"
        Write-Host "`tShared: $($BetaSettings.SharedValue)"
    }
}
Function Set-Class {
    Param($Value)

    $script:SharedValue = $Value
}
#region Classes
class cSettings {

    [string] $MyValue

    cSettings () {
        $this | Add-Member ScriptProperty SharedValue { $script:SharedValue } { $script:SharedValue = $args[0] }
        $this.MyValue = "My default value"
        $this | Add-Member ScriptProperty MyScriptValue { $this.MyValue } { $this.MyValue = $args[0] }
    }

    [string] GetData () { return $script:SharedValue }
    [void] SetData ($Value) { $script:SharedValue = $Value }

}