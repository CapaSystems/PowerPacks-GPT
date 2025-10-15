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