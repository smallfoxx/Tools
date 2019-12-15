<#
.SYNOPSIS
Change profiles for GitHub Desktop
.DESCRIPTION
Change login profiles for GitHub Desktop to allow for different accounts.
.NOTES
The profiles are swapped by utilizing symbolic directory links to different named profile folders.

If this is the first type running this, create a new profile using:
    .\SwapGitHubProfile.ps1 -Profile <ProfileName> -New
The existing profile will be copied to a profile entitled 'Default'.

If you ever need to remove a profile from the list, make sure it is not the active profile and
delete the folder.
.EXAMPLE
.\SwapGitHubProfile.ps1
Will swap between profile if there are only 2 profiles available
.EXAMPLE
.\SwapGitHubProfile.ps1 -Profile MyCorp
Change active profile from current to one named 'MyCorp'
.EXAMPLE
.\SwapGitHubProfile.ps1 -Profile Newbie -New
Copies the current profile to a new directory suffixed with '-Newbie' and switches to it
.EXAMPLE
.\SwapGitHubProfile.ps1 -ListAvailable
List currently available profiles
.LINK
mklink.exe
https://desktop.github.com/
#>
[Cmdletbinding(DefaultParameterSetName="Swap")]
Param(
    [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    #The name of the profile to switch to
    [string]$Profile,

    [Parameter(Position=1,ValueFromPipelineByPropertyName=$true)]
    #Parent directory where profiles are found
    [String]$ProfilePath = "$env:USERPROFILE\AppData\Roaming",

    #Beginning of the profile direcotry (appended with '-' and the name of the profile)
    [string]$ProfilePrefix = "GitHub Desktop",

    [Parameter()]
    #Name of the configuration file used to store details about the profile
    [string]$ConfigFile = "AccountDetails.json",

    [parameter(ParameterSetName="Swap")]
    #Current version of GIT
    [string]$GitVer = "2.2.4",

    [parameter(ParameterSetName="Swap")]
    #The path to the executable used for GIT
    [string]$GitExe = "$env:USERPROFILE\AppData\Local\GitHubDesktop\app-$GitVer\resources\app\git\cmd\git.exe",

    [parameter(ParameterSetName="Swap")]
    #The path to the executable used for GitHub Desktop
    [string]$GitHubDesktop = "C:\Users\live\AppData\Local\GitHubDesktop\GitHubDesktop.exe",

    [parameter(ParameterSetName="Swap")]
    #Copies the current profile to a new profile and then swaps to it
    [Alias('Create','Copy')]
    [switch]$New,

    [parameter(ParameterSetName="ListProfiles",Mandatory=$true)]
    #List all currently available profiles
    [switch]$ListAvailable)

Begin {
    Function NewProfileObj{
        [Cmdletbinding(DefaultParameterSetName="Current")]
        Param(
            [Parameter(Position=0)]
            [string]$ProfileName = $Profile,
            [Parameter(Position=1)]
            [string]$Path = "$ProfilePath\$ProfilePrefix-$ProfileName",
            [Parameter(ParameterSetName="Current")]
            [switch]$Current,
            [Parameter(ParameterSetName="New")]
            [switch]$NewProfile)

        $ThisProfile = Get-Item $Path
        $ThisProfile | Add-Member -MemberType NoteProperty -Name ConfigFile "$($ThisProfile.FullName)\$ConfigFile"
        $ThisProfile | Add-Member -MemberType NoteProperty -Name Config -Value (NewGitHubConfigJson)
        $ThisProfile | Add-Member -MemberType ScriptProperty -Name ProfileName -Value { $this.Config.Profile }
        $ThisProfile | Add-Member -MemberType ScriptMethod -Name ReloadConfig -Value {
            If (Test-Path $This.ConfigFile) { 
                $this.Config = Get-Content $This.ConfigFile -Raw | ConvertFrom-Json
            }
        }
        $ThisProfile | Add-Member -MemberType ScriptMethod -Name SaveConfig -Value { $this.Config | ConvertTo-Json | Set-Content $This.ConfigFile }
        $ThisProfile | Add-Member -MemberType ScriptMethod -Name UpdateConfig -Value {
            $This.Config.Name = &$GitExe config --global --get user.name
            $This.Config.PublicEmail = &$GitExe config --global --get user.email
        }

        $ThisProfile.ReloadConfig()

        If ($Current) {
            $ProfileName = $ThisProfile.ProfileName
        } elseIf ($NewProfile) {
            $ThisProfile.Config.Profile = $ProfileName
            If (-not $ThisProfile.Config.Name) { $ThisProfile.UpdateConfig() }
            $ThisProfile.SaveConfig()
        }
        return $ThisProfile | Where-Object { $_.ProfileName -eq $ProfileName }
    }

    Function NewGitHubConfigJson {
        param([string]$ProfileName,
            [string]$Path)

        return @{
            "Profile" = $ProfileName
            "Name" = ""
            "PublicEmail" = ""
        }
    }
    Function NewGitHubProfile {
        Param([string]$ProfileName = $Profile,
            [string]$SourceProfile = "$ProfilePath\$ProfilePrefix")

        $NewProfilePath = "$SourceProfile-$ProfileName"

        Copy-Item $SourceProfile $NewProfilePath
        $NewProfile = NewProfileObj -ProfileName $ProfileName -Path $NewProfilePath -NewProfile

        Return $NewProfile
    }

    Function SwapProfile {
        param($NewProfile)

        Write-Host "Swapping to [$($NewProfile.ProfileName)]..." -ForegroundColor Green

        If ($GHDFile = Get-Item $GitHubDesktop) {
            $GHDProc = Get-Process -name "GitHubDesktop" -ErrorAction SilentlyContinue
            If ($GHDProc) {
                Write-Host "Stopping existing [$($GHDProc.Count)] processes..." -ForegroundColor Red -BackgroundColor Black
                $GHDProc | Stop-Process -Force
            }
        }

        If (-not $PossibleProfiles) {
            Write-Host "First implementation. Saving current profile as [Default]." -ForegroundColor DarkCyan
            If (-not $CurrentProfile.Config.Profile) { $CurrentProfile.Config.Profile = "Default" }
            Move-Item $CurrentProfile.FullName "$($CurrentProfile.FullName)-Default"
            cmd.exe /c mklink /D "$($CurrentProfile.FullName)" "$($CurrentProfile.FullName)-Default"
        }
        Write-Host "Saving existing config of [$($CurrentProfile.Config.Profile)]..."
        $ProfilePath = $CurrentProfile.FullName
        $CurrentProfile.UpdateConfig()
        $CurrentProfile.SaveConfig()
        $global:PrevProfile = $CurrentProfile

        if (Test-Path $ProfilePath) {
            Write-Host "Remove existing link at [$ProfilePath]" -ForegroundColor DarkRed -BackgroundColor Black
            cmd.exe /c rd "$ProfilePath"
        }
        Write-Host "Make new link from [$($NewProfile.FullName)]" -ForegroundColor DarkGreen -BackgroundColor Black
        cmd.exe /c mklink /D "$ProfilePath" "$($NewProfile.FullName)"
        &$GitExe config --global --replace-all user.name $NewProfile.Config.Name
        &$GitExe config --global --replace-all user.email $NewProfile.Config.PublicEmail

        If ($GHDProc -and $GHDFile) {
            Write-Host "Restarting GitHub Desktop with [$($NewProfile.ProfileName)] profile" -ForegroundColor Green -BackgroundColor Black
            &$GHDFile.FullName
        }
        $CurrentProfile = $NewProfile
    }

    $CurrentProfile = NewProfileObj -Path "$ProfilePath\$ProfilePrefix" -Current

    $PossibleProfiles = Get-ChildItem "$ProfilePath\$ProfilePrefix-*" | ForEach-Object {
        NewProfileObj -ProfileName ($_.BaseName -replace "\A[^-]+-","") -Path $_.FullName
    }
}

Process {
    If ($PSCmdlet.ParameterSetName -eq 'ListProfiles') {
        $PossibleProfiles | Select-Object ProfileName,FullName
    } else {
        If (-not $Profile -and $PossibleProfiles.Count -eq 2) {
            $Profile = $PossibleProfiles.ProfileName | Where-Object { $_ -ne $CurrentProfile.ProfileName } | Select-Object -First 1
        } 
        if ($Profile) {
            If ($CurrentProfile.ProfileName -eq $Profile) {
                Write-Host "Current profile is already [$Profile]." -ForegroundColor Yellow
            } else {
                $TargetProfile = $PossibleProfiles | Where-Object { $_.ProfileName -eq $Profile }
                If ($TargetProfile) {
                    SwapProfile -NewProfile $TargetProfile
                } elseif ($New) {
                    $TargetProfile = NewGitHubProfile
                    SwapProfile -NewProfile $TargetProfile
                } else {
                    Write-Error "Could not find a profile [$Profile]"
                }
            }
        } else {
            Write-Host "No profile specified." -ForegroundColor Yellow
        }
    }
}

End {

}