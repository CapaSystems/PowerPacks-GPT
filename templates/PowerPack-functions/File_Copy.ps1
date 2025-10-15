Function File-Copy {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$Source_File,
		[Parameter(Mandatory = $true)]
		[string]$Destination_File,
		[Parameter(Mandatory = $false)]
		[bool]$Overwrite_File
	)
  $LogPreTag = 'File_Copy:'
  $cs.Job_Writelog("$LogPreTag Source_File: $($Source_File) | Destination_File: $($Destination_File) | Overwrite_File: $($Overwrite_File)")

  if ($Source_File.StartsWith('"')) {
    $Source_File = $Source_File.Substring(1)
  }
  if ($Source_File.EndsWith('"')) {
    $Source_File = $Source_File.Substring(0, $Source_File.Length - 1)
  }
  if ($Destination_File.StartsWith('"')) {
    $Destination_File = $Destination_File.Substring(1)
  }
  if ($Destination_File.EndsWith('"')) {
    $Destination_File = $Destination_File.Substring(0, $Destination_File.Length - 1)
  }

	$cs.File_CopyFile($Source_File, $Destination_File, $Overwrite_File)
}
