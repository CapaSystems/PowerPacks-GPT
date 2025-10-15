function File_CopyToAllUsersProfiles {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$SourceFile,
		[Parameter(Mandatory = $true)]
		[string]$DestinationFile,
		[Parameter(Mandatory = $false)]
		[bool]$OverwriteFile
	)
	$LogPreTag = 'File_CopyToAllUsersProfiles:'

  if ($SourceFile.StartsWith('"')) {
    $SourceFile = $SourceFile.Substring(1)
  }
  if ($SourceFile.EndsWith('"')) {
    $SourceFile = $SourceFile.Substring(0, $SourceFile.Length - 1)
  }
  if ($DestinationFile.StartsWith('"')) {
    $DestinationFile = $DestinationFile.Substring(1)
  }
  if ($DestinationFile.EndsWith('"')) {
    $DestinationFile = $DestinationFile.Substring(0, $DestinationFile.Length - 1)
  }

	try {
		$cs.Job_WriteLog("$LogPreTag Building Array With All Users That Have Logged On To This Unit...")
		$RegKeys = $cs.Reg_EnumKey('HKLM', 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList', $true)

		# Convert from array to list and add DEFAULT user
		$UsersRegKey = @()
		$UsersRegKey += $RegKeys
		$UsersRegKey += 'DEFAULT'

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
				}
				default {
					$ProfileImagePath = $cs.Reg_GetExpandString('HKLM', "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$User", 'ProfileImagePath')
				}
			}

			$DestinationPath = Join-Path $ProfileImagePath $DestinationFile
			$cs.File_CopyFile($SourceFile, $DestinationPath, $OverwriteFile)

			$cs.Job_EnableLog()
		}
	} finally {
		$cs.Job_EnableLog()
	}
}
