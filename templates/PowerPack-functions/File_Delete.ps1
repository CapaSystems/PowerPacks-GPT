Function File-Delete {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$File_Path,
		[Parameter(Mandatory = $false)]
		[bool]$SearchSubFolders
	)
  $LogPreTag = 'File_Delete:'
  $cs.Job_Writelog("$LogPreTag File_Path: $($File_Path) | SearchSubFolders: $($SearchSubFolders)")

  if ($File_Path.StartsWith('"')) {
    $File_Path = $File_Path.Substring(1)
  }
  if ($File_Path.EndsWith('"')) {
    $File_Path = $File_Path.Substring(0, $File_Path.Length - 1)
  }

	$cs.File_DelFile($File_Path, $SearchSubFolders)
}
