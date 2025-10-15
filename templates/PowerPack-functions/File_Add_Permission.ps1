function File_Add_Permission {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Path,
		[Parameter(Mandatory = $true)]
		[string]$Identity,
		[Parameter(Mandatory = $true)]
		#[ValidateSet('FullControl', 'Modify', 'Read', 'ReadAndExecute', 'ExecuteFile', 'Write', 'Delete')]
		[string]$Right,
		[Parameter(Mandatory = $false)]
		[bool]$ShouldPathExist = $true,
		[Parameter(Mandatory = $false)]
		[int]$InheritanceType = 0
	)
	$LogPreTag = 'File_Set_Permissions:'
	$cs.Job_Writelog("$LogPreTag Path: $($Path) | Identity: $($Identity) | Right: $($Right) | ShouldPathExist: $($ShouldPathExist) | InheritanceType: $($InheritanceType)")

  if ($Path.StartsWith('"')) {
    $Path = $Path.Substring(1)
  }
  if ($Path.EndsWith('"')) {
    $Path = $Path.Substring(0, $Path.Length - 1)
  }

	#region Precheck
	$ExistPath = Test-Path $Path
	if ($ShouldPathExist -and -not $ExistPath) {
		$cs.Job_Writelog("$LogPreTag Path: $($Path) does not exist")
		throw "$LogPreTag Path: $($Path) does not exist"
	}
	if ($ExistPath) {
		$cs.Job_Writelog("$LogPreTag Path: $($Path) exists")
	} else {
		$cs.Job_Writelog("$LogPreTag Path: $($Path) does not exist")
	}

	$ErrorActionPreference = 'SilentlyContinue'
	$IsSID = $false
	try {
		$sidObj = New-Object System.Security.Principal.SecurityIdentifier($Identity)
		$cs.Job_Writelog("$LogPreTag Identity: $($Identity) is a SID")
		$IsSID = $true
	} catch {
		$cs.Job_Writelog("$LogPreTag Identity: $($Identity) is not a  SID")
	}
	$ErrorActionPreference = 'Continue'

	if ($IsSID) {
		$cs.Job_Writelog("$LogPreTag Identity: $($Identity) is a SID - trying to translate to NTAccount")
    try {
      $Identity = $sidObj.Translate([System.Security.Principal.NTAccount]).Value
      $cs.Job_Writelog("$LogPreTag Identity: $($Identity)")
    } catch {
      $cs.Job_Writelog("$LogPreTag Error: Could not translate SID $($Identity) to NTAccount")
      throw "$LogPreTag Error: Could not translate SID $($Identity) to NTAccount - $_"
    }
  } else {
    # Validate that the identity exists
    $ErrorActionPreference = 'SilentlyContinue'
    try {
      $ntAccount = New-Object System.Security.Principal.NTAccount($Identity)
      $testSid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
      $cs.Job_Writelog("$LogPreTag Identity: $($Identity) is valid")
    } catch {
      $cs.Job_Writelog("$LogPreTag Error: Identity $($Identity) does not exist or cannot be resolved")
      $ErrorActionPreference = 'Continue'
      throw "$LogPreTag Error: Identity $($Identity) does not exist or cannot be resolved - $_"
    }
    $ErrorActionPreference = 'Continue'
	}

	$IsAFile = Test-Path $Path -PathType Leaf
	$cs.Job_Writelog("$LogPreTag IsAFile: $($IsAFile)")
	if ($IsAFile -and $InheritanceType -ne 0) {
		$cs.Job_Writelog("$LogPreTag InheritanceType: $($InheritanceType) is not supported for files")
		$InheritanceType = 0
	}
	#endregion

	#region Add rights
	$cs.Job_Writelog("$LogPreTag Creating File System Access Rules")

	switch ($InheritanceType) {
		0 {
			# This folder only
			$propagationFlags = 'None'
			$inheritanceFlags = 'None'

		}
		1 {
			# This folder, sub-folders and files
			$propagationFlags = 'None'
			$inheritanceFlags = 'ContainerInherit,ObjectInherit'
		}
		2 {
			# This folder and sub-folders
			$propagationFlags = 'None'
			$inheritanceFlags = 'ContainerInherit'
		}
		3 {
			# This folder and files
			$propagationFlags = 'None'
			$inheritanceFlags = 'ObjectInherit'
		}
		4 {
			# Sub-folders and files only
			$propagationFlags = 'InheritOnly'
			$inheritanceFlags = 'ContainerInherit,ObjectInherit'
		}
		5 {
			# Sub-folders only
			$propagationFlags = 'InheritOnly'
			$inheritanceFlags = 'ContainerInherit'
		}
		6 {
			# Files only
			$propagationFlags = 'InheritOnly'
			$inheritanceFlags = 'ObjectInherit'
		}
		default {
			throw "$LogPreTag InheritanceType: $($InheritanceType) is not supported."
		}
	}

	$cs.Job_Writelog("$LogPreTag propagationFlags: $($propagationFlags)")
	$cs.Job_Writelog("$LogPreTag inheritanceFlags: $($inheritanceFlags)")

	$fileSystemAccessRuleArgumentList = $Identity, $Right, $inheritanceFlags, $propagationFlags, 'Allow'

	$newParams = @{
		TypeName     = 'System.Security.AccessControl.FileSystemAccessRule'
		ArgumentList = $fileSystemAccessRuleArgumentList
	}
	$fileSystemAccessRule = New-Object @newParams
	$cs.Job_Writelog("$LogPreTag DONE - Creating File System Access Rules")

	if ($global:Debug) {
		$cs.Job_Writelog("$LogPreTag FileSystemAccessRule - AccessControlType: $($fileSystemAccessRule.AccessControlType)")
		$cs.Job_Writelog("$LogPreTag FileSystemAccessRule - FileSystemRights: $($fileSystemAccessRule.FileSystemRights)")
		$cs.Job_Writelog("$LogPreTag FileSystemAccessRule - IdentityReference: $($fileSystemAccessRule.IdentityReference)")
		$cs.Job_Writelog("$LogPreTag FileSystemAccessRule - InheritanceFlags: $($fileSystemAccessRule.InheritanceFlags)")
		$cs.Job_Writelog("$LogPreTag FileSystemAccessRule - IsInherited: $($fileSystemAccessRule.IsInherited)")
		$cs.Job_Writelog("$LogPreTag FileSystemAccessRule - PropagationFlags: $($fileSystemAccessRule.PropagationFlags)")
	}

	$cs.Job_Writelog("$LogPreTag Getting ACL for path: $($Path)")
	#$NewACL = Get-Acl -Path $Path

	$jsonResult = & powershell.exe -NoProfile -Command "
`$acl = Get-Acl -Path `"$Path`"
`$acl.Access | ForEach-Object {
	[PSCustomObject]@{
		FileSystemRights  = `$_.FileSystemRights
		AccessControlType = `$_.AccessControlType
		IdentityReference = `$_.IdentityReference.Value
		IsInherited       = `$_.IsInherited
		InheritanceFlags  = `$_.InheritanceFlags
		PropagationFlags  = `$_.PropagationFlags
	}
} | ConvertTo-Json -Depth 3
"
	$TempNewACL = $jsonResult | ConvertFrom-Json

	if ($Global:Debug) {
		$cs.Job_Writelog("$LogPreTag JSON ACL entries for $($Path): $($TempNewACL.Count)")
		foreach ($AccessRule in $TempNewACL) {
			$cs.Job_Writelog("$LogPreTag JSON ACL Entry: IdentityReference: $($AccessRule.IdentityReference) | AccessControlType: $($AccessRule.AccessControlType) | FileSystemRights: $($AccessRule.FileSystemRights)")
		}
	}

	if (Test-Path -PathType Leaf $Path) {
		$NewACL = New-Object System.Security.AccessControl.FileSecurity

		if ($Global:Debug) {
			$cs.Job_Writelog("$LogPreTag Created new FileSecurity object for $($Path)")
		}
	} else {
		$NewACL = New-Object System.Security.AccessControl.DirectorySecurity

		if ($Global:Debug) {
			$cs.Job_Writelog("$LogPreTag Created new DirectorySecurity object for $($Path)")
		}
	}

	$ErrorActionPreference = 'SilentlyContinue'
	foreach ($AccessRule in $TempNewACL) {
		$TempFileSystemAccessRule = $null

		if ($Global:Debug) {
			$cs.Job_Writelog("$LogPreTag Creating FileSystemAccessRule for Identity: $($AccessRule.IdentityReference) | AccessControlType: $($AccessRule.AccessControlType) | FileSystemRights: $($AccessRule.FileSystemRights)")
		}

		try {
			$TempFileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
				$AccessRule.IdentityReference,
				$AccessRule.FileSystemRights,
				$AccessRule.InheritanceFlags,
				$AccessRule.PropagationFlags,
				$AccessRule.AccessControlType
			)
			$NewACL.AddAccessRule($TempFileSystemAccessRule)
		} catch {
			if ($Global:Debug) {
				$cs.Job_Writelog("$LogPreTag Error creating FileSystemAccessRule for Identity: $($AccessRule.IdentityReference) - $_")
			}
		}
	}
	$ErrorActionPreference = 'Continue'


	$NewACLAccess = $NewACL.GetAccessRules($true, $true, [System.Security.Principal.NTAccount])

	if ($Global:Debug) {
		$cs.Job_Writelog("$LogPreTag Total ACL entries for $($Path): $($NewACL.Count)")
		$cs.Job_Writelog("$LogPreTag Total ACL access entries for $($Path): $($NewACLAccess.Count)")

		foreach ($AccessRule in $NewACLAccess) {
			$cs.Job_Writelog("$LogPreTag ACL Entry: FileSystemRights: $($AccessRule.FileSystemRights) | AccessControlType: $($AccessRule.AccessControlType) | IdentityReference: $($AccessRule.IdentityReference) | IsInherited: $($AccessRule.IsInherited) | InheritanceFlags: $($AccessRule.InheritanceFlags) | PropagationFlags: $($AccessRule.PropagationFlags)")
		}
	}

	$cs.Job_Writelog("$LogPreTag Adding setting to AclObject")
	$NewACL.AddAccessRule($FileSystemAccessRule)
	$cs.Job_Writelog("$LogPreTag DONE - Adding setting to AclObject")

	$cs.Job_Writelog("$LogPreTag Setting the new ACL settings")
	Set-Acl -Path $Path -AclObject $NewACL
	$cs.Job_Writelog("$LogPreTag New ACL settings set")
	#endregion
}