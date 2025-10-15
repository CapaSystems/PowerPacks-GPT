function Registry_Remove_Permission {
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('HKEY_CLASSES_ROOT', 'HKEY_LOCAL_MACHINE', 'HKEY_USERS', 'HKEY_CURRENT_CONFIG')]
		[string]$RegistryRoot,
		[Parameter(Mandatory = $false)]
		[string]$RegistryKey,
		[Parameter(Mandatory = $true)]
		[string]$Identity,
		[Parameter(Mandatory = $false)]
		[bool]$ShouldPathExist = $false
	)
	$LogPreTag = 'Registry_Remove_Permission:'
	$cs.Job_Writelog("$LogPreTag RegistryRoot: $($RegistryRoot) | RegistryKey: $($RegistryKey) | Identity: $($Identity) | ShouldPathExist: $($ShouldPathExist)")

  if ($RegistryKey.StartsWith('\')) {
    $RegistryKey = $RegistryKey.Substring(1)
  }

	#region Precheck
	$Path = "Registry::$RegistryRoot\$RegistryKey"
	$cs.Job_Writelog("$LogPreTag Path: $($Path)")

	$ExistPath = (Get-Item -Path $Path -ErrorAction SilentlyContinue) -ne $null
	if ($ShouldPathExist -and -not $ExistPath) {
		$cs.Job_Writelog("$LogPreTag Path: $($Path) does not exist")
		throw "$LogPreTag Path: $($Path) does not exist"
	}
	if ($ExistPath) {
		$cs.Job_Writelog("$LogPreTag Path: $($Path) exists")
	} else {
		$cs.Job_Writelog("$LogPreTag Path: $($Path) does not exist")
		return
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
		$Identity = $sidObj.Translate([System.Security.Principal.NTAccount]).Value
		$cs.Job_Writelog("$LogPreTag Identity: $($Identity)")
	}
	#endregion

	#region Remove rights
	$cs.Job_Writelog("$LogPreTag Getting ACL for path: $($Path)")
	#$NewACL = Get-Acl -Path $Path

	$jsonResult = & powershell.exe -NoProfile -Command "
`$acl = Get-Acl -Path `"$Path`"
`$acl.Access | ForEach-Object {
	[PSCustomObject]@{
		RegistryRights  = `$_.RegistryRights
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
			$cs.Job_Writelog("$LogPreTag JSON ACL Entry: IdentityReference: $($AccessRule.IdentityReference) | AccessControlType: $($AccessRule.AccessControlType) | RegistryRights: $($AccessRule.RegistryRights)")
		}
	}

	$NewACL = New-Object System.Security.AccessControl.RegistrySecurity
	if ($Global:Debug) {
		$cs.Job_Writelog("$LogPreTag Created new RegistrySecurity object for $($Path)")
	}

	$ErrorActionPreference = 'SilentlyContinue'
	foreach ($AccessRule in $TempNewACL) {
		$TempRegistryAccessRule = $null

		if ($Global:Debug) {
			$cs.Job_Writelog("$LogPreTag Creating RegistryAccessRule for Identity: $($AccessRule.IdentityReference) | AccessControlType: $($AccessRule.AccessControlType) | RegistryRights: $($AccessRule.RegistryRights)")
		}

		try {
			$TempRegistryAccessRule = New-Object System.Security.AccessControl.RegistryAccessRule(
				$AccessRule.IdentityReference,
				$AccessRule.RegistryRights,
				$AccessRule.InheritanceFlags,
				$AccessRule.PropagationFlags,
				$AccessRule.AccessControlType
			)
			$NewACL.AddAccessRule($TempRegistryAccessRule)
		} catch {
			if ($Global:Debug) {
				$cs.Job_Writelog("$LogPreTag Error creating RegistryAccessRule for Identity: $($AccessRule.IdentityReference) - $_")
			}
		}
	}
	$ErrorActionPreference = 'Continue'


	$NewACLAccess = $NewACL.GetAccessRules($true, $true, [System.Security.Principal.NTAccount])

	if ($Global:Debug) {
		$cs.Job_Writelog("$LogPreTag Total ACL entries for $($Path): $($NewACL.Count)")
		$cs.Job_Writelog("$LogPreTag Total ACL access entries for $($Path): $($NewACLAccess.Count)")

		foreach ($AccessRule in $NewACLAccess) {
			$cs.Job_Writelog("$LogPreTag ACL Entry: RegistryRights: $($AccessRule.RegistryRights) | AccessControlType: $($AccessRule.AccessControlType) | IdentityReference: $($AccessRule.IdentityReference) | IsInherited: $($AccessRule.IsInherited) | InheritanceFlags: $($AccessRule.InheritanceFlags) | PropagationFlags: $($AccessRule.PropagationFlags)")
		}
	}

	$ThingsToRemove = $NewACLAccess | Where-Object { $_.IdentityReference -like "*$Identity" }
	$RemoveCount = $ThingsToRemove.Count
	$cs.Job_Writelog("$LogPreTag Found $RemoveCount ACL entries for $($Identity)")

  if ($Identity.StartsWith($env:COMPUTERNAME) -and $RemoveCount -eq 0) {
    $TempIdentity = $Identity.Replace("$env:COMPUTERNAME\", 'BUILTIN\')
    $ThingsToRemove = $NewACLAccess | Where-Object { $_.IdentityReference -like "*$TempIdentity" }
    $RemoveCount = $ThingsToRemove.Count
    $cs.Job_Writelog("$LogPreTag Found $RemoveCount ACL entries for $($TempIdentity)")
  }
	if ($RemoveCount -eq 0) {
		$cs.Job_Writelog("$LogPreTag No ACL entries found for $($Identity)")
		return
	}

	$Count = 0
	foreach ($FileSystemAccessRule in $ThingsToRemove) {
		$Count++
		$cs.Job_Writelog("$LogPreTag Removing setting $($Count) of $($RemoveCount) from AclObject | IdentityReference: $($FileSystemAccessRule.IdentityReference) | AccessControlType: $($FileSystemAccessRule.AccessControlType) | RegistryRights: $($FileSystemAccessRule.RegistryRights)")
		$NewACL.RemoveAccessRule($FileSystemAccessRule)
	}
	$cs.Job_Writelog("$LogPreTag DONE - Removing setting from AclObject")

	$cs.Job_Writelog("$LogPreTag Setting the new ACL settings")
	Set-Acl -Path $Path -AclObject $NewACL
	$cs.Job_Writelog("$LogPreTag New ACL settings set")
	#endregion
}