$ValidSets = @{
    'dynaFirst' = @("DynaA","DynaB")
    'dynaSecond' = @("DynaAgain","DynaBasic")
} #Can be changed to update validation of dynamic parameters, keys just need to match parameter names

Function Example {
    param(
        [parameter(Position=1)]
        [ValidateSet("Op1","Op2")]
        [string]$Static
    )
    DynamicParam {
        #List of dynamic parameters in ordered hashtable
        $DynaParams = [ordered]@{
            "dynaFirst" = @{
                'Mandatory' = $false
                'HelpMessage' = 'Dynamic help message'
                'Validation' = $ValidSets
                'ParamType' = [string]
            }
            "dynaSecond" = @{
                'Mandatory' = $false
                'HelpMessage' = 'Another dynamic message'
                'Validation' = $ValidSets
                'ParamType' = [string]
            }
        }

        $Pos = 2
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        ForEach ($ParamName in $DynaParams.Keys) {
            $dynaAttribute = New-Object System.Management.Automation.ParameterAttribute
            $dynaAttribute.Position = $Pos++
            $dynaAttribute.Mandatory = $DynaParams.$ParamName.Mandatory
            $dynaAttribute.HelpMessage = $DynaParams.$ParamName.HelpMessage
 
            #create an attributecollection object for the attribute we just created.
            $dynaCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
 
            #add our custom attribute
            $dynaCollection.Add($dynaAttribute)

            if ($DynaParams.$ParamName.ContainsKey('Validation')) {
                $dynaValidateSet = New-Object System.Management.Automation.ValidateSetAttribute($DynaParams.$ParamName.Validation.$ParamName)
                $dynaCollection.add($dynaValidateSet)
            }
 
            #add our paramater specifying the attribute collection
            $dynaParam = New-Object System.Management.Automation.RuntimeDefinedParameter($ParamName, $DynaParams.$ParamName.ParamType, $dynaCollection)
 
            #expose the name of our parameter
            $paramDictionary.Add($ParamName, $dynaParam)
        }
 
        Return $paramDictionary
 
    }

Process {
    ForEach ($ParaName in $PSBoundParameters.Keys) {
        if (-not (Get-Variable -Name $ParaName -ErrorAction Ignore)) {
            Write-Debug -Message "Creating variable for dynamic parameter [$ParaName]"
            New-Variable -Name $ParaName -Value $PSBoundParameters.$ParaName 
        }
    } 
    Write-Host "[$Static] - [$DynaFirst] - [$DynaSecond]"

}

}
