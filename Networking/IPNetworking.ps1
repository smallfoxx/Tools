Class FullIP {

    hidden [IPAddress]$IPv4Address
    [IPAddress]$Mask

    FullIP() {
        $this.Initialize()
    }

    FullIP([string]$IPaddress) {
        $this.Initialize()
        $this.Address = $IPaddress
    }

    FullIP([ciminstance]$NetAddress) {
        $this.Initialize()
        $this.Address = "{0}/{1}" -f $NetAddress.IPAddress,$NetAddress.PrefixLength
    }

    FullIP([ipaddress]$IPaddress,[ipaddress]$SubnetMask) {
        $this.Initialize()
        $this.Address = $IPaddress
        $this.Mask = $SubnetMask
    }

    FullIP([ipaddress]$IPaddress,[int]$CIDRMask) {
        $this.Initialize()
        $this.Address = $IPaddress
        $this.CIDRMask = $CIDRMask
    }

    [bool]IsOnNetwork($PeerAddress) {
        $PeerIP = New-Object FullIP($PeerAddress)
        If ($this.Mask) {
            return (($PeerIP.Address.Address -band $this.Mask.Address) -eq $this.NetworkAddress.Address)
        } else {
            return $null
        }
    }

    [string]ToString() {
        return $this.IPv4Address.ToString()
    }

    hidden [void]Initialize() {
        $this | Add-Member ScriptProperty Address -Value { $this.IPv4Address } -SecondValue {
            if ($args[0] -is [ipaddress]) {
                $this.IPv4Address = $args[0]
            } elseif ($args[0] -match "\A(?<ip>(\d{1,3}\.){3}\d{1,3})(\/(?<cidr>\d{1,2}))?\Z") {
                $this.IPv4Address = [ipaddress]($Matches.IP); $this.CIDRMask = [int]($Matches.cidr) 
            }
        }
        $this | Add-Member ScriptProperty CIDRMask -Value {
            if ($this.Mask) {
                [int]([math]::Log($this.Mask.Address+1)/[math]::log(2))
            } 
        } -SecondValue { if ($args[0]) { $this.Mask = [ipaddress][convert]::ToInt64(("1"*[int]$args[0]),2) } }
        $this | Add-Member ScriptProperty CIDR { if ($this.Mask) { "{0}/{1}" -f $this.Address.IPAddressToString,$this.CIDRMask } } { $this.Address = $args[0] }
        $this | Add-Member ScriptProperty NetworkAddress { if ($this.Mask) { [ipaddress]($this.IPv4Address.Address -band $this.Mask.Address) } }
        $this | Add-Member ScriptProperty BroadcastAddress { if ($this.Mask) {  [ipaddress]($this.NetworkAddress.address + [convert]::ToInt64(("1"*(32-$this.CIDRMask)+"0"*$this.CIDRMask),2)) } } #); [ipaddress]($this.NetworkAddress.Address + [convert]::ToInt64("1"*(32-$this.CIDRMask)+"0"*$this.CIDRMask)) } }
        $this | Add-Member ScriptProperty NetworkAddressCount { if ($this.Mask) { [convert]::ToInt64("1"*(32-$this.CIDRMask),2)+1 } }
        $this | Add-Member ScriptProperty NetworkUsableCount { if ($this.Mask) { $this.NetworkAddressCount-2 } }
        $this | Add-Member ScriptProperty AzureUsableCount { if ($this.Mask) { $this.NetworkUsableCount-3 } }
    }
}

Function Test-OnNetwork {
    param(
        [parameter(ValueFromPipelineByPropertyName=$true,Position=0)]
        [FullIP]$Address,
        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=1)]
        [FullIP[]]$RemoteAddress,
        [Switch]$PassThru
    )

    Process {
        ForEach ($Remote in $RemoteAddress) {
            If ($Address.IsOnNetwork($Remote)) {
                If ($PassThru) {
                    $Remote
                } else {
                    $true
                }
            } elseif (-not $PassThru) {
                $false
            } else {

            }
        }
    }
}