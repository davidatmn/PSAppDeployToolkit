<#
.SYNOPSIS
    This script performs the installation or uninstallation of Adobe Reader DC.
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
    The script is provided as a template to perform an install or uninstall of an application(s).
    The script either performs an "Install" deployment type or an "Uninstall" deployment type.
    The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
    The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
    The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
    Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
    Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
    Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
    Disables logging to file for the script. Default is: $false.
.EXAMPLE
    PowerShell.exe .\Deploy-AdobeReaderDC.ps1 -DeploymentType "Install" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-AdobeReaderDC.ps1 -DeploymentType "Install" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-AdobeReaderDC.ps1 -DeploymentType "Install" -DeployMode "Interactive"
.EXAMPLE
    PowerShell.exe .\Deploy-AdobeReaderDC.ps1 -DeploymentType "Uninstall" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-AdobeReaderDC.ps1 -DeploymentType "Uninstall" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-AdobeReaderDC.ps1 -DeploymentType "Uninstall" -DeployMode "Interactive"
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
    70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
    http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('Install','Uninstall','Repair')]
    [string]$DeploymentType = 'Install',
    [Parameter(Mandatory=$false)]
    [ValidateSet('Interactive','Silent','NonInteractive')]
    [string]$DeployMode = 'Silent',
    [Parameter(Mandatory=$false)]
    [string]$AdobeDirectory = 'D:\PSAppDeployToolkit\Applications\AdobeReaderDC',
    [Parameter(Mandatory=$false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory=$false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory=$false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor = 'Adobe'
    [string]$appName = 'Reader DC'
    [string]$appVersion = ''
    [string]$appArch = ''
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '09/16/2022'
    [string]$appScriptAuthor = 'David Thao'
    [string]$DEPLOYDIR = 'D:\PSAppDeployToolkit'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = ''
    [string]$installTitle = "${appVendor} ${appName}"

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [int32]$mainExitCode = 0

    ## Variables: Script
    [string]$deployAppScriptFriendlyName = 'Deploy Application'
    [version]$deployAppScriptVersion = [version]'3.8.4'
    [string]$deployAppScriptDate = '22/09/2022'
    [hashtable]$deployAppScriptParameters = $psBoundParameters

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [string]$moduleAppDeployToolkitMain = "${DEPLOYDIR}\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
        If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
    }
    Catch {
        If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, Close Adobe Reader With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'AdobeARM,AcroRd32,cidaemon,armsvc,AdobeUpdateService' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## Remove Any Existing Versions of Adobe Reader
        Remove-MSIApplications "Adobe Reader"
        Remove-MSIApplications "Adobe Acrobat Reader"

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        $ExePath = Get-ChildItem -Path "$AdobeDirectory" -Include AcroRdrDC*.exe -File -Recurse -ErrorAction SilentlyContinue

        If($ExePath.Exists)
        {
        Write-Log -Message "Found $($ExePath.FullName), now attempting to install $installTitle."
        ## Install Adobe Reader DC
        Show-InstallationProgress "Installing Adobe Reader DC. This may take some time. Please wait..."
        Execute-Process -Path "$ExePath" -Parameters "/sAll /rs /msi EULA_ACCEPT=YES /L*v C:\Windows\Logs\Software\AdobeReaderDC-Install.log" -WindowStyle Hidden

        ## Disable Adobe Reader DC Updater
        Write-Log -Message "Disabling the Adobe Reader DC Updater."
        Set-RegistryKey -Key 'HKLM\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown' -Name 'bUpdater' -Type DWord -Value '0'
        }

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

    }
    ElseIf ($deploymentType -ieq 'Uninstall')
    {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, Close Adobe Reader With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'AdobeARM,AcroRd32,cidaemon,armsvc,AdobeUpdateService' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'

        ## Remove Any Existing Versions of Adobe Reader
        Remove-MSIApplications "Adobe Reader"
        Remove-MSIApplications "Adobe Acrobat Reader"

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Uninstallation'


    }
    ElseIf ($deploymentType -ieq 'Repair')
    {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [string]$installPhase = 'Pre-Repair'

        ## Show Progress Message (with the default message)
        Show-InstallationProgress


        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [string]$installPhase = 'Repair'


        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [string]$installPhase = 'Post-Repair'


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
