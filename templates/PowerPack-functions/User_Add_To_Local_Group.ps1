Function User_Add_To_Local_Group {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$Username,
		[Parameter(Mandatory = $false)]
		[string]$Group
	)

	$cs.UsrMgr_AddUserToLocalGroup($Username, $Group)
}
