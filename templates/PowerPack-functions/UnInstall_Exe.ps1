Function Install-Exe {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$ProcessPath,
		[Parameter(Mandatory = $false)]
		[string]$ProcessArguments,
		[Parameter(Mandatory = $false)]
		[string]$WorkingDirectory,
		[Parameter(Mandatory = $true)]
		[bool]$ProcessWait,
		[Parameter(Mandatory = $true)]
		[string]$WindowStyle,
		[Parameter(Mandatory = $true)]
		[bool]$CheckProcessExist,
		[Parameter(Mandatory = $false)]
		[string]$Codehandle = ''
	)
  $LogPreTag = 'UnInstall-Exe:'
  $cs.Job_Writelog("$LogPreTag ProcessPath: $($ProcessPath) | ProcessArguments: $($ProcessArguments) | WorkingDirectory: $($WorkingDirectory) | ProcessWait: $($ProcessWait) | WindowStyle: $($WindowStyle) | CheckProcessExist: $($CheckProcessExist)")

  if ($ProcessPath.StartsWith('"')) {
    $ProcessPath = $ProcessPath.Substring(1)
  }
  if ($ProcessPath.EndsWith('"')) {
    $ProcessPath = $ProcessPath.Substring(0, $ProcessPath.Length - 1)
  }
  if ($WorkingDirectory.StartsWith('"')) {
    $WorkingDirectory = $WorkingDirectory.Substring(1)
  }
  if ($WorkingDirectory.EndsWith('"')) {
    $WorkingDirectory = $WorkingDirectory.Substring(0, $WorkingDirectory.Length - 1)
  }

	$ExitCode = $cs.Shell_Execute($ProcessPath, $ProcessArguments, $ProcessWait, $WindowStyle, $CheckProcessExist, $WorkingDirectory)
	$cs.Job_WriteLog("$LogPrefix The installation of $ProcessPath returned: $ExitCode")

	if ([string]::IsNullOrEmpty($Codehandle) -eq $false) {
		$cs.Job_WriteLog("$LogPrefix A Codehandle has been specified with value: $Codehandle")

		$Codehandle =  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Codehandle))
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
}
