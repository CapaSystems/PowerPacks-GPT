function Registry-Create-Key {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
		[string]$Registry_Root,
		[Parameter(Mandatory=$false)]
		[string]$Registry_Key
	)
  $LogPreTag = 'Registry-Create-Key:'
  $cs.Job_Writelog("$LogPreTag Registry_Root: $($Registry_Root) | Registry_Key: $($Registry_Key)")

  if ($Registry_Key.StartsWith('\')) {
    $Registry_Key = $Registry_Key.Substring(1)
  }

	$cs.Reg_CreateKey($Registry_Root, $Registry_Key)
}
