Function Windows_Service_Start {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$Service_Name,
		[Parameter(Mandatory = $false)]
		[int]$MaxTimeOut
	)

	$cs.Service_Start($Service_Name, $MaxTimeOut * 1000)
}