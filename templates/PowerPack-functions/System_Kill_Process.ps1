Function System-Kill-Process {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$Process_Name
	)

	$cs.sys_killprocess($Process_Name)
}