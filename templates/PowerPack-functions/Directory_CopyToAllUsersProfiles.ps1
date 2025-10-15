function Directory_CopyToAllUsersProfiles {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$SourceDirectory,
		[Parameter(Mandatory = $true)]
		[string]$DestinationDirectory,
		[Parameter(Mandatory = $false)]
		[bool]$IncludeSubDirectories = $true,
		[Parameter(Mandatory = $false)]
		[bool]$OverwriteFile
	)
	$LogPreTag = "Directory_CopyToAllUsersProfiles"

  if ($SourceDirectory.StartsWith('"')) {
    $SourceDirectory = $SourceDirectory.Substring(1)
  }
  if ($SourceDirectory.EndsWith('"')) {
    $SourceDirectory = $SourceDirectory.Substring(0, $SourceDirectory.Length - 1)
  }
  if ($DestinationDirectory.StartsWith('"')) {
    $DestinationDirectory = $DestinationDirectory.Substring(1)
  }
  if ($DestinationDirectory.EndsWith('"')) {
    $DestinationDirectory = $DestinationDirectory.Substring(0, $DestinationDirectory.Length - 1)
  }

	if (-not (Test-Path -Path $SourceDirectory)) {
		throw "SourceDirectory '$SourceDirectory' does not exist."
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

			$DestinationPath = Join-Path $ProfileImagePath $DestinationDirectory
			$cs.File_CopyTree($SourceDirectory, $DestinationPath, $IncludeSubDirectories, $OverwriteFile)

			$cs.Job_EnableLog()
		}
	} finally {
		$cs.Job_EnableLog()
	}
}
