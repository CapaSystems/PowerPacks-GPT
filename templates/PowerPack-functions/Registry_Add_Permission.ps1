function Registry_Add_Permission {
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('HKEY_CLASSES_ROOT', 'HKEY_LOCAL_MACHINE', 'HKEY_USERS', 'HKEY_CURRENT_CONFIG')]
		[string]$RegistryRoot,
		[Parameter(Mandatory = $false)]
		[string]$RegistryKey,
		[Parameter(Mandatory = $true)]
		[string]$Identity,
		[Parameter(Mandatory = $true)]
		[ValidateSet('QueryValues', 'SetValue', 'CreateSubKey', 'EnumerateSubKeys', 'Notify', 'CreateLink', 'Delete', 'ReadPermissions', 'WriteKey', 'ExecuteKey', 'ReadKey', 'ChangePermissions', 'TakeOwnership', 'FullControl')]
		[string]$Right,
		[Parameter(Mandatory = $false)]
		[bool]$ShouldPathExist = $true
	)
	$LogPreTag = 'Registry_Add_Permission:'
	$cs.Job_Writelog("$LogPreTag RegistryRoot: $($RegistryRoot) | RegistryKey: $($RegistryKey) | Identity: $($Identity) | Right: $($Right) | ShouldPathExist: $($ShouldPathExist)")

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
	#endregion

	#region Add rights
	$cs.Job_Writelog("$LogPreTag Creating Registry Access Rules")

	# This folder, sub-folders and files
	$propagationFlags = 'None'
	$inheritanceFlags = 'ContainerInherit,ObjectInherit'

	$registryAccessRuleArgumentList = $Identity, $Right, $inheritanceFlags, $propagationFlags, 'Allow'

	$newParams = @{
		TypeName     = 'System.Security.AccessControl.RegistryAccessRule'
		ArgumentList = $registryAccessRuleArgumentList
	}
	$registrySystemAccessRule = New-Object @newParams
	$cs.Job_Writelog("$LogPreTag DONE - Creating Registry Access Rules")

	if ($global:Debug) {
		$cs.Job_Writelog("$LogPreTag RegistryAccessRule - RegistryRights: $($registrySystemAccessRule.RegistryRights)")
		$cs.Job_Writelog("$LogPreTag RegistryAccessRule - AccessControlType: $($registrySystemAccessRule.AccessControlType)")
		$cs.Job_Writelog("$LogPreTag RegistryAccessRule - IdentityReference: $($registrySystemAccessRule.IdentityReference)")
		$cs.Job_Writelog("$LogPreTag RegistryAccessRule - InheritanceFlags: $($registrySystemAccessRule.InheritanceFlags)")
		$cs.Job_Writelog("$LogPreTag RegistryAccessRule - PropagationFlags: $($registrySystemAccessRule.PropagationFlags)")
	}
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

	$cs.Job_Writelog("$LogPreTag Adding setting to AclObject")
	$NewACL.AddAccessRule($registrySystemAccessRule)
	$cs.Job_Writelog("$LogPreTag DONE - Adding setting to AclObject")

	$cs.Job_Writelog("$LogPreTag Setting the new ACL settings")
	Set-Acl -Path $Path -AclObject $NewACL
	$cs.Job_Writelog("$LogPreTag New ACL settings set")
	#endregion
}