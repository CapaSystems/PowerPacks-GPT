Function Windows_Service_Stop {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$ServiceName,
		[Parameter(Mandatory = $false)]
		[int]$MaxTimeOut
	)

	$cs.Service_Stop($ServiceName, $MaxTimeOut * 1000)
}