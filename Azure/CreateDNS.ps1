param([parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
    # The DNS Zone name to create (ie: domain.tld)
    [string]$Zone,
    [parameter(Position=1,ValueFromPipelineByPropertyName=$true)]
    [string]$ResourceGroupName="DNSZones",
    [string]$DefaultLocation="southcentralus",
    [switch]$SkipRegistrar,
    [switch]$NoOffice365,
    [switch]$PassThru
)

Begin {
    Function CreateDNSZone {
        param([parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$Zone=$Script:Zone,
        [parameter(Position=1,ValueFromPipelineByPropertyName=$true)]
        [string]$ResourceGroupName=$Script:ResourceGroupName)
        Process {
            Write-Host "Creating Azure DNS Zone resources for $Zone..."
            $RG = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
            If (-not $RG) { $RG = New-AzResourceGroup -Name $ResourceGroupName -Location $DefaultLocation }
            $DNSZone = Get-AzDnsZone -Name $Zone -ResourceGroupName $RG.ResourceGroupName -ErrorAction SilentlyContinue
            If (-not $DNSZone) {
                Write-Host "`tCreating Azure DNS zone for [$($DNSZone.name)]..."

                $DNSZone = New-AzDnsZone -Name $Zone -ResourceGroupName $RG.ResourceGroupName -ZoneType Public
            }
            $DNSZone
        }
    }

    Function AddO365Records {
        param([parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [Microsoft.Azure.Commands.Dns.DnsZone]$DNSZone=$Script:AzZone,
            [switch]$Overwrite)

        Process {
            Write-Host "`tAdding [$($DNSZone.name)] entries for Office 365..."
            
            $Records = @{
                "MX" = @{ "@" ="[10,{0}.mail.protection.outlook.com]" }
                "SRV" = @{"_sipfederationtls._tcp"="[100,1,5061,sipfed.online.lync.com]"
                    "_sip._tls"="[100,1,443,sipdir.online.lync.com]"}
                "CNAME" = @{
                    "autodiscover"="autodiscover.outlook.com"
                    "enterpriseenrollment"="enterpriseenrollment.manage.microsoft.com"
                    "enterpriseregistration"="enterpriseregistration.windows.net"
                    "lyncdiscover"="webdir.online.lync.com"
                    "msoid"="clientconfig.microsoftonline-p.net"
                    "sip"="sipdir.online.lync.com"
                }
                "TXT" = @{
                    '@' = "v=spf1 include:spf.protection.outlook.com -all"
                }
            }
            
            ForEach ($RecordType in $Records.Keys) {
                ForEach ($Record in $Records.$RecordType.Keys) {
                    $ExistingRecord = Get-AzDnsRecordSet -ZoneName $DNSZone.Name -ResourceGroupName $DNSZone.ResourceGroupName `
                        -Name $Record -RecordType $RecordType -ErrorAction SilentlyContinue
                    If ($Overwrite -or (-not $ExistingRecord)) {
                        $Entry = $Records.$RecordType.$Record
                        $RecordsList = $null
                        switch ($RecordType) {
                            "MX" {
                                If ($Entry -match "\A\[?(?<Pref>\d+),(?<domain>[^\]]+)\]?\Z") {
                                    $RecordsList = New-AzDnsRecordConfig -Preference $Matches.Pref -Exchange ($Matches.domain -f ($DNSZone.Name -replace "\.","-"))
                                }
                            }
                            "SRV" {
                                If ($Entry -match "\A\[?(?<Pri>\d+),(?<wei>\d+),(?<port>\d+),(?<target>[^\]]+)\]?\Z") {
                                    $RecordsList = New-AzDnsRecordConfig -Priority $Matches.Pri -Weight $Matches.wei -Port $Matches.Port -Target $Matches.target
                                }
                            }
                            "CNAME" {
                                If ($Entry -match "\A\[?(?<target>[\S\.]+)\]?\Z") {
                                    $RecordsList = New-AzDnsRecordConfig -Cname $Matches.target
                                }
                            }
                            "TXT" {
                                $RecordsList = New-AzDnsRecordConfig -Value $Entry
                            }
                            default {
                                If ($Entry -match "\A\[?(?<IP>([\d]+\.){3}\d+)\]?\Z") {
                                    $RecordsList = New-AzDnsRecordConfig -Ipv4Address $Matches.IP
                                } elseif ($Entry -match "\A\[?(?<IP>([\da-f]*\:)+[\da-f]+)\]?\Z") {
                                    $RecordsList = New-AzDnsRecordConfig -Ipv6Address $Matches.IP
                                }
                            }
                        }
                        If ($RecordsList) {
                            New-AzDnsRecordSet -ZoneName $DNSZone.Name -ResourceGroupName $DNSZone.ResourceGroupName -Name $Record `
                                -RecordType $RecordType -DnsRecords $RecordsList -Ttl 3600 -Overwrite:$Overwrite
                        }
                    }
                }
            }
        }
    }

    Function AddToExchange {
        <#
        .DESCRIPTION
        Add zone to accepted Exchange domains 
        Requires Azure AD:
          PS> Connect-AzureAD -Credential $UserCredential
        Requires connection to Exchange Online:
          PS> $Session = New-PSSession -ConfigurationName Microsoft.Exchange -Credential $UserCredential `
                -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Authentication Basic -AllowRedirection
          PS> Import-PSSession $Session -DisableNameChecking
        #>
        param([parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [Microsoft.Azure.Commands.Dns.DnsZone]$DNSZone=$Script:AzZone,
            [string]$ExceptionGroup='zAllOffic365Addresses@shinari.onmicrosoft.com',
            [string]$RedirectTo='smallfoxx@live.com')

        Process {
            Write-Host "`tAdding [$($DNSZone.name)] to Exchange..."
            $ADDomain = $Null
            try {
                $ADDomain = Get-AzureADDomain -name $DNSZone.Name -ErrorAction Stop
            } catch {
                If (-not $ADDomain) { $ADDomain = New-AzureADDomain -Name $DNSZone.Name }
            }
            If (-not $ADDomain.IsVerified) {

                $Record = $ADDomain | Get-AzureADDomainVerificationDnsRecord | Where-Object { $_.RecordType -eq 'Txt' } | Select-Object -First 1
                Write-Host "`t`tConfirming domain with '$($Record.text)'"
                try {
                    $RootTxt = Get-AzDNSRecordSet -Name '@' -ZoneName $DNSZone.Name -RecordType TXT -ResourceGroupName $DNSZone.ResourceGroupName 
                    $VerifyRecordSet = Add-AzDnsRecordConfig -RecordSet $RootTxt -Value $Record.Text
                    $null = Set-AzDnsRecordSet -RecordSet $RootTxt
                } catch {
                    $VerifyRecordConf = New-AzDnsRecordConfig -Value $Record.Text
                    $VerifyRecordSet = New-AzDnsRecordSet -Name '@' -ZoneName $DNSZone.Name -RecordType TXT -Ttl 3600 -ResourceGroupName $DNSZone.ResourceGroupName -DnsRecords $VerifyRecordConf
                }
                $null = Confirm-AzureAdDomain -Name $DNSZone.Name
                $ADDomain = $ADDomain | Get-AzureADDomain 
            }
            $ExpectedSupportedServices = @('Email','OfficeCommunicationsOnline','OrgIdAuthentication','Intune')
            If (Compare-Object -ReferenceObject $ExpectedSupportedServices -DifferenceObject $ADDomain.SupportedServices) {
                Write-Host "`t`tUpdating supported services ($($ExpectedSupportedServices -join ',')"
                $ADDomain = $ADDomain | Set-AzureADDomain -SupportedServices $ExpectedSupportedServices
            }
            $ExDomain = Get-AcceptedDomain -Identity $DNSZone.Name -ErrorAction SilentlyContinue
            If (-not $ExDomain) { $ExDomain = Set-AcceptedDomain -Identity $DNSZone.Name -DomainType 'InternalRelay' }
            If ($ExDomain.DomainType -ne 'InternalRelay') { $ExDomain = Set-AcceptedDomain -Identity $DNSZone.Name -DomainType 'InternalRelay' }
            $TxRule = Get-TransportRule -Identity "CatchAll-$($DNSZone.Name)" -ErrorAction SilentlyContinue
            If (-not $TxRule) {
                $TxRule = New-TransportRule -Name "CatchAll-$($DNSZone.Name)" -ExceptIfSentToMemberOf $ExceptionGroup `
                    -RecipientDomainIs $DNSZone.Name -RedirectMessageTo $RedirectTo -FromScope 'NotInOrganization' `
                    -Comments ("Redirect any messages sent to addresses in @{0} that are not already assigned to accounts to '{1}'" -f $DNSZone.Name,$RedirectTo)
            }
        }
    }

    Function CreateStaticPage {
        param([parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$Zone=$Script:Zone)

        Process {
        }

    }

}

Process {
    $AzZone = CreateDNSZone -Zone $Zone
    Write-Host $AzZone.Name -ForegroundColor Black -BackgroundColor Yellow -NoNewline
    Write-Host " Name Servers" -ForegroundColor Yellow
    $AzZone.NameServers | Write-Host -ForegroundColor Yellow
    If (-not $NoOffice365) {
        $AzRecords = AddO365Records -DNSZone $AzZone
        If (-not $SkipRegistrar) {
            Write-Host "Update DNS Name Servers with Registrar of $($AzZone.Name)" -ForegroundColor Red -BackgroundColor Black
            Pause
        }
        $ExResults = AddToExchange -DNSZone $AzZone
        $ExResults
    }
    Write-Host ''
    If ($PassThru) {
        $AzZone | Get-AzDnsZone
    }
}