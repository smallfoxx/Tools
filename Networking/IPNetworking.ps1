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
                ([convert]::ToString($this.Mask.Address,2) -replace "0","").length
            } 
        } -SecondValue { if ($args[0]) { $this.Mask = [ipaddress][convert]::ToInt64((Convert-CIDRToBitmask -CIDRMask $args[0]),2) } }
        $this | Add-Member ScriptProperty CIDR { if ($this.Mask) { "{0}/{1}" -f $this.Address.IPAddressToString,$this.CIDRMask } } { $this.Address = $args[0] }
        $this | Add-Member ScriptProperty NetworkAddress { if ($this.Mask) { [ipaddress]($this.IPv4Address.Address -band $this.Mask.Address) } }
        $this | Add-Member ScriptProperty BroadcastAddress { if ($this.Mask) {  [ipaddress]($this.NetworkAddress.address + [convert]::ToInt64((Convert-CIDRToBitmask -CIDRMask $this.CIDRMask -Invert).PadLeft(32,"1"),2)) } } 
        $this | Add-Member ScriptProperty NetworkAddressCount { if ($this.Mask) { [convert]::ToInt64("1"*(32-$this.CIDRMask),2)+1 } }
        $this | Add-Member ScriptProperty NetworkUsableCount { if ($this.Mask) { $this.NetworkAddressCount-2 } }
        $this | Add-Member ScriptProperty AzureUsableCount { if ($this.Mask) { $this.NetworkUsableCount-3 } }
    }
}

Function Convert-CIDRToBitmask {
    param([int]$CIDRMask,
        [switch]$Invert)
    If ($Invert) {
        $on = "0"
        $off = "1"
    } else {
        $on = "1"
        $off = "0"
    }
    If ($CIDRMask -gt 8) {
        return (Convert-CIDRToBitmask -CIDRMask ($CIDRMask-8) -Invert:$Invert)+$on*8
    } elseif ($CIDRMask -ge 0) {
        return ($on*$CIDRMask+$off*(8-$CIDRMask))
    }
}

Function Test-OnNetwork {
    <#
    .SYNOPSIS
    Compare two IP addresses to determine if they're on the same network
    .DESCRIPTION
    Takes two IP addresses with at least one having a subnet mask and returns true if they are on the same
    subnet; false if the are not. If the actual address is needed rather than a boolean response, use the
    -PassThru parameter to return the IP adddress
    .INPUTS
    FullIP
    .OUTPUTS
    Boolean
    FullIP
    .EXAMPLE
    Test-OnNetwork -Address "192.168.32.14/25" -RemoteAddress "192.168.32.5"
    Would return $true as 192.168.32.5 is on the same subnet as 192.168.32.14 with the mask 255.255.255.128
    .EXAMPLE
    Get-Content .\IPAddresses.txt | Test-OnNetwork -Address (Get-NetIPAddress | Where-Object { $_.Address } | Select-Object -first 1 -Skip 1) -PassThru
    Will take the content of the IPAddresses.txt file and compare them against the second network address of
    the local machine and return the IP address object of those address that are on the network.
    .LINK
    https://github.com/smallfoxx/
    #>
    param(
        # Local IP address to use for source of test. Should be in CIDR format or IPAddress type with a Subnet mask
        [parameter(ValueFromPipelineByPropertyName=$true,Position=0)]
        [FullIP]$Address,
        # Remote IP address to test against
        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=1)]
        [FullIP[]]$RemoteAddress,
        # Return the IP address if on network rather than just a binary true/false
        [Switch]$PassThru
    )

    Process {
        ForEach ($Remote in $RemoteAddress) {
            If ($Address.Mask) {
                $OnNetwork = $Address.IsOnNetwork($Remote)
            } elseif ($Remote.Mask) {
                $OnNetwork = $Remote.IsOnNetwork($Address)
            } else {
                $OnNetwork = $false
            }
            If ($OnNetwork) {
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