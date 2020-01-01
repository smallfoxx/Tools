<#
.SYNOPSIS
Startup a VM in Azure and call MSTSC to connect to it
.DESCRIPTION
Start a VM, find its IP address, and call MSTSC to connect to it. Optional flags will also cause the VM
and its resources to be created if it doesn't exist and change its size & disk type.
.EXAMPLE
PS> .\ConnectJumpVM.ps1 -VMName 'MyVM' -Create -PublicIP -PremiumDisk
This will look for the MyVM and create it if it doesn't already exist, looks for its public IP address,
and make sure the disks are Premium SSD types.
.LINK
Start-AzVM
New-AzVM
Minimize.ps1
#>
[Cmdletbinding()]
Param(
    [parameter(ValueFromPipelineByPropertyName=$true,Position=1)]
    [Alias('Name')]
    [ValidatePattern('\A[a-z0-9][a-z0-9\-_]{0,13}[a-z0-9]\Z')]
    #Name of the VM in Azure
    [string]$VMName="JumpVM",

    [Alias('Public','PiP')]
    #Use or create a Public IP address
    [switch]$PublicIP,

    #Create a VM if doesn't already exist
    [switch]$Create,

    [parameter(ValueFromPipelineByPropertyName=$true,Position=2)]
    #Name of resource group for resources
    [string]$ResourceGroupName="$VMName-rg",

    [parameter(ValueFromPipelineByPropertyName=$true,Position=3)]
    [Alias('PublicDNS','DNS','FQDN')]
    #full DNS name use for public IP address
    [string]$DomainNameLabel=($VMName.tolower()),

    [parameter(ValueFromPipelineByPropertyName=$true,Position=4)]
    [Alias('VNet','VNetName')]
    #Virtual network to attach to
    [string]$VirtualNetworkName="$VMName-vnet",

    [parameter(ValueFromPipelineByPropertyName=$true,Position=5)]
    [Alias('VNetRG')]
    #Resource group of virtual network
    [string]$VirtualNetowrkRG=$ResourceGroupName,

    [parameter(ValueFromPipelineByPropertyName=$true)]
    [Alias('VNetRange')]
    #Address pool of virtual network
    [string]$VirtualNetowrkAddressRange='10.0.0.0/24',

    [parameter(ValueFromPipelineByPropertyName=$true)]
    [Alias('Subnet')]
    #subnet to attach to
    [string]$SubnetName='default',

    [parameter(ValueFromPipelineByPropertyName=$true)]
    [Alias('SubnetAddress')]
    #address range of subnet; must be within $VirtualNetworkAddressRange
    [string]$SubnetAddressMask=$VirtualNetowrkAddressRange,

    [parameter(ValueFromPipelineByPropertyName=$true)]
    [Alias('NSG')]
    #Azure region to create resources in. If not specified, uses region of $ResourceGroupName
    [string]$NetworkSecurityGroup="$VMName-nsg",

    [parameter(ValueFromPipelineByPropertyName=$true)]
    #Azure region to create resources in. If not specified, uses region of $ResourceGroupName
    [string]$PublicIPName="$VMName-pip",

    [parameter(ValueFromPipelineByPropertyName=$true)]
    #Size of VM to use. Default is B2s.
    [string]$Size,

    [parameter(ValueFromPipelineByPropertyName=$true)]
    #Credential (username and password) to use for local admin on newly created VM
    [pscredential]$Credential,

    [parameter(ValueFromPipelineByPropertyName=$true)]
    [Alias('Location')]
    #Azure region to create resources in. If not specified, uses region of $ResourceGroupName
    [string]$AzureRegion,

    #Use premium disk on the VM
    [switch]$PremiumDisk

)

Begin {
    Function CreateVM {
  
        $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Ignore
        If (-not $ResourceGroup) {
            If (-not $AzureRegion) {
                throw "Azure region not specified. Must specify region when creating new resource group."
                break
            }
            Write-Host "Creating resource group [$ResourceGroupName]"
            $ResourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $AzureRegion
        }

        $VNetRG = Get-AzResourceGroup -Name $VirtualNetowrkRG -ErrorAction Ignore
        If (-not $VNetRG) {
            Write-Host "Creating resource group [$VirtualNetowrkRG]"
            $VNetRG = New-AzResourceGroup -Name $VirtualNetowrkRG -Location $AzureRegion
        }
        
        $VNet = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VNetRG.ResourceGroupName -ErrorAction Ignore
        If (-not $Vnet) {
            Write-Host "Creating virtual network [$VirtualNetworkName]..."
            $VNet = New-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VNetRG.ResourceGroupName `
                -Location $VNetRG.Location -AddressPrefix $VirtualNetowrkAddressRange 
        }

        If (-not ($Vnet.Subnets | Where-Object { $_.Name -eq $SubnetName})) {
            Write-Host "Adding subnet [$SubnetName]..."
            Add-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $Vnet -AddressPrefix $SubnetAddressMask | Out-Null
            $VNet = $VNet | Set-AzVirtualNetwork
        }

        $NSG = Get-AzNetworkSecurityGroup | Where-Object { $_.Name -eq $NetworkSecurityGroup } | Select-Object -First 1
        If (-not $NSG) {
            Write-Host "Creating NSG [$NetworkSecurityGroup]..."
            $NSGRules = @((New-AzNetworkSecurityRuleConfig -Protocol Tcp -Name 'Allow-RDP' `
                            -SourcePortRange * -SourceAddressPrefix * `
                            -DestinationPortRange 3389 -DestinationAddressPrefix 'VirtualNetwork' `
                            -Direction Inbound -Access Allow -Priority 3000))
            $NSG = New-AzNetworkSecurityGroup -Name $NetworkSecurityGroup -ResourceGroupName $ResourceGroup.ResourceGroupName `
                -Location $ResourceGroup.Location -SecurityRules $NSGRules
        }

        If (-not $Size) {
            $Size = "Standard_B2s"
        } elseif ($Size -notlike "Standard_*") {
            $Size = "Standard_$Size"
        }

        Write-Host "Creating actual VM's resources..."
        $NIC = New-AzNetworkInterface -Name ("{0}-{1:00000}" -f $VMName,(Get-Random -Minimum 100 -Maximum 10000)) `
            -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $ResourceGroup.Location `
            -SubnetId (($Vnet.Subnets | Where-Object { $_.Name -eq $SubnetName}).Id)

        $VMConfig = New-AzVMConfig -VMName $VMName -VMSize $Size 
        If ($Credential) {
            $VMConfig = Set-AzVMOperatingSystem -VM $VMConfig -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
        } else {
            $VMConfig = Set-AzVMOperatingSystem -VM $VMConfig -Windows -ComputerName $VMName -ProvisionVMAgent -EnableAutoUpdate `
                -Credential (Get-Credential -UserName $env:USERNAME -Message "Enter username and password to use for local admin of new VM")
        }
        $VMConfig = Add-AzVMNetworkInterface -VM $VMConfig -Id $NIC.Id
        $VMConfig = Set-AzVMSourceImage -VM $VMConfig -PublisherName 'MicrosoftWindowsDesktop' -Offer 'windows-10' -Skus '19h2-pro' -Version latest

        Write-Host "Creating actual VM..."
        New-AzVM -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $ResourceGroup.Location -VM $VMConfig -Verbose | Out-Null
        <#
        $VMParams = @{
            'ResourceGroupName' = $ResourceGroup.ResourceGroupName 
            'Name' = $VMName
            'Location' = $ResourceGroup.Location
            'VirtualNetworkName' = $VNet.Name
            'SubnetName' = $SubnetName
            'SecurityGroupName' = $NSG.Name
            'Size' = $Size
            'PublicIPAddress' = '""'
        }
        If ($Credential) { $VMParams.Credential = $Credential}

        Write-Host "Creating actual VM..."
        $NewVM = New-AzVm @VMParams
        #> 
        Get-AzVm -ResourceGroupName $ResourceGroup.ResourceGroupName -Name $VMName
    }

    Function StartVM {
        Param($VM)

        $ResourceGroup = Get-AzResourceGroup -Name $Vm.ResourceGroupName
        $NIC = Get-AzResource -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].id | Get-AzNetworkInterface
        $IpConfig = $NIC.IpConfigurations[0]

        If ($PublicIP) {
            Write-Host "Verifying Public IP details..."
            if (-not ($NIC.NetworkSecurityGroup)) {
                Write-host "Adding NSG..."
                $NSG = Get-AzNetworkSecurityGroup | Where-Object { $_.Name -eq $NetworkSecurityGroup } | Select-Object -First 1
                If (-not $NSG) {
                    $NSGRules = @((New-AzNetworkSecurityRuleConfig -Protocol Tcp -Name 'Allow-RDP' `
                                    -DestinationPortRange 3389 -DestinationAddressPrefix 'VirtualNetwork' `
                                    -Direction Inbound -Access Allow -Priority 3000))
                    $NSG = New-AzNetworkSecurityGroup -Name $NetworkSecurityGroup -ResourceGroupName $ResourceGroup.ResourceGroupName `
                        -Location $ResourceGroup.Location -SecurityRules $NSGRules
                }
                $NIC.NetworkSecurityGroup = $NSG
            }

            if (-not ($IpConfig.PublicIpAddress)) {
                Write-Host "Adding public IP"
                $PubIP = Get-AzPublicIpAddress | Where-Object { $_.Name -eq $PublicIPName } | Select-Object -First 1
                If (-not $PubIP) {
                    $PubIP = New-AzPublicIpAddress -Name $PublicIPName -ResourceGroupName $ResourceGroup.ResourceGroupName `
                        -Location $ResourceGroup.Location -AllocationMethod Dynamic -DomainNameLabel $DomainNameLabel
                }
                
                $NIC | Set-AzNetworkInterfaceIpConfig -Name $IpConfig.Name -PublicIpAddress $PubIP -Subnet $IpConfig.Subnet
            }

            Write-Host "Updating NIC..."
            $NIC = $NIC | Set-AzNetworkInterface
        }

        If ($PremiumDisk -and (TestVMDeallocated -VM $VM)) {
            Write-Host "Ensuring premium disks..."
            $Disks = @($VM.StorageProfile.OsDisk)
            $Disks += $VM.StorageProfile.DataDisks
            $DiskUpdate = New-AzDiskUpdateConfig -SkuName Premium_LRS
            ForEach ($Disk in $Disks) {
                If ($Disk.ManagedDisk) {
                    $ManagedDisk = Get-AzResource -ResourceId $Disk.ManagedDisk.id | Get-AzDisk 
                    If ($ManagedDisk.Sku.Name -notlike "Premium*") {
                        Write-host "Updating [$($ManagedDisk.name)]"
                        $ManagedDisk = $ManagedDisk | Update-AzDisk -DiskUpdate $DiskUpdate
                    }
                }
            }
        }

        If (TestVMDeallocated -VM $VM) {
            If ($Size -and ($VM.HardwareProfile.VmSize -notlike "*$Size")) {
                Write-Host "Resizing to [$Size]..."
                If ($Size -notlike 'Standard_*') { $Size = "Standard_$Size" }
                $VM.HardwareProfile.VmSize = $Size
                Update-AzVm -VM $VM -ResourceGroupName $VM.ResourceGroupName | Out-Null
            }
            Write-Host "Starting VM [$($VM.Name)]..."
            $VM | Start-AzVm
        }
    }

    Function GetVMAddress {
        param($VM)
        $NIC = Get-AzResource -ResourceId $VM.NetworkProfile.NetworkInterfaces[0].Id | Get-AzNetworkInterface
        $IpConfig = $NIC.IpConfigurations[0]
        If ($PublicIP -and ($IpConfig.PublicIpAddress)) {
            $PIP = Get-AzResource -ResourceId $IpConfig.PublicIpAddress.id | Get-AzPublicIpAddress
            If ($PIP.DnsSettings.Fqdn) {
                $PIP.DnsSettings.Fqdn
            } else {
                $PIP.IpAddress.ToString()
            }
        } else {
            $IpConfig.PrivateIpAddress.ToString()
        }
    }

    Function TestVMDeallocated {
        param($VM)

        $VMStatus = Get-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Status
        If ($VMStatus.PowerState) {
            $VMStatus.PowerState -like '*deallocated'
        } elseif ($VMStatus.Statuses | Where-Object {$_.DisplayStatus -like '*deallocated'}) {
            $true
        } else {
            $false
        }
    }

    If (-not (Get-AzContext)) {
        Connect-AzAccount
    }
}

Process {
    If ($VMName) {
        If ($ResourceGroupName) {
            $VM = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction Ignore
        } else {
            $VM = Get-AzVM  | Where-Object { $_.Name -eq $VMName } | Select-Object -First 1
        }
        If ($Create -and -not $VM) {
            Write-Host "Creating VM [$VMName]..."
            $VM = CreateVM
        }
        If ($VM) {
            Write-Host "checking status of VM [$($VM.Name)]..."
            StartVM -VM $VM
            $Address = GetVMAddress -VM $VM
            Write-Host "Found address as [$Address]"
            mstsc /v:$Address
        } else {
            Write-Error "Could not find VM [$VMName]"
        }
    }
}

End {

}