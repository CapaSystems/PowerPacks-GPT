Function System-Wait-For-Process-To-End {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$Process_Name,
		[Parameter(Mandatory = $false)]
		[int]$MaxTimeOut,
		[Parameter(Mandatory = $false)]
		[int]$CheckInterval
	)

	$cs.Sys_WaitForProcess($Process_Name, $MaxTimeOut, $CheckInterval)
}
