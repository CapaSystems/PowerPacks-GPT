function PowerPack-Download {
	if ($InputObject) {
		Start-PSDownloadPackage

		if (($Packageroot -notmatch 'kit') -and (Test-Path -Path "${Packageroot}\Kit" -PathType Container)) {
			$global:Packageroot = $global:Packageroot + '\Kit'
			$cs.Job_WriteLog("`$Packageroot changed to $($global:Packageroot)")
		}
	}
}