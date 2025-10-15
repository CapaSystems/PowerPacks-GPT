Function Directory-Copy {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$SourceDirectory,
		[Parameter(Mandatory = $true)]
		[string]$DestinationDirectory,
		[Parameter(Mandatory = $false)]
		[bool]$IncludeSubDirectories,
		[Parameter(Mandatory = $false)]
		[bool]$OverwriteFile
	)
  $LogPreTag = 'Directory_Copy:'
  $cs.Job_Writelog("$LogPreTag SourceDirectory: $($SourceDirectory) | DestinationDirectory: $($DestinationDirectory) | IncludeSubDirectories: $($IncludeSubDirectories) | OverwriteFile: $($OverwriteFile)")

  if ($SourceDirectory.StartsWith('"')) {
    $SourceDirectory = $SourceDirectory.Substring(1)
  }
  if ($SourceDirectory.EndsWith('"')) {
    $SourceDirectory = $SourceDirectory.Substring(0, $SourceDirectory.Length - 1)
  }

  if ($DestinationDirectory.StartsWith('"')) {
    $DestinationDirectory = $DestinationDirectory.Substring(1)
  }
  if ($DestinationDirectory.EndsWith('"')) {
    $DestinationDirectory = $DestinationDirectory.Substring(0, $DestinationDirectory.Length - 1)
  }

	$cs.File_CopyTree($SourceDirectory, $DestinationDirectory, $IncludeSubDirectories, $OverwriteFile)
}
