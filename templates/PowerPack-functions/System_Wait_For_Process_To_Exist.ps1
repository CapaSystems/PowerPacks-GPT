Function System-Wait-For-Process-To-Exist {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$Process_Name,
		[Parameter(Mandatory = $false)]
		[int]$MaxTimeOut,
		[Parameter(Mandatory = $false)]
		[int]$CheckInterval
	)

	$cs.Sys_WaitForProcessToExist($Process_Name, $MaxTimeOut, $CheckInterval)
}
