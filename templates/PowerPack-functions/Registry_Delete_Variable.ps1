Function Registry-Delete-Variable {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$Registry_Root,
		[Parameter(Mandatory = $false)]
		[string]$Registry_Key,
		[Parameter(Mandatory = $false)]
		[string]$Registry_Value_Name
	)
	$LogPreTag = 'Registry-Delete-Variable:'
	$cs.Job_WriteLog("$LogPreTag Calling function with: Registry_Root: $Registry_Root | Registry_Key: $Registry_Key | Registry_Value_Name: $Registry_Value_Name")

  if ($Registry_Key.StartsWith('\')) {
    $Registry_Key = $Registry_Key.Substring(1)
  }

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
					$cs.Reg_DeleteVariable($Temp_Registry_Root, $RegKeyPathTemp, $Registry_Value_Name)

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
			$cs.Reg_DeleteVariable($Registry_Root, $Registry_Key, $Registry_Value_Name)
		}
	}

	$cs.Job_EnableLog()
}
