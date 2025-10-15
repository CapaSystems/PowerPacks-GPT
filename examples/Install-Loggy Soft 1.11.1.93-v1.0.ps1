[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$Packageroot,
  [Parameter(Mandatory=$true)]
  [string]$AppName,
  [Parameter(Mandatory=$true)]
  [string]$AppRelease,
  [Parameter(Mandatory=$true)]
  [string]$LogFile,
  [Parameter(Mandatory=$true)]
  [string]$TempFolder,
  [Parameter(Mandatory=$true)]
  [string]$DllPath,
  [Parameter(Mandatory=$false)]
  [Object]$InputObject=$null
)
###################
#### VARIABLES ####
###################
$global:DownloadPackage = $true # Set to $true if you want to download the kit folder from the server

# DO NOT CHANGE THESE VARIABLES
$global:Packageroot = $Packageroot
$global:AppName = $AppName
$global:AppRelease = $AppRelease
$global:LogFile = $LogFile
$global:TempFolder = $TempFolder
$global:DllPath = $DllPath
$global:InputObject = $InputObject

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

	try {
		$cs.Job_WriteLog("$LogPreTag Calling function with: Registry_Root: $Registry_Root | Registry_Key: $Registry_Key | Registry_Value_Name: $Registry_Value_Name | Registry_Value: $Registry_Value")

    if ($Registry_Key.StartsWith('\')) {
      $Registry_Key = $Registry_Key.Substring(1)
    }

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
			default {
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

						if ($Global:Debug -ne $true) {
							$cs.Job_DisableLog()
						}

						# Sets user specific variables
						switch ($User) {
							'DEFAULT' {
								$ProfileImagePath = 'C:\Users\DEFAULT'
								$Temp_Registry_Root = 'HKLM'
								$RegistryCoreKey = 'TempHive\'
								$HKUExists = $false
							}
							default {
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
								$cs.Job_EnableLog()
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
								$cs.Job_EnableLog()
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
							$cs.Job_EnableLog()
							$cs.Job_WriteLog("$LogPreTag Error: The registry hive could not be unmounted")
						}
					}
				}
			}
			default {
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
	} finally {
		$cs.Job_EnableLog()
	}
}

function PreInstall {
  #MARK: PreInstall
  <#
    PreInstall runs before the package download and if $global:DownloadPackage is set to $true.
    Use this function to check for prerequisites, such as disk space, registry keys, or other requirements.
  #>
  $cs.Log_SectionHeader("PreInstall",'o')
  if(!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:',1500)){Exit-PSScript 3333} # 1500 mb minimum disk space required


}

function Install {
  #MARK: Install
  $cs.Log_SectionHeader("Install",'o')

  $FilePath1 = Join-Path $global:Packageroot "kit" "EasyLogUSB+Installer.exe"
  $FilePath2 = Join-Path $global:Packageroot "kit" "LoggySoft-v1.11.1.93-install.exe"
  $DesktopShortcut = Join-Path $global:gsCommonDesktop "EasyLog USB.lnk"

	$File1 = Split-Path $FilePath1 -Leaf
	$File2 = Split-Path $FilePath2 -Leaf
  $msiLog1 = Join-Path $global:AppLogFolder "$($File1)_install.log"
  $msiLog2 = Join-Path $global:AppLogFolder "$($File2)_install.log"
  $TempFolder = "C:\Temp"
  $TempLog = Join-Path $TempFolder 'install.log'

  $cs.File_CreateDir($TempFolder)

  # Install EasyLogUSB+Installer.exe
  $cs.File_DelFile($TempLog)
  $cs.Shell_Execute($FilePath1, "/s /v`"/qb /norestart /L*v $TempLog`"")
  if ($cs.File_ExistFile($TempLog)) {
    $cs.File_CopyFile($TempLog, $msiLog1, $true)
  }

  # Install Loggy Soft
  $Splat = @{
    Registry_Root = 'HKEY_LOCAL_MACHINE'
    Registry_Datatype = 'String'
    Registry_Key = 'SOFTWARE\SRD'
    Registry_Value_Name = 'FirmName'
    Registry_Value = "BHJ"
  }
	Registry-Set-Value @Splat

  $Splat.Registry_Root = "HKEY_CURRENT_USER"
	Registry-Set-Value @Splat

  $Splat.Registry_Root = 'HKEY_LOCAL_MACHINE'
  $Splat.Registry_Key = "SOFTWARE\WOW6432Node\SRD"
	Registry-Set-Value @Splat

  $cs.File_DelFile($TempLog)
  $cs.Shell_Execute($FilePath2,  "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /LOG=`"$TempLog`"")
  if ($cs.File_ExistFile($TempLog)) {
    $cs.File_CopyFile($TempLog, $msiLog2, $true)
  }

  $cs.File_DelFile($DesktopShortcut)
}

function PostInstall {
  #MARK: PostInstall
  $cs.Log_SectionHeader("PostInstall",'o')

}

##############
#### MAIN ####
##############
try {
  if ($global:InputObject){$pgkit=""}else{$pgkit="kit"}
  Import-Module (Join-Path $global:Packageroot $pgkit "PSlib.psm1") -ErrorAction stop
  $cs=Add-PSDll
  $cs.Job_Start("WS",$global:AppName,$global:AppRelease,$global:LogFile,"UNINSTALL")

  $cs.Job_WriteLog("[Init]: Starting package: '" + $global:AppName + "' Release: '" + $global:AppRelease + "'")
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
  if ($global:DownloadPackage -and $global:InputObject){Start-PSDownloadPackage}
  Install
  PostInstall
  Exit-PSScript 0
}
catch {
    $line = $_.InvocationInfo.ScriptLineNumber
    $cs.Job_WriteLog("*****************","Something bad happend at line $($line): $($_.Exception.Message)")
    Exit-PSScript $_.Exception.HResult
}