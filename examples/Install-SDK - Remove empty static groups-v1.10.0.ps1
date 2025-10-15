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
$global:AllowRemovalIfPackagesIsAssigned = $true # Set to $true if you want to remove groups that have packages assigned, but no units
$global:LogOnly = $false # Set to $true if you want to only log the groups that would be removed, but not actually remove them

$global:Server = 'MRACAPA01'
$global:Database = 'CapaInstaller'
$global:ManagementPoints = @(1) # Array of management points to run the script against
$global:UserName = '' # Username of an SQL User with access to the CapaInstaller database, leave empty if using Windows Authentication
$global:DecryptionKey = @(248, 84, 141, 224, 207, 210, 59, 236, 155, 211, 22, 252, 114, 47, 131, 189, 254, 200, 77, 154, 250, 213, 200, 15, 36, 31, 45, 75, 135, 102, 252, 31)
$global:SecuredPassword = '76492d1116743f0423413b16050a5345MgB8AHAAcQB2AG4AZgBoADUAAzAEYATgBTAEQAMwBQAEcAVABZAEgAUwB4AHcAPQA9AHwAMQA3ADQAMgBmAGUAMgBjADMANQA3ADgAYgA1ADEAMQAyADIAMgA1AGUAYwA1ADYANwBjAGIANAAzAGEAMAAwADcANgBjAGIAOAA1AGQAYQBiAGYANgAwAGYAMgBlAGYANABlADMANAAzADAAMQA3ADkANgA4ADQANgAxAGEAZgA='

# DO NOT CHANGE THESE VARIABLES
$global:Packageroot = $Packageroot
$global:AppName = $AppName
$global:AppRelease = $AppRelease
$global:LogFile = $LogFile
$global:TempFolder = $TempFolder
$global:DllPath = $DllPath
$global:InputObject = $InputObject

[bool]$global:DownloadPackage = $true # Set to $true if you want to download the kit folder from the server

###################
#### FUNCTIONS ####
###################
function PreInstall {
	$cs.Log_SectionHeader('PreInstall', 'o')

	$ModulePath = Join-Path $global:Packageroot 'kit' 'Modules'
	$Module = Get-ChildItem -Path $ModulePath -Filter '*.psm1' -Recurse
	$Module | ForEach-Object {
		$cs.Job_WriteLog("Importing module: $($_.FullName)")
		Import-Module $_.FullName
	}

	if ($global:SecuredPassword -and $global:UserName) {
		$cs.Job_WriteLog('Decrypting password')
		$global:SecureString = $global:SecuredPassword | ConvertTo-SecureString -Key $global:DecryptionKey
		$global:BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
		$global:UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
	}
}

function Install {
	$cs.Log_SectionHeader('Install', 'o')

	$Splatting = @{
		Server   = $global:Server
		Database = $global:Database
	}
	if ($global:SecuredPassword -and $global:UserName) {
		$cs.Job_WriteLog('Setting credentials')
		$Splatting.UserName = $global:UserName
		$Splatting.Password = $global:UnsecurePassword
	}

	$cs.Job_WriteLog('Initializing CapaSDK')
	$CapaSDK = Initialize-CapaSDK @Splatting

	foreach ($Point in $global:ManagementPoints) {
		$cs.Job_WriteLog("Running for management point: $Point")

		$cs.Job_WriteLog("Setting default management point to: $Point")
		$CapaSDK.SetInstanceManagementPoint($Point)

		$cs.Job_WriteLog('Getting all static groups')
		$Groups = Get-CapaGroups -CapaSDK $CapaSDK -GroupType 'Static'
		$cs.Job_WriteLog("Found $($Groups.Count) static groups")

		foreach ($Group in $Groups) {
			$cs.Job_WriteLog("Checking group: $($Group.Name)")
			$LogPrefix = "Group: $($Group.Name):"

			if ($Group.Name -like 'CapaWinUpgrade -> *') {
				$cs.Job_WriteLog("$LogPrefix Group is a CapaWinUpgrade group, skipping")
				continue
			}

			if ($Group.Name -like '* - BUILDING') {
				$cs.Job_WriteLog("$LogPrefix Group is a building group, checking if non building group exists")
				$GroupName = $Group.Name -replace ' - BUILDING', ''
				$NonBuildingGroup = Get-CapaGroups -CapaSDK $CapaSDK -GroupType 'Static' | Where-Object { $_.Name -eq $GroupName }
				if ($NonBuildingGroup) {
					$cs.Job_WriteLog("$LogPrefix Non building group exists, skipping")
					continue
				}
			}

			$cs.Job_WriteLog("$LogPrefix Getting all linked units")
			$Units = Get-CapaGroupUnits -CapaSDK $CapaSDK -GroupType 'Static' -GroupName $Group.Name
			$cs.Job_WriteLog("$LogPrefix Found $($Units.Count) linked units")

			if ($Units.Count -ne 0) {
				$cs.Job_WriteLog("$LogPrefix Group is not empty, skipping")
				continue
			}

			if ($global:AllowRemovalIfPackagesIsAssigned -eq $false) {
				$cs.Job_WriteLog("$LogPrefix Getting all linked packages")
				$LinkedPackages = Get-CapaGroupPackages -GroupName $Group.Name -CapaSDK $CapaSDK -GroupType 'Static'
				$cs.Job_WriteLog("$LogPrefix Found $($LinkedPackages.Count) linked packages")

				if ($LinkedPackages.Count -ne 0) {
					$cs.Job_WriteLog("$LogPrefix Group has linked packages, skipping")
					continue
				}
			}

			$cs.Job_WriteLog("$LogPrefix Removing group")
			if ($global:LogOnly -eq $false) {
				Remove-CapaGroup -GroupName $Group.Name -CapaSDK $CapaSDK -GroupType 'Static' -UnitType Computer
			}
			$cs.Job_WriteLog("$LogPrefix Group removed")
		}
	}

}

function PostInstall {
	$cs.Log_SectionHeader('PostInstall', 'o')
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
	Exit-PSScript $Error
} catch {
	$line = $_.InvocationInfo.ScriptLineNumber
	$cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")
	Exit-PSScript $_.Exception.HResult
}