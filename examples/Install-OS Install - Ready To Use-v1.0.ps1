[CmdletBinding()]
Param(
	[Parameter(Mandatory = $true)]
	[string]$Packageroot,
	[Parameter(Mandatory = $true)]
	[string]$AppName,
	[Parameter(Mandatory = $true)]
	[string]$AppRelease,
	[Parameter(Mandatory = $true)]
	[string]$LogFile,
	[Parameter(Mandatory = $true)]
	[string]$TempFolder,
	[Parameter(Mandatory = $true)]
	[string]$DllPath,
	[Parameter(Mandatory = $false)]
	[Object]$InputObject = $null
)
###################
#### VARIABLES ####
###################
[bool]$global:DownloadPackage = $false # Set to $true if you want to download the kit folder from the server

# DO NOT CHANGE THESE VARIABLES
$global:Packageroot = $Packageroot
$global:AppName = $AppName
$global:AppRelease = $AppRelease
$global:LogFile = $LogFile
$global:TempFolder = $TempFolder
$global:DllPath = $DllPath
$global:InputObject = $InputObject

$global:ScriptError = $Error

###################
#### FUNCTIONS ####
###################
function FinalReboot {
	$cs.Log_SectionHeader('FinalReboot', 'o')

	$Installed = 0
	$Failed = 0
	$Waiting = 0
	$Unknown = 0

	$RegKeys = $cs.Reg_EnumKey('HKLM', 'Software\CapaSystems\CapaInstaller\Statistics', $true)
	foreach ($RegKey in $RegKeys) {
		switch ($RegKey) {
			"CapaInstaller Agent" {
				Continue
			}
			"CapaInstaller Healthcheck" {
				Continue
			}
			"Overall Status" {
				Continue
			}
			"PreDiskPartScript" {
				Continue
			}
			"PreDriverCopy" {
				Continue
			}
			"PreGuiScript" {
				Continue
			}
			"WINPEINVENTORY" {
				Continue
			}
			Default {
				$RegKeyPath = "Software\CapaSystems\CapaInstaller\Statistics\$RegKey"
				$Status = $cs.Reg_GetString('HKLM', $RegKeyPath, 'Status')
				$cs.Job_WriteLog("Status: $Status")

				switch ($Status) {
					"Installed" {
						$Installed++
					}
					"Failed" {
						$Failed++
					}
					"Failed Install" {
						$Failed++
					}
					"Waiting" {
						$Waiting++
					}
					'Cancel' {
						$Waiting++
					}
					Default {
						$Unknown++
					}
				}
			}
		}
	}

	$JpsStatus = CustomJps

	if ($Waiting -eq 0 -and $JpsStatus) {
		$cs.reg_setstring('HKLM', 'SOFTWARE\CapaSystems\CapaInstaller\ciNotify', 'iInstalled', "Successful packages: $Installed")
		$cs.reg_setstring('HKLM', 'SOFTWARE\CapaSystems\CapaInstaller\ciNotify', 'iFailed', "Failed packages: $Failed")
		$cs.reg_setstring('HKLM', 'SOFTWARE\CapaSystems\CapaInstaller\ciNotify', 'iUnknown', "Unknown packages: $Unknown")
		$cs.Reg_SetInteger('HKLM', 'Software\CapaSystems\Capainstaller\ciNotify', "FinalReboot", 1)
		$global:Reboot = $true
	}
 else {
		$global:Reboot = $false
	}
}

function RemoveStandardGroups {
	$cs.Log_SectionHeader('RemoveStandardGroups', 'o')

	$Groups = CMS_GetGroupMembership

	foreach ($Group in $Groups) {
		if ($Group.Name -like 'Standard Software*' -or $Group.Name -like 'OSD *') {
			CMS_RemoveComputerFromStaticGroup -group $Group.Name
		}
	}
}

function Get-IniContent ($filePath) {
	$ini = @{}
	switch -regex -file $FilePath {
		'^\[(.+)\]' {
			# Section
			$section = $matches[1]
			$ini[$section] = @{}
			$CommentCount = 0
		}
		'^(;.*)$' {
			# Comment
			$value = $matches[1]
			$CommentCount = $CommentCount + 1
			$name = 'Comment' + $CommentCount
			$ini[$section][$name] = $value
		}
		'(.+?)\s*=(.*)' {
			# Key
			$name, $value = $matches[1..2]
			$ini[$section][$name] = $value
		}
	}
	return $ini
}

function CustomJps {
	# Convert content from ANSI to UTF8
	$Path = Join-Path $cs.gsWorkstationPath 'Agent' "$($cs.gsUUID).jps"
	$Destination = Join-Path $global:Packageroot 'Packages.jps'

	$ANSI = [System.Text.Encoding]::GetEncoding(1252)

	if (!$cs.File_ExistFile($Path)) {
		$cs.Job_WriteLog("CustomJps return: $true")
	}

	$Content = Get-Content -Path $Path -Encoding $ANSI
	Set-Content -Path $Destination -Value $Content -Encoding UTF8
	$Content = Get-IniContent -filePath $Destination

	foreach ($Section in $Content.JOBS) {
		If ($Section.Name -like "WS Ready To Use*") {
			continue
		}
		If ($Section.Name -like 'PerformanceGuard*') {
			continue
		}
		If ($Section.Name -like 'Security - Cleanup SilentInstall.dat*') {
			continue
		}
		If ($Section.Name -like 'Flash Player ActiveX 31.0.0.108*') {
			continue
		}
		If ($Section.Name -like 'HotFixInstaller*') {
			continue
		}

		if ($Section.Value -like "Waiting*") {
			$cs.Job_WriteLog("CustomJps :", "Waiting for package: $($Section.Name)")
			$cs.Job_WriteLog("CustomJps return: $false")
			return $false
		}
	}

	$cs.Job_WriteLog('CustomJps :', 'All packages are installed')
	$cs.Job_WriteLog("CustomJps return: $true")
	return $true
}

##############
#### MAIN ####
##############
try {
	##############################################
	#load core PS lib - don't mess with this!
	if ($global:InputObject) { $pgkit = '' }else { $pgkit = 'kit' }
	Import-Module (Join-Path $global:Packageroot $pgkit 'PSlib.psm1') -ErrorAction stop
	#load Library dll
	$cs = Add-PSDll
	##############################################

	#Begin
	$cs.Job_Start('WS', $global:AppName, $global:AppRelease, $global:LogFile, 'INSTALL')
	$cs.Job_WriteLog("[Init]: Starting package: '" + $global:AppName + "' Release: '" + $global:AppRelease + "'")
	if (!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:', 1500)) { Exit-PSScript 3333 }
	if ($global:DownloadPackage -and $global:InputObject) { Start-PSDownloadPackage }

	$cs.Job_WriteLog("[Init]: `$PackageRoot:` '" + $global:Packageroot + "'")
	$cs.Job_WriteLog("[Init]: `$AppName:` '" + $global:AppName + "'")
	$cs.Job_WriteLog("[Init]: `$AppRelease:` '" + $global:AppRelease + "'")
	$cs.Job_WriteLog("[Init]: `$LogFile:` '" + $global:LogFile + "'")
	$cs.Job_WriteLog("[Init]: `$global:AppLogFolder:` '" + $global:AppLogFolder + "'")
	$cs.Job_WriteLog("[Init]: `$TempFolder:` '" + $global:TempFolder + "'")
	$cs.Job_WriteLog("[Init]: `$DllPath:` '" + $global:DllPath + "'")
	$cs.Job_WriteLog("[Init]: `$global:DownloadPackage`: '" + $global:DownloadPackage + "'")
	$cs.Job_WriteLog("[Init]: `$global:PSLibVersion`: '" + $global:PSLibVersion + "'")

	#RemoveStandardGroups
	FinalReboot
	if ($global:Reboot) {
		$Path = Join-Path $cs.gsWorkStationPath "SilentInstall.dat"
		if ($cs.File_ExistFile($Path)) {
			$cs.File_DelFile($Path)
		}
		$cs.Job_RebootWS('Check if all package is installed')
		Exit-PSScript $global:ScriptError
	}
 else {
		CMS_RunSystemAgent -delay '5s'

		# PACKAGE_CANCELLED_RETRY_LATER
		Exit-PSScript 3326
	}
}
catch {
	$line = $_.InvocationInfo.ScriptLineNumber
	$cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")
	Exit-PSScript $_.Exception.HResult
}