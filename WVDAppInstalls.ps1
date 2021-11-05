# Purpose: this script builds a new VM for Windows Virtual Desktop, based on the Marketplace "Win10 1909 Enterprise Multisession + O365 Apps" image
# Prerequisites: 
#   1. Need to ensure the VM is in the right OU so it picks up appropriate GPOs
#   2. Need to execute this script using a domain admin account
#
# Before executing this script, need to run in PS: 
#
#		Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
# 
# Written by Craig Woodburn July 2020
#
# NOTE!!! There is no error checking in this script. Currently you need to check the output yourself to ensure there have been no errors
# There are individual logs for many of the installs though, stored in the "c:\buildartifacts" directory
#
#
# Future Enhancements:
#                       * implement full logging
#                       * handle windows updates
#                       * setup scheduled task to update windows defender antivirus definitions


Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

#Ensure we're running this script as an administrator
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

# Setup Timestamp function to track progress
    function Get-TimeStamp {
    
        return "[{0:dd/MM/yy} {0:HH:mm:ss}]" -f (Get-Date)
    
    }

# Change timezone to Australia 
    Write-Host -f Green "Started Script at $(Get-TimeStamp) in the wrong timezone. Fixing time zone now..."
    set-timezone -name "AUS Eastern Standard Time"
    Write-Host -f Green "Timezone Corrected $(Get-TimeStamp)"
    Write-Host -f Green "Started Script at $(Get-TimeStamp)"

#Create temp folder
    New-Item -Path 'C:\BuildArtifacts' -ItemType Directory -Force | Out-Null


#Install Choco and .net3.5 (for iMIS)
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    choco feature enable -n allowGlobalConfirmation
    choco install dotnet3.5 -r
    Write-Host -f Green "Finished Choco installs at $(Get-TimeStamp)"
    Start-Sleep -Seconds 10

#Install Microsoft Office
	
    Write-Host -f Green "Installing Microsoft Office at $(Get-TimeStamp)"
    #Remove Default OneNote install so we don't end up with two
    Get-AppxPackage *OneNote* | Remove-AppxPackage
	pushd "\\c1sccm01\Sources\Office 365 Pro Plus 2102"
	Invoke-Command -ScriptBlock {.\setup.exe /configure AVDconfiguration.xml}
    Write-Host -f Green "Finished Microsoft Office install at $(Get-TimeStamp)"
	popd
    Start-Sleep -Seconds 300

#Install Onedrive

    Write-Host -f Green "Installing Microsoft Onedrive at $(Get-TimeStamp)"
	pushd "\\c1sccm01\Sources\OneDrive 21.196.0921.0007"
	Invoke-Command -ScriptBlock {.\OneDriveSetup.exe /allusers /silent}
    Write-Host -f Green "Finished Microsoft Onedrive install at $(Get-TimeStamp)"
	popd
    Start-Sleep -Seconds 60

#install Visio 2019
    Write-Host -f Green "Installing Microsoft Visio at $(Get-TimeStamp)"
    pushd "\\c1sccm01\Sources\Office 2019 Visio Pro WVD"
    # Start-Process "\\c1sccm01\Sources\Office 2019 Visio Pro WVD\setup.exe" -Wait -ArgumentList '/configure "\\c1sccm01\Sources\Office 2019 Visio Pro WVD\ConfigurationWVD.xml"'
    Invoke-Command -ScriptBlock {.\setup.exe /configure "\\c1sccm01\Sources\Office 2019 Visio Pro WVD\ConfigurationWVD.xml"}
    popd
    Start-Sleep -Seconds 300
    Write-Host -f Green "Installing Microsoft Visio at $(Get-TimeStamp)"

#Install Notepad++
    Write-Host -f Green "Installing Notepad++ at $(Get-TimeStamp)"
    pushd "\\c1sccm01\Sources\Notepad ++\8.1.9"
    Invoke-Command -ScriptBlock {.\npp.8.1.9.Installer.x64.exe /S}
    popd
    Write-Host -f Green "Finished Notepad++ install at $(Get-TimeStamp)"
    Start-Sleep -Seconds 10

#Install Edge - no longer required as preinstalled
    #Write-Host -f Green "Installing Edge at $(Get-TimeStamp)"
    #Invoke-Expression -Command 'msiexec /i "\\c1sccm01\Sources\Edge Chromium 95.0.1020.30\MicrosoftEdgeEnterpriseX64.msi" /qn /norestart /l*v c:\BuildArtifacts\edgeinstall.log'
    #Write-Host -f Green "Finished Edge install at $(Get-TimeStamp)"
    #Start-Sleep -Seconds 10

#Install Keepass
    Write-Host -f Green "Installing Keepass at $(Get-TimeStamp)"
    Invoke-Expression -Command '\\c1sccm01\sources\Keepass\KeePass-2.49-Setup.exe /install /silent /norestart'
    Write-Host -f Green "Finished Keepass install at $(Get-TimeStamp)"
    Start-Sleep -Seconds 30
    # Copy keepass global config file
    Copy-Item -path \\c1sccm01\sources\WindowsVirtualDesktop\KeePass.config.xml -destination "C:\Program Files (x86)\KeePass Password Safe 2"


#InstallFSLogix - no longer needed as this is preinstalled now
    #Write-Host -f Green "Installing fsLogix at $(Get-TimeStamp)"
    #Invoke-Expression -Command '\\c1sccm01\Sources\WindowsVirtualDesktop\FsLogix\x64\Release\FSLogixAppsSetup.exe /install /quiet /norestart'    
    #Invoke-Expression -Command '\\c1sccm01\Sources\WindowsVirtualDesktop\FsLogix\x64\Release\FSLogixAppsRuleEditorSetup.exe /install /quiet /norestart'    
    #Start-Sleep -Seconds 30
    #Write-Host -f Green "Finished fsLogix at $(Get-TimeStamp)"

    # Configure fslogix to enable roaming profile for WVD users
        
		# ********&&&&&&& need to update this reg for Test **********&&&&&&&&&&&&&&!!!!!!!!!
		
		#reg import "\\c1sccm01\sources\WindowsVirtualDesktop\FSLogixProfileSettingsTest.reg"

        #The following 2 properties are no longer needed here because they are controlled via GPO
        #New-ItemProperty -Path HKLM:\SOFTWARE\FSLogix\Profiles -name PreventLoginWithFailure -PropertyType DWord -Value 1 -Force | Out-Null
        #New-ItemProperty -Path HKLM:\SOFTWARE\FSLogix\Profiles -name DeleteLocalProfileWhenVHDShouldApply -PropertyType DWord -Value 1 -Force | Out-Null
   

#Install Chrome
    Start-Process msiexec.exe -Wait -ArgumentList '/i \\c1sccm01\sources\Chrome\94.0.4606.81\googlechromestandaloneenterprise64.msi /qn /norestart /l*v c:\BuildArtifacts\chromeinstall.log'

#Install Convene
    &"\\c1sccm01\sources\Azeus Convene\5.8.509727\convene_setup.5.8.509727-64bit.exe" "/silent"
    Start-Sleep -Seconds 10

#Install Teams
    # recommended Teams version from Jason (Microsoft) is https://statics.teams.cdn.office.net/production-windows-x64/1.4.00.4167/Teams_windows_x64.msi
    #InstallTeamsMachinemode Preview Media Optimisations - Reg pre-reqs
    Write-Host -f Green "Installing Teams at $(Get-TimeStamp)"
    New-Item -Path HKLM:\SOFTWARE\Microsoft\Teams -Force | Out-Null
    New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Teams -name IsWVDEnvironment -Value '1' -Force | Out-Null


    # Video support for Teams!

    Write-Host -f Green "Installing Teams (Visual C) at $(Get-TimeStamp)"
    #Install VC++ & WebSocket Service then Teams with media optimisations
    #Invoke-Expression -Command 'msiexec /i \\c1sccm01\Sources\WindowsVirtualDesktop\websocket\vc.msi /qn /norestart /l*v c:\BuildArtifacts\visualcinstall.log'
    #Start-Process msiexec.exe -Wait -ArgumentList '/i \\c1sccm01\Sources\WindowsVirtualDesktop\websocket\vc.msi /qn /norestart /l*v c:\BuildArtifacts\visualcinstall.log'
    #Start sleep
    #Start-Sleep -Seconds 120
    Write-Host -f Green "Installing Teams (Websocket Redirector) at $(Get-TimeStamp)"

    Start-Process msiexec.exe -Wait -ArgumentList '/i \\c1sccm01\Sources\WindowsVirtualDesktop\websocket\MsRdcWebRTCSvc_HostSetup_1.1.2110.16001_x64.msi /qn /norestart /l*v c:\BuildArtifacts\websocketinstall.log'

    #Start sleep
    #Start-Sleep -Seconds 30

    #Normal Teams Install
    Write-Host -f Green "Installing Teams (Teams App) at $(Get-TimeStamp)"

    Start-Process msiexec.exe -Wait -ArgumentList '/i \\c1sccm01\Sources\WindowsVirtualDesktop\TeamsInstaller\Teams64bitv4.29469.msi /qn /l*v c:\BuildArtifacts\teamsinstall.log ALLUSER=1 ALLUSERS=1'


# Fix Teams Timezone settings
    reg import "\\c1sccm01\sources\WindowsVirtualDesktop\TeamsTimeZonesettings.reg"

# Install Acrobat Pro and Updates...
    #Write-Host -f Green "Install AdobePro at $(Get-TimeStamp)"
    #Start-Process msiexec.exe -Wait -ArgumentList '/i "\\c1sccm01\Sources\Adobe\Acrobat Pro DC 2015.007.20033\AcroPro.msi" /q IGNOREVCRT64=1 /t "\\c1sccm01\sources\Adobe\Acrobat Pro DC 2015.007.20033\AcrobatTPB.mst" /norestart /l*v c:\BuildArtifacts\adobeproinstall.log'
    #Start-Sleep -Seconds 180
    #Start-Process msiexec.exe -Wait -ArgumentList '/update "\\c1sccm01\sources\Adobe\Acrobat Pro DC 2020.013.20064\AcrobatDCUpd2001320064.msp" /q /norestart /l*v c:\BuildArtifacts\adobeproupdate.log'

    #update process current doesn't work for reader but choco does it for us for now at least
    #Start-Process msiexec.exe -Wait -ArgumentList '/update "\\c1sccm01\sources\Adobe\Reader DC 2020.013.20064\AcroRdrDCUpd2001320064.msp" /q /norestart /l*v c:\BuildArtifacts\adobereaderupdate.log'
    #Write-Host -f Green "Finished AdobePro at $(Get-TimeStamp)"

# Install JanusSeal
    # 7Aug20 Craig has commented out next line because Andrew Nott has applied these reg settings by GPO instead
    # reg import "\\c1sccm01\sources\WindowsVirtualDesktop\janusnetregentries.reg"
    Invoke-Expression -Command 'msiexec /i \\c1sccm01\sources\JanusSEAL\3.5.1\janusSEALforOutlookSetup_x64.msi /quiet /norestart /l*v c:\BuildArtifacts\janussealinstall.log'

# Install iMIS
    Start-Sleep -Seconds 30
    Write-Host -f Green "Install iMIS at $(Get-TimeStamp)"
    Start-Process -FilePath "\\c1sccm01\sources\appexports\asi_files\Content_abaf7f5e-5f1b-4825-80d9-fae65bb74894\iMIS_InstallWVD.cmd" -Wait
    Write-Host -f Green "iMIS install finished at $(Get-TimeStamp)"
    
# Install PowerPDF
    Write-Host -f Green "Install PowerPDF at $(Get-TimeStamp)"
    Start-Process msiexec.exe -Wait -ArgumentList '/i "\\c1sccm01\Sources\WindowsVirtualDesktop\PowerPDF\Kofax Power PDF Advanced.msi" /q TRANSFORMS="\\c1sccm01\Sources\WindowsVirtualDesktop\PowerPDF\TPBPowerPDF.mst" /norestart /l*v c:\BuildArtifacts\powerPDFinstall.log'
    Write-Host -f Green "PowerPDF finished at $(Get-TimeStamp)"    

# Install Ivanti App Control
    Write-Host -f Green "Install Ivanti App Control at $(Get-TimeStamp)"
    Start-Process msiexec.exe -Wait -ArgumentList '/i "\\c1sccm01\Sources\IvantiAppControlClientSoftware\ClientCommunicationsAgent64.msi" WEB_SITE="http://c1flex02:7751" GROUP_NAME="TPB Restricted Deployment Group" /quiet /norestart /l*v c:\BuildArtifacts\IvantiClientCommsAgentInstall.log'
    Start-Process msiexec.exe -Wait -ArgumentList '/i "\\c1sccm01\Sources\IvantiAppControlClientSoftware\ApplicationManagerAgent64.msi" /quiet /norestart /l*v c:\BuildArtifacts\IvantiAppManagerAgentInstall.log'
    Write-Host -f Green "Ivanti App Control finished at $(Get-TimeStamp)"    

#deploy Visio FsLogix Rules
    Copy-Item -path \\c1sccm01\sources\WindowsVirtualDesktop\FSLogixVisioRestriction.* -destination "C:\Program Files\FSLogix\Apps\Rules\"


# Install Developer Tools

	#Create DeveloperTools folder
	New-Item -Path 'C:\DeveloperTools' -ItemType Directory -Force | Out-Null
	New-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Developer Tools' -ItemType Directory -Force | Out-Null

	# GitDesktop
	Start-Process msiexec.exe -Wait -ArgumentList '/i \\c1sccm01\Sources\Git\2.32.0.2\GitHubDesktopSetup-x64.msi /qn /norestart /l*v "c:\DeveloperTools\GitDesktopInstall.log"'
	write-host "git desktop done"

	# GIT for Windows
	Invoke-Expression -Command '\\c1sccm01\Sources\Git\2.33.0.2\Git-2.33.0.2-64-bit.exe /verysilent'
	write-host "git for Windows done"


	# XRMToolbox
	Expand-Archive -LiteralPath '\\c1sccm01\Sources\XRMToolbox\XrmToolbox.zip' -DestinationPath 'C:\DeveloperTools'
	copy '\\c1sccm01\sources\WindowsVirtualDesktop\XrmToolBox.lnk' 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Developer Tools'
	write-host "XRM done"

	# Sourcetree
	Start-Process msiexec.exe -Wait -ArgumentList '/i \\c1sccm01\Sources\Sourcetree\3.4.5\SourcetreeEnterpriseSetup_3.4.5.msi /qn /norestart /l*v "c:\DeveloperTools\SourcetreeInstall.log" ACCEPTEULA=1'
	write-host "sourcetree done"

	# Postman
    pushd "\\c1sccm01\Sources\PostmanRESTAPI"
    Invoke-Command -ScriptBlock {.\Postman-win64-8.10.0-Setup.exe --silent}
    popd
	write-host "postman done"

	# VSCode
	Invoke-Expression -Command "\\c1sccm01\Sources\VSCode\1.59.0MachineWide\VSCodeSetup-x64-1.59.0.exe /silent /MERGETASKS=!runcode"
	write-host "vscode done"

	# .Net Framework 5.0
	Invoke-Expression -Command '\\c1sccm01\Sources\.NetSDK\dotnet-sdk-5.0.400-win-x64.exe /install /quiet /norestart'

	Write-Host -f Green "All finished"

	Move-Item "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\GitHub, Inc" 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Developer Tools'
	Move-Item "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Postman" 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Developer Tools'
	Move-Item 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Visual Studio Code' 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Developer Tools'
	Copy-Item 'C:\Users\Public\Desktop\Sourcetree.lnk' 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Developer Tools'

	# ms-dotnettools.csharp-1.23.14 - can only be installed thru VSCode


# Cleanup and other customisations...
    Write-Host -f Green "Begin cleanup and other customisations at $(Get-TimeStamp)"
    Xcopy "\\c1sccm01\sources\WindowsVirtualDesktop\public pictures folder on WVD\*.*" C:\Users\Public\Pictures\WVDfiles\

    # Change default wallpaper for new users
        takeown /f c:\windows\Web\wallpaper\Windows\img0.jpg
        takeown /f C:\Windows\Web\4K\Wallpaper\Windows\*.*
        icacls c:\windows\WEB\wallpaper\Windows\img0.jpg /Grant "System:(F)"
        icacls c:\windows\WEB\wallpaper\Windows\img0.jpg /Grant "Administrators:(F)"
        icacls C:\Windows\Web\4K\Wallpaper\Windows\*.* /Grant "System:(F)"
        icacls C:\Windows\Web\4K\Wallpaper\Windows\*.* /Grant "Administrators:(F)"
        del c:\windows\WEB\wallpaper\Windows\img0.jpg
        Remove-Item -path C:\Windows\Web\4K\Wallpaper\Windows\*
        copy "\\c1sccm01\sources\WindowsVirtualDesktop\public pictures folder on WVD\Desktop-background_v1.jpg" c:\windows\WEB\wallpaper\Windows\img0.jpg
  
    # Create iMIS DesktopShortcut
        $AppLocation = "C:\Program Files (x86)\ASI\iMISProd\Omnis7\Omnis7.exe"
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\iMIS Desktop.lnk")
        $Shortcut.TargetPath = $AppLocation
        $Shortcut.Arguments =" imis4.lbr /m"
        $Shortcut.IconLocation = "C:\Program Files (x86)\ASI\iMISTest\Omnis7\Omnis7.exe"
        $Shortcut.Description ="iMIS Desktop"
        $Shortcut.WorkingDirectory ="C:\Program Files (x86)\ASI\iMISProd\"
        $Shortcut.Save()

    # Create QAS Shortcut
        $AppLocation = "\\Qas\qas\Prod\QAS.exe"
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\QAS.lnk")
        $Shortcut.TargetPath = $AppLocation
        $Shortcut.IconLocation = "C:\Users\Public\Pictures\WVDfiles\QAS ICON.ico"
        $Shortcut.Description ="QAS"
        $Shortcut.WorkingDirectory ="\\Qas\Qas\Prod"
        $Shortcut.Save()

    # Create WebViews Shortcut
        $AppLocation = "http://staff.tpb.gov.au/TPBStaff/Sign_In.aspx?LoginRedirect=true&returnurl=%2f"
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\iMIS Webviews.lnk")
        $Shortcut.TargetPath = $AppLocation
        $Shortcut.IconLocation = "C:\Users\Public\Pictures\WVDfiles\webviews_rIb_icon.ico"
        $Shortcut.Description ="iMIS Webviews"
        $Shortcut.Save()

    # Create SharePoint shortcut
        $AppLocation = "https://taxpractitionersboard.sharepoint.com/SitePages/Home.aspx"
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\TPB SharePoint.lnk")
        $Shortcut.TargetPath = $AppLocation
        $Shortcut.IconLocation = "C:\Users\Public\Pictures\WVDfiles\TPB logo.ico"
        $Shortcut.Description ="TPB SharePoint"
        $Shortcut.Save()

    # Create shortcut for G drive
        Copy-Item -path "\\c1sccm01\sources\WindowsVirtualDesktop\shortcuts\G Drive.lnk" -destination "C:\Users\Public\Desktop" -Recurse

    # Copy Watermark app over plus shortcut to start it up in startup items
        Copy-Item -path "\\c1sccm01\sources\WindowsVirtualDesktop\watermark" -destination "C:\Program Files (x86)\watermark" -Recurse
        Copy-Item -path "\\c1sccm01\sources\WindowsVirtualDesktop\watermark\watermark.lnk" -destination "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp" -Recurse

   
    # Copy start menu and default taskbar settings to VM for later use by GPO
        Copy-Item -path \\c1sccm01\sources\WindowsVirtualDesktop\taskbarlayout.xml -destination C:\Users\Public\Pictures\WVDfiles

    #setup scheduled tasks
        $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument 'restart-computer -force'
        $trigger =  New-ScheduledTaskTrigger -Daily -At 2am
        $user = "System"
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Daily Restart" -Description "Daily restart to keep things fresh" -User $user

    #hybrid join settings
        New-Item -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ -Force | Out-Null
        New-Item -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\AAD -Force | Out-Null
        New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\AAD -name TenantId -Value "b88d715e-046a-4739-aade-c329479b0606" -Force | Out-Null
        New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\AAD -name TenantName -Value "tpb.gov.au" -Force | Out-Null

    #disable automatic updates (currently missing this step - to be applied via GPO instead)
    #New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -name NoAutoUpdate -value 1 -Force | Out-Null
    #disable storage sense (recommended by https://docs.microsoft.com/en-us/azure/virtual-desktop/set-up-customize-master-image)
    New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -name 01 -value 0 -Force | Out-Null

    #Photo viewer associations
    reg import "\\c1sccm01\sources\WindowsVirtualDesktop\photoviewersettings.reg"


    Write-Host -f Green "Finished Cleanup at $(Get-TimeStamp)"

    #run optimisation
    New-Item -Path 'C:\Optimize' -ItemType Directory -Force | Out-Null
    Copy-Item -path "\\c1sccm01\sources\WindowsVirtualDesktop\WVDOptimisations\*" -destination "C:\Optimize" -Recurse
    Write-Host -f Green "WVD Optimisations at $(Get-TimeStamp)"
    pushd "C:\Optimize"
    .\Win10_VirtualDesktop_Optimize.ps1 -AcceptEULA -Restart
    popd
    
    Write-Host -f Green "Finished WVD Optimisations at $(Get-TimeStamp)"

Write-Host -f Green "All finished at $(Get-TimeStamp)"
pause
Restart-Computer -Force
