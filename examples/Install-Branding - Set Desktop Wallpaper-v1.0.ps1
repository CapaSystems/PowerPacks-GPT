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
$global:WallpaperName = 'wallpaper.jpg'
$global:WallpaperDestination = "C:\Program Files\Logitrans\Branding\$global:WallpaperName"

# DO NOT CHANGE THESE VARIABLES
$global:Packageroot = $Packageroot
$global:AppName = $AppName
$global:AppRelease = $AppRelease
$global:LogFile = $LogFile
$global:TempFolder = $TempFolder
$global:DllPath = $DllPath
$global:InputObject = $InputObject

[bool]$global:DownloadPackage = $true # Set to $true if you want to download the kit folder from the server

###################
#### FUNCTIONS ####
###################
Function Registry-Set-Value {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[ValidateSet('HKEY_LOCAL_MACHINE', 'HKEY_CURRENT_USER', 'HKEY_USERS')]
		[string]$Registry_Root,
		[Parameter(Mandatory = $true)]
		[string]$Registry_Datatype,
		[Parameter(Mandatory = $true)]
		[string]$Registry_Key,
		[Parameter(Mandatory = $true)]
		[string]$Registry_Value_Name,
		[Parameter(Mandatory = $false)]
		[string]$Registry_Value
	)
	$LogPreTag = 'Registry-Set-Value:'
	$cs.Job_WriteLog("$LogPreTag Calling function with: Registry_Root: $Registry_Root | Registry_Key: $Registry_Key | Registry_Value_Name: $Registry_Value_Name | Registry_Value: $Registry_Value")

	#region Convert Registry_Root as this is not supported by the ScriptingLibrary yet
	<#
		TODO: When ScriptingLibrary supports HKEY_CURRENT_USER, we can remove this region.
	#>
	switch ($Registry_Root) {
		'HKEY_CURRENT_USER' {
			# PowerBricks is running as SYSTEM, so we need to handle this differently
			$Temp_Registry_Root = $null
		}
		'HKEY_USERS' {
			$Temp_Registry_Root = 'HKU'
		}
		Default {
			$Temp_Registry_Root = 'HKLM'
		}
	}
	#endregion

	switch ($Registry_Root) {
		'HKEY_CURRENT_USER' {
			$cs.Job_WriteLog("$LogPreTag Building Array With All Users That Have Logged On To This Unit....")
			$RegKeys = $cs.Reg_EnumKey('HKLM', 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList', $true)

			# Convert from array to list and add DEFAULT user
			$UsersRegKey = @()
			$UsersRegKey += $RegKeys
			$UsersRegKey += 'DEFAULT'

			try {
				foreach ($User in $UsersRegKey) {
					$cs.Job_WriteLog("$LogPreTag Running for $User")

					# Skip if the user is not a user or the default user
					$split = $User -split '-'
					if ($split[3] -ne '21' -and $User -ne 'DEFAULT' -and $split[3] -ne '1') {
						$cs.Job_WriteLog("$LogPreTag Skipping $User")
						continue
					}

					# Sets user specific variables
					switch ($User) {
						'DEFAULT' {
							$ProfileImagePath = 'C:\Users\DEFAULT'
							$Temp_Registry_Root = 'HKLM'
							$RegistryCoreKey = 'TempHive\'
							$HKUExists = $false
						}
						Default {
							$ProfileImagePath = $cs.Reg_GetExpandString('HKLM', "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$User", 'ProfileImagePath')
							if ($ProfileImagePath) {
								if ($cs.Reg_ExistKey('HKU', $User)) {
									$Temp_Registry_Root = 'HKU'
									$RegistryCoreKey = "$User\"
									$HKUExists = $true
								} else {
									$Temp_Registry_Root = 'HKLM'
									$RegistryCoreKey = 'TempHive\'
									$HKUExists = $false
								}
							} else {
								$cs.Job_WriteLog("$LogPreTag ProfileImagePath is empty for $User. Skipping...")
								continue
							}
						}
					}

					# Load the NTUSER.DAT file if it exists
					$NTUserDatFile = Join-Path $ProfileImagePath 'NTUSER.DAT'
					if ($RegistryCoreKey -eq 'TempHive\' -and ($cs.File_ExistFile($NTUserDatFile))) {
						$RetValue = $cs.Shell_Execute('cmd.exe', "/c reg load HKLM\TempHive `"$ProfileImagePath\NTUSER.DAT`"")
						if ($RetValue -ne 0) {
							$cs.Job_WriteLog("$LogPreTag Error: The registry hive for $User could not be mounted. Skipping...")
							continue
						}
					} elseif ($HKUExists) {
						# Do nothing
					}	else {
						$cs.Job_WriteLog("$LogPreTag NTUSER.DAT does not exist for $User. Skipping...")
						continue
					}

					# Set the registry value
					$RegKeyPathTemp = "$RegistryCoreKey$Registry_Key"
					switch -Exact ($Registry_Datatype) {
						'String' {
							$cs.Reg_SetString($Temp_Registry_Root, $RegKeyPathTemp, $Registry_Value_Name, $Registry_Value)
						}
						'DWORD (32-bit)' {
							$cs.Reg_SetDword($Temp_Registry_Root, $RegKeyPathTemp, $Registry_Value_Name, [int]$Registry_Value)
						}
						'Expanded String' {
							$cs.Reg_SetExpandString($Temp_Registry_Root, $RegKeyPathTemp, $Registry_Value_Name, $Registry_Value)
						}
					}

					# Unload the NTUSER.DAT file if it was loaded
					if ($RegistryCoreKey -eq 'TempHive\') {
						[gc]::collect()
						[gc]::WaitForPendingFinalizers()
						Start-Sleep -Seconds 2
						$RetValue = $cs.Shell_Execute('cmd.exe', '/c reg unload HKLM\TempHive')
						if ($RetValue -ne 0) {
							$cs.Job_WriteLog("$LogPreTag Error: The registry hive for $User could not be unmounted")
						}
					}
				}
			} finally {
				if ($cs.Reg_ExistKey('HKLM', 'TempHive')) {
					[gc]::collect()
					[gc]::WaitForPendingFinalizers()
					Start-Sleep -Seconds 2
					$RetValue = $cs.Shell_Execute('cmd.exe', '/c reg unload HKLM\TempHive')
					if ($RetValue -ne 0) {
						$cs.Job_WriteLog("$LogPreTag Error: The registry hive could not be unmounted")
					}
				}
			}
		}
		Default {
			# TODO: Change this to use the $Registry_Root instead of $Temp_Registry_Root
			switch -Exact ($Registry_Datatype) {
				'String' {
					$cs.Reg_SetString($Temp_Registry_Root, $Registry_Key, $Registry_Value_Name, $Registry_Value)
				}
				'DWORD (32-bit)' {
					$cs.Reg_SetDword($Temp_Registry_Root, $Registry_Key, $Registry_Value_Name, [int]$Registry_Value)
				}
				'Expanded String' {
					$cs.Reg_SetExpandString($Temp_Registry_Root, $Registry_Key, $Registry_Value_Name, $Registry_Value)
				}
			}
		}
	}
}

function PreInstall {
	$cs.Log_SectionHeader('PreInstall', 'o')

	$source = Join-Path $global:Packageroot "kit" $global:WallpaperName
	$cs.File_CopyFile($source, $global:WallpaperDestination, $true)
}

function Install {
	$cs.Log_SectionHeader('Install', 'o')

	$Splat = @{
		Registry_Root = "HKEY_CURRENT_USER"
		Registry_Datatype = "String"
		Registry_Key      = "Software\Microsoft\Windows\CurrentVersion\Policies\System"
		Registry_Value_Name = "Wallpaper"
		Registry_Value = $global:WallpaperDestination
	}
	Registry-Set-Value @Splat

	$cs.Reg_SetString('HKLM', "SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP", "LockScreenImagePath", $global:WallpaperDestination)
	$cs.Reg_SetString('HKLM', 'SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP', 'LockScreenImageUrl', $global:WallpaperDestination)
	$cs.Reg_SetDword('HKLM', 'SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP', 'LockScreenImageStatus', 1)
}

	function PostInstall {
	$cs.Log_SectionHeader('PostInstall', 'o')
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
	$cs = Add-PsDll
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
	Initialize-Variables

	PreInstall
	Install
	PostInstall
	Exit-PSScript $Error
} catch {
	$line = $_.InvocationInfo.ScriptLineNumber
	$cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")
	Exit-PSScript $_.Exception.HResult
}