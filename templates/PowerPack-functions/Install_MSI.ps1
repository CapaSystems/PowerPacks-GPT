function Install-Msi {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
		[string]$msiFilePath,
		[Parameter(Mandatory=$false)]
		[string]$msiArgs,
		[Parameter(Mandatory = $false)]
		[string]$Codehandle = ''
	)
	$LogPrefix = 'Install-Msi:'

  if ($msiFilePath.StartsWith('"')) {
    $msiFilePath = $msiFilePath.Substring(1)
  }
  if ($msiFilePath.EndsWith('"')) {
    $msiFilePath = $msiFilePath.Substring(0, $msiFilePath.Length - 1)
  }

	$cs.Job_WriteLog("$LogPrefix msiFilePath: $msiFilePath, msiArgs: $msiArgs")

  $MsiLogFolder = $global:AppLogFolder
  $cs.File_CreateDir($MsiLogFolder)
  $msiFile = Split-Path $msiFilePath -Leaf
  $msiLog = $MsiLogFolder + '\' + $msiFile + '_install.log'

  if ($msiArgs -notmatch '(?i)/l\*') {
    $msiArgs = $msiArgs + " /l*v `"$msiLog`""
  }

  $ExitCode = $cs.Shell_Execute('msiexec', "/i `"$msiFilePath`" $msiArgs")
	$cs.Job_WriteLog("$LogPrefix MSI file '$msiFilePath' installation completed with: $ExitCode")

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
