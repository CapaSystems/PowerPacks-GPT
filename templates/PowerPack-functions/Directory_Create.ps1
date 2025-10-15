Function Directory-Create {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$Directory_Path
	)
  $LogPreTag = 'Directory_Create:'
  $cs.Job_Writelog("$LogPreTag Directory_Path: $($Directory_Path)")

  if ($Directory_Path.StartsWith('"')) {
    $Directory_Path = $Directory_Path.Substring(1)
  }
  if ($Directory_Path.EndsWith('"')) {
    $Directory_Path = $Directory_Path.Substring(0, $Directory_Path.Length - 1)
  }

	$cs.File_CreateDir($Directory_Path)
}
