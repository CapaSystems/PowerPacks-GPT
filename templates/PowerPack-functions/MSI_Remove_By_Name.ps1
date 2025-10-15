function MSI-Remove-By-Name {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$DisplayName,
		[Parameter(Mandatory = $false)]
		[string]$Version = $null,
		[Parameter(Mandatory = $false)]
		[string]$Codehandle = ''
	)
	$LogPreTag = 'MSI-Remove-By-Name:'

	try {
		$cs.Job_Writelog("$LogPreTag DisplayName: $($DisplayName) | Version: $($Version)")

		if ($DisplayName.Trim() -eq '*') {
      throw "$LogPreTag Error - DisplayName cannot be just a wildcard"
		}

		$RegPaths = @(
			'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
			'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
		)

		if ($global:Debug -ne $true) {
			$cs.Job_DisableLog()
		}

		foreach ($RegPath in $RegPaths) {
			$RegKeys = $cs.Reg_EnumKey('HKLM', $RegPath, $true)
			foreach ($Item in $RegKeys) {
				$cs.job_writelog("$LogPreTag Running for $($Item)")

				$RegDisplayName = $cs.Reg_GetString('hklm', "$RegPath\$Item", 'DisplayName')
				if ($RegDisplayName -notlike $DisplayName) {
					$cs.job_writelog("$LogPreTag Skipping $($Item) as DisplayName does not match")
					continue
				}

				$CheckForVersion = [string]::IsNullOrEmpty($Version) -eq $false
				$DisplayVersionExists = $cs.Reg_ExistVariable('hklm', "$RegPath\$Item", 'DisplayVersion')
				if ($DisplayVersionExists -eq $false -and $CheckForVersion) {
					$cs.job_writelog("$LogPreTag Skipping $($Item) as DisplayVersion does not exist")
					continue
				}

				if ($DisplayVersionExists) {
					$RegVersion = $cs.Reg_GetString('hklm', "$RegPath\$Item", 'DisplayVersion')
					if ($CheckForVersion) {
						# You cannot compare version numbers on empty strings, so we need the parent if statement
						if ([version]$RegVersion -ne [version]$Version) {
							$cs.job_writelog("$LogPreTag Skipping $($Item) as Version does not match")
							continue
						}
					}
				}

				if ($cs.Reg_ExistVariable('hklm', "$RegPath\$Item", 'UninstallString') -eq $false) {
					$cs.job_writelog("$LogPreTag Skipping $($Item) as UninstallString does not exist")
					continue
				}

				$UninstallString = $cs.Reg_GetString('hklm', "$RegPath\$Item", 'UninstallString')
				if ([string]::IsNullOrEmpty($UninstallString)) {
					$cs.job_writelog("$LogPreTag Skipping $($Item) as UninstallString is empty")
					continue
				} elseif ($UninstallString -notlike 'msiexec*') {
					$cs.job_writelog("$LogPreTag Skipping $($Item) as UninstallString does not start with msiexec")
					continue
				}

        $MsiLogFolder = $global:AppLogFolder

				if ([string]::IsNullOrEmpty($RegVersion)) {
					$RegVersion = 'NoVersion'
				}
				$msiLog = Join-Path $MsiLogFolder "$RegDisplayName.$($RegVersion)_Uninstall.log"

				$cs.Job_EnableLog()
				$cs.Job_Writelog("$LogPreTag Found MSI to uninstall: $($RegDisplayName) | Version: $($RegVersion)")
				$cs.job_writelog("$LogPreTag Uninstallating $($Item)")
				$ExitCode = $cs.Shell_Execute('msiexec', "/x $item /qn REBOOT=REALLYSUPPRESS /l*v `"$msiLog`"")
				$cs.Job_WriteLog("Uninstall of $item completed with status: $ExitCode")
				if (![string]::IsNullOrEmpty($Codehandle)) {
					$cs.Job_WriteLog("$LogPrefix A Codehandle has been specified with value: $Codehandle")

					$Codehandle = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Codehandle))
					$CodehandleObj = ConvertFrom-Json $Codehandle

					$ExistCode = $CodehandleObj | Where-Object { $_.code -eq $ExitCode }
					if ([string]::IsNullOrEmpty($ExistCode)) {
						$cs.Job_WriteLog("$LogPrefix The exit code $ExitCode is not in the list of handled codes")
						Exit-PSScript $ExitCode
					} else {
						$CodehandleId = $ExistCode.option.id

						$cs.Job_WriteLog("$LogPrefix The exit code $ExitCode is in the list of handled codes. Action to take: $CodehandleId")

						switch ($CodehandleId) {
							'success' {
								$cs.Job_WriteLog("$LogPrefix The installation was successful")
								return
							}
							'notcompliant' {
								$cs.Job_WriteLog("$LogPrefix The installation was not compliant")
								Exit-PSScript 3327
							}
							'failure' {
								$cs.Job_WriteLog("$LogPrefix The installation failed with exit code $ExitCode")
								Exit-PSScript $ExitCode
							}
							'retrylater' {
								$cs.Job_WriteLog("$LogPrefix The installation failed with exit code $ExitCode, but will be retried later")
								Exit-PSScript 3326
							}
							default {
								$cs.Job_WriteLog("$LogPrefix Option not handled: $CodehandleId")
								Exit-PSScript $ExitCode
							}
						}
					}
				} else {
					$cs.Job_WriteLog("$LogPrefix No Codehandle specified. Exit code: $ExitCode")

					if ($ExitCode -ne 0) {
						$cs.Job_WriteLog("$LogPrefix The installation failed with exit code $ExitCode")
						Exit-PSScript $ExitCode
					}
				}

				if ($global:Debug -ne $true) {
					$cs.Job_DisableLog()
				}
			}
		}
	} finally {
		$cs.Job_EnableLog()
	}
}