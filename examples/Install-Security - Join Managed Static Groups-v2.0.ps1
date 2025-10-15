[CmdletBinding()]
Param(
	[Parameter(Mandatory = $true)]
	[string]$Packageroot,
	[Parameter(Mandatory = $true)]
	[string]$AppName,
	[Parameter(Mandatory = $true)]
	[string]$AppRelease,
	[Parameter(Mandatory = $true)]
	[string]$LogFile,
	[Parameter(Mandatory = $true)]
	[string]$TempFolder,
	[Parameter(Mandatory = $true)]
	[string]$DllPath,
	[Parameter(Mandatory = $false)]
	[Object]$InputObject = $null
)
###################
#### VARIABLES ####
###################

# Building groups variables
$global:UseBuildingGroups = $true # Set to $true if you want to create groups called "- BUILDING" at the end
$global:BuildingRegKey = 'SOFTWARE\CapaSystems\Custom'
$global:BuildingRegVariable = 'JoinBuildingGroup'
$global:UnjoinBuildingGroupPackage = 'OS Install - Unjoin Build Groups' # Name of the package to run after joining building groups
$global:UnjoinBuildingGroupPackageVer = 'v2.0' # Version of the package to run after joining building groups

# CCSWebservice variables used to create groups in folders
$global:URI = 'https://MRACAPA02.capainstaller.com/CCSWEBSERVICE/CCS.asmx' # Set URL to "" if you don't want to use CCSWebservice
$global:CCSUserName = 'svc_capawebservice@FirmaX.Local'
$global:DecryptionKey = @(34, 232, 106, 150, 116, 76, 123, 15, 219, 17, 54, 179, 248, 58, 105, 168, 213, 23, 18, 181, 250, 26, 173, 2, 0, 37, 136, 218, 225, 108, 28, 192)
$global:CCSEncPassword = '76492d1116743f0423413b16050a5345MgB8AFYAVwA2AHAANgBlAFkAZAB0AEkAYwBpAEgAUwA0ADMAVgBYADgQB5AFEAPQA9AHwAYwBhADEAZAA5AGMAYwBiADYAYgBmADQAZgBmADAANQA5ADUAYgA2ADIANQAyAGIAMQAxADMANAA5ADAAYgBlAGQAMgA2ADEAMwBhADcANgBhADEAZAA5ADIANgAyADEAOQAyAGEAZgA5AGMAZQBlADEAZQAxADQAZABlADUAZAA='

# DO NOT CHANGE THESE VARIABLES
$global:Packageroot = $Packageroot
$global:AppName = $AppName
$global:AppRelease = $AppRelease
$global:LogFile = $LogFile
$global:TempFolder = $TempFolder
$global:DllPath = $DllPath
$global:InputObject = $InputObject
[bool]$global:DownloadPackage = $false # Set to $true if you want to download the kit folder from the server

$global:ScriptError = $Error

###################
#### FUNCTIONS ####
###################
function PreInstall {
	$cs.Log_SectionHeader('PreInstall', 'o')

	if ($global:UseBuildingGroups) {
		if ($cs.Reg_ExistVariable('HKLM', $global:BuildingRegKey, $global:BuildingRegVariable)) {
			$Global:HaveNotBeenInBuilding = $false
			$cs.Job_WriteLog('HaveNotBeenInBuilding = false')
		} else {
			$Global:HaveNotBeenInBuilding = $true
			$cs.Job_WriteLog('HaveNotBeenInBuilding = true')
		}
	}

	$global:UnitGroups = CMS_GetGroupMembership

	# Decrypt password
	$SecureString = $global:CCSEncPassword | ConvertTo-SecureString -Key $global:DecryptionKey
	$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
	$global:UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

function CapaInstaller_AddUnitToStaticGroup {
	param (
		[Parameter(Mandatory = $true)]
		[string]$ComputerName,
		[Parameter(Mandatory = $true)]
		[string]$GroupName,
		[Parameter(Mandatory = $false)]
		[string]$DESC2Value = '',
		[Parameter(Mandatory = $false)]
		[string]$BusinessUnitName = '',
		[Parameter(Mandatory = $false)]
		[string]$FolderStructure = '',
		[Parameter(Mandatory = $true)]
		[string]$CCSWebserviceUrl,
		[Parameter(Mandatory = $true)]
		[string]$CCSWebserviceUserName,
		[Parameter(Mandatory = $true)]
		[string]$CCSWebservicePassword,
		[Parameter(Mandatory = $false)]
		[bool]$AllowFallbackToCMSFunction = $true
	)
	$LogPrefix = 'CapaInstaller_AddUnitToStaticGroup :'

	if ($cs) {
		$cs.Job_WriteLog("$LogPrefix Adding computer to group: $GroupName")
	}

	# Basic Authentication header
	$pair = "$($global:CCSUserName):$($global:UnsecurePassword)"
	$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

	# Define SOAP-XML request
	$soapTemplate = @'
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <CapaInstaller_AddUnitToStaticGroup xmlns="http://CCSWebservice.dk/CCS">
      <ComputerName>{0}</ComputerName>
      <GroupName>{1}</GroupName>
      <DESC2Value>{2}</DESC2Value>
      <BusinessUnitName>{3}</BusinessUnitName>
      <FolderStructure>{4}</FolderStructure>
    </CapaInstaller_AddUnitToStaticGroup>
  </soap12:Body>
</soap12:Envelope>
'@

	# Replace placeholders in the SOAP-XML request
	$body = @{
		ComputerName     = $ComputerName
		GroupName        = $GroupName
		DESC2Value       = $DESC2Value
		BusinessUnitName = $BusinessUnitName
		FolderStructure  = $FolderStructure
	}

	# Create the SOAP-XML request
	$soapXml = $soapTemplate -f $body.ComputerName, $body.GroupName, $body.DESC2Value, $body.BusinessUnitName, $body.FolderStructure

	# Define headers
	$headers = @{
		'Content-Type'  = 'application/soap+xml; charset=utf-8'
		'Authorization' = "Basic $base64AuthInfo"
	}

	# Send the SOAP-XML request
	try {
		$response = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $soapXml

		if ($cs) {
			$cs.Job_WriteLog("$LogPrefix StatusDescription: $($response.StatusDescription)")
			$cs.Job_WriteLog("$LogPrefix StatusCode: $($response.StatusCode)")
		}
		if ($response.StatusDescription -ne 'OK' -and $AllowFallbackToCMSFunction) {
			if ($cs) {
				$cs.Job_WriteLog("$LogPrefix Fallback to CMS function")
			}
			CMS_AddComputerToStaticGroup -group $GroupName
		} else {
			if ($cs) {
				$cs.Job_WriteLog("$LogPrefix Computer added to group: $GroupName")
			}
		}
	} catch {
		if ($cs) {
			$cs.Job_WriteLog("$LogPrefix Error: $_")
		}
		if ($AllowFallbackToCMSFunction) {
			if ($cs) {
				$cs.Job_WriteLog("$LogPrefix Fallback to CMS function")
			}
			CMS_AddComputerToStaticGroup -group $GroupName
		} else {
			throw $_
		}
	}
}

function Join-StaticGroup {
	param (
		[Parameter(Mandatory = $false)]
		[string]$Prefix,
		[Parameter(Mandatory = $false)]
		[string]$Name = $null,
		[Parameter(Mandatory = $false)]
		[bool]$AddBuilding = $false,
		[Parameter(Mandatory = $false)]
		[string]$FolderStructure = $null
	)
	$LogPrefix = 'Join-StaticGroup :'

	if ([string]::IsNullOrEmpty($Name)) {
		$Name = 'UNKNOWN'
	}

	if ([string]::IsNullOrEmpty($Prefix)) {
		$GroupName = $Name
	} else {
		$GroupName = "$Prefix $Name"
	}

	# If comma exist it will be joining two groups
	$GroupName = $GroupName -replace ',', '.'

	if ($global:UnitGroups.Name -contains $GroupName) {
		$cs.Job_WriteLog("$LogPrefix Already in group: $GroupName")
	} else {
		$GroupsToUnjoin = $global:UnitGroups | Where-Object { $_.Name -like "$Prefix *" }

		foreach ($Group in $GroupsToUnjoin) {
			$cs.Job_WriteLog("$LogPrefix Unjoining group: $($Group.Name)")
			CMS_RemoveComputerFromStaticGroup -group $Group.Name
		}

		if ([string]::IsNullOrEmpty($global:URI)) {
			CMS_AddComputerToStaticGroup -group $GroupName
		} else {
			$Splatting = @{
				ComputerName          = $global:gsWorkstationName
				GroupName             = $GroupName
				CCSWebserviceUrl      = $global:URI
				CCSWebserviceUserName = $global:CCSUserName
				CCSWebservicePassword = $global:UnsecurePassword
				FolderStructure       = $FolderStructure
			}
			CapaInstaller_AddUnitToStaticGroup @Splatting
		}

		if ($AddBuilding -and $Global:HaveNotBeenInBuilding -and $global:UseBuildingGroups) {
			$BuildingGroupName = "$GroupName - BUILDING"

			if ([string]::IsNullOrEmpty($global:URI)) {
				CMS_AddComputerToStaticGroup -group $BuildingGroupName
			} else {
				$Splatting = @{
					ComputerName          = $global:gsWorkstationName
					GroupName             = $BuildingGroupName
					CCSWebserviceUrl      = $global:URI
					CCSWebserviceUserName = $global:CCSUserName
					CCSWebservicePassword = $global:UnsecurePassword
					FolderStructure       = $FolderStructure
				}
				CapaInstaller_AddUnitToStaticGroup @Splatting
			}
		}
	}
}

function Install {
	$cs.Log_SectionHeader('Install', 'o')

	#region Get data
	$MachineType = $cs.Reg_GetString('HKLM', 'Software\CapaSystems\CapaInstaller\OSD', 'MachineType')
	if ([string]::IsNullOrEmpty($MachineType)) {
		$MachineType = 'UNKNOWN'
	}

	if ($global:gsComputerManufacturer -like '*Lenovo*') {
		$LenovoModelVersion = (Get-CimInstance -ClassName Win32_ComputerSystemProduct).Version
		$ModelName = "$LenovoModelVersion - $global:gsComputerModel"
	} else {
		$ModelName = $global:gsComputerModel
	}

	$ProductType = (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType
	switch ($ProductType) {
		1 {
			$OSType = 'Workstation'
		}
		2 {
			$OSType = 'Domain Controller'
		}
		3 {
			$OSType = 'Server'
		}
		Default {
			$OSType = 'UNKNOWN'
		}
	}

	$OSName = ($global:gsOsSystem -replace 'Microsoft' -replace 'Enterprise' -replace 'Professional' -replace 'Pro' -replace 'Standard').Trim()

	$OSNameDisplay = "$OSName $($cs.gsDisplayVersion)"
	$OSNameDisplayBuild = "$OSNameDisplay $global:gsOsBuild"

	$Domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain.ToUpper()

	$BU = $cs.Reg_GetString('HKLM', 'SOFTWARE\CapaSystems\CapaInstaller\Client', 'BusinessUnit')
	#endregion

	if ([string]::IsNullOrEmpty($BU) -eq $false) {
		Join-StaticGroup -Name $BU
	}

	Join-StaticGroup -Prefix '1.1.' -Name $MachineType -AddBuilding $true -FolderStructure 'Managed Groups\OSD'
	Join-StaticGroup -Prefix '2.0.' -Name $Global:gsComputerManufacturer -AddBuilding $true -FolderStructure 'Managed Groups\Hardware'
	Join-StaticGroup -Prefix '2.1.' -Name $ModelName -AddBuilding $true -FolderStructure 'Managed Groups\Hardware'
	Join-StaticGroup -Prefix '3.0.' -Name $OSType -AddBuilding $true -FolderStructure 'Managed Groups\OS'
	Join-StaticGroup -Prefix '3.1.' -Name $OSName -AddBuilding $true -FolderStructure 'Managed Groups\OS'
	Join-StaticGroup -Prefix '3.2.' -Name $OSNameDisplay -AddBuilding $true -FolderStructure 'Managed Groups\OS'
	Join-StaticGroup -Prefix '3.3.' -Name $OSNameDisplayBuild -AddBuilding $true -FolderStructure 'Managed Groups\OS'
	Join-StaticGroup -Prefix '4.0.' -Name $Domain -FolderStructure 'Managed Groups\Domain'
}

function PostInstall {
	$cs.Log_SectionHeader('PostInstall', 'o')

	if ($global:UseBuildingGroups -and $Global:HaveNotBeenInBuilding) {
		$cs.Reg_SetString('HKLM', $global:BuildingRegKey, $global:BuildingRegVariable, 'True')
		if ([string]::IsNullOrEmpty($global:UnjoinBuildingGroupPackage) -eq $false -and [string]::IsNullOrEmpty($global:UnjoinBuildingGroupPackageVer) -eq $false) {
			CMS_RerunPackage -package $global:UnjoinBuildingGroupPackage -version $global:UnjoinBuildingGroupPackageVer
		}
	}
}

##############
#### MAIN ####
##############
try {
	##############################################
	#load core PS lib - don't mess with this!
	if ($global:InputObject) { $pgkit = '' }else { $pgkit = 'kit' }
	Import-Module (Join-Path $global:Packageroot $pgkit 'PSlib.psm1') -ErrorAction stop
	#load Library dll
	$cs = Add-PSDll
	##############################################

	#Begin
	$cs.Job_Start('WS', $global:AppName, $global:AppRelease, $global:LogFile, 'INSTALL')
	$cs.Job_WriteLog("[Init]: Starting package: '" + $global:AppName + "' Release: '" + $global:AppRelease + "'")
	if (!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:', 1500)) { Exit-PSScript 3333 }
	if ($global:DownloadPackage -and $global:InputObject) { Start-PSDownloadPackage }

	$cs.Job_WriteLog("[Init]: `$PackageRoot:` '" + $global:Packageroot + "'")
	$cs.Job_WriteLog("[Init]: `$AppName:` '" + $global:AppName + "'")
	$cs.Job_WriteLog("[Init]: `$AppRelease:` '" + $global:AppRelease + "'")
	$cs.Job_WriteLog("[Init]: `$LogFile:` '" + $global:LogFile + "'")
	$cs.Job_WriteLog("[Init]: `$global:AppLogFolder:` '" + $global:AppLogFolder + "'")
	$cs.Job_WriteLog("[Init]: `$TempFolder:` '" + $global:TempFolder + "'")
	$cs.Job_WriteLog("[Init]: `$DllPath:` '" + $global:DllPath + "'")
	$cs.Job_WriteLog("[Init]: `$global:DownloadPackage`: '" + $global:DownloadPackage + "'")
	$cs.Job_WriteLog("[Init]: `$global:PSLibVersion`: '" + $global:PSLibVersion + "'")
	Initialize-Variables

	PreInstall
	Install
	PostInstall
	Exit-PSScript $global:ScriptError
} catch {
	$line = $_.InvocationInfo.ScriptLineNumber
	Exit-PSScript $_.Exception.HResult
}