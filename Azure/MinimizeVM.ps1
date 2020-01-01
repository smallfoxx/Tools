<#
.SYNOPSIS
Shuts down a VM in Azure and minize resources at rest.
.DESCRIPTION
Deallocates an Azure VM, remove an public IP addresses, and drop its disks down to Standard HDD disks to
minimize its costs while at rest.
.EXAMPLE
PS> .\MinimizeVM.ps1 -VMName 'MyVM'
This will look for the MyVM and stop it if its running, looks for any public IP addresses & removes them,
and make sure the disks are Standard HDD types.
.LINK
Stop-AzVM
New-AzVM
ConnectJumpVM.ps1
#>
[Cmdletbinding()]
param(
    [parameter(ValueFromPipelineByPropertyName=$true,Position=1)]
    [Alias('Name')]
    #Name of the VM in Azure
    [string]$VMName="JumpVM",

    [Alias('KeepPiP')]
    #Use or create a Public IP address
    [switch]$KeepPublicIP,

    #Create a VM if doesn't already exist
    [switch]$KeepDiskLevel,

    [parameter(ValueFromPipelineByPropertyName=$true,Position=2)]
    #Name of resource group for resources
    [string]$ResourceGroupName

)

Begin {
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

}

Process {
    If ($VMName) {
        If ($ResourceGroupName) {
            $VM = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName
        } else {
            $VM = Get-AzVM | Where-Object { $_.Name -eq $VMName } | Select-Object -First 1  
        }

        If ($VM) {
            If (-not (TestVMDeallocated -VM $VM)) {
                Write-Host "Shutting down VM [$($VM.Name)]..."
                $VM | Stop-AzVM -Force  
            }

            if (-not $KeepPublicIP) {
                $NIC = Get-AzResource -ResourceId $VM.NetworkProfile.NetworkInterfaces[0].Id | Get-AzNetworkInterface
                $PiPs = @()
                ForEach ($IpConfig in $NIC.IpConfigurations) {
                    If ($IpConfig.PublicIPAddress) {
                        $PiPs += Get-AzResource -ResourceId $IpConfig.PublicIPAddress.id | Get-AzPublicIpAddress
                        $IpConfig.PublicIPAddress = $null
                    }
                }
                If ($PiPs) {
                    Write-Host "Remove [$($PiPs.count)] public ip"
                    $NIC | Set-AzNetworkInterface
                    $PiPs | Remove-AzPublicIpAddress -Force
                }
            }

            If (-not $KeepDiskLevel) {
                Write-Host "Dropping disks' sku's..."
                $Disks = @($VM.StorageProfile.OsDisk)
                $Disks += $VM.StorageProfile.DataDisks
                $DiskUpdate = New-AzDiskUpdateConfig -SkuName Standard_LRS
                ForEach ($Disk in $Disks) {
                    If ($Disk.ManagedDisk) {
                        $ManagedDisk = Get-AzResource -ResourceId $Disk.ManagedDisk.id | Get-AzDisk 
                        If ($ManagedDisk.Sku.Name -notlike "Standard_*") {
                            Write-host "Updating [$($ManagedDisk.name)]"
                            $ManagedDisk = $ManagedDisk | Update-AzDisk -DiskUpdate $DiskUpdate
                        }
                    }
                }
            }
        }
    }
    
}

End {

}