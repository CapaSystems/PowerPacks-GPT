[CmdletBinding()]
param(
	[Parameter(Mandatory = $false)]
	[string]$Packageroot = (Get-ScriptDirectory),
	[Parameter(Mandatory = $false)]
	[string]$AppName = 'OS - Join Domain',
	[Parameter(Mandatory = $false)]
	[string]$AppRelease = 'v2025-04',
	[Parameter(Mandatory = $false)]
	[string]$LogFile = (Join-Path (Get-ScriptDirectory) $AppName 'Install.log'),
	[Parameter(Mandatory = $false)]
	[string]$TempFolder = (Join-Path (Get-ScriptDirectory) $AppName 'Temp'),
	[Parameter(Mandatory = $false)]
	[string]$DllPath,
	[Parameter(Mandatory = $false)]
	[Object]$InputObject = $null
)


##################
### PARAMETERS ###
##################
# DO NOT CHANGE
[bool]$global:DownloadPackage = $false
$Global:Packageroot = $Packageroot
$Global:AppName = $AppName
$Global:AppRelease = $AppRelease
$Global:LogFile = $LogFile
$Global:TempFolder = $TempFolder
$Global:DllPath = $DllPath
$Global:InputObject = $InputObject
# Change as needed

<#
	The AD user is both used to Join and delete computer in the domain.
#>
$global:ADUseDT = $true # (perfered methode) If true the following info wil come from deployment templates
$global:ADJoinUser = 'OSInstall'
$global:FullDomain = 'FirmaX.Local'
$global:ADServerPreferred = 'MRACAPA03.FirmaX.Local'
$global:OUPath = 'OU=Test,DC=FirmaX,DC=local'
$global:OUPathRemove = "LDAP://$global:ADServerPreferred/DC=FirmaX,DC=local"
$global:ADJoinKeyString = @(142, 222, 103, 124, 140, 204, 138, 109, 55, 55, 15, 254, 214, 179, 101, 220, 24, 40, 33, 109, 190, 187, 229, 224, 249, 137, 211, 172, 154, 169, 141, 5)
$global:ADJoinSecurePassword = '76492d1116743f0423413b16050a5345MgB8AEIAMgBSADYASgBjAHgASABlAG0ASABGAEwARgBqAEMAUQBpAFgsBrAGcAPQA9AHwANAA4ADYAYgAxADcAMwA0AGQAMAAzADgAZAAzADAANQA0ADAAYgA3ADQAYwA5ADkANwAyADYAZABkAGQAYgAzADkAOABjAGUAMAA1ADIAYgAyADEANQAwAGMAYwA1AGIAMwBjAGYAOQA3ADAAOQBiADgANQBlAGQAMgBmAGUANQBhAGIAYQBjADAANwBlADAAZABlAGEAOABjADAAYQBiADYAYwA1AGQAZgA3ADIAMABiAGUANwBjAGIANwA4ADAAMAA0ADMAOQAwADkAZgBiADQANwBkADQANAA1ADMAMgBjAGUAZAAyADQAMwBmADYAZAAwADYAMgBhADcAOQAwAGYAYQA3AGQAZgBlADEAOAA1ADUANgA0ADUANAAxAGIANwBiADQAYwBkADUAOAAyADAANQA2ADkANABmADgAYQA0ADgAYQAwAGIAMQA4AGEAZAAxAGEAMwA0AhjAMwAxAGIANQBiADUAYgAxADgAOQA5AGUAYgBjADAAZQA4ADEAZQA3ADUAYgA0AGIAYwBlAGUAOQBjADEAMwA2ADAAYgA2AGIAOQBiAGYAYgBiADgAZQBlAGYANgA3AGQAYgAyADMAZAAxADEAZgA2AGMANABkADkAMwBhAGIAMgA5AGEAMgA1AGYAMgAwAGQAYgA5ADcAMQAzADEAZgBhAGYANgAzADgAYgA2AGEANwAzADAAYgBjADQANgA2ADUAMAA3ADkAOQBlADYAOQA5AGUAMwBkAGUANABkADgAZQA2ADUA'


$global:CCSUseDT = $false # (perfered methode) If true the following info wil come from deployment templates
$global:CCSUrl = 'https://MRACAPA03.Firmax.local/CCSWebservice/CCS.asmx' # Do not set if you don't want to use this functionality
$global:CCSUser = 'svc_capawebservice'
$global:CCSKeyString = @(76, 180, 142, 224, 38, 10, 211, 95, 152, 109, 141, 222, 148, 24, 199, 9, 134, 115, 65, 157, 238, 23, 115, 31, 119,39,87,248,172,44,27,238)
$global:CCSSecurePassword = '76492d1116743f0423413b16050a5345MgB8AGMAeQBWADMANwBHAEsASQBEADYAZwBVAGEALwBrAGsAaGUAaABUAGcAPQA9AHwAYQA4ADAAMQAzADYANABkAGUANwAwADcAZQBjADQANQBhAGMAOAA2AGIANQBjADUAZQA3ADUANABkADAAMgAwADMAMABmADUANQA2AGMANQBkADUAZQBmAGEANwA0ADMANgA3ADgANwA3ADkAZgA4AGMAYwAyADQAYQBkADUAMAA='

$global:LogSensativeData = $false # Set to true if you want to log sensative data like passwords. Default is false.

#################
### FUNCTIONS ###
#################
function InitializeBasic {
	if ($InputObject) { $pgkit = '' }else { $pgkit = 'kit' }
	Import-Module (Join-Path $Packageroot $pgkit 'PSlib.psm1') -ErrorAction stop
	$global:cs = Add-PsDll
}

function Begin {
	#Begin
	Job_Start -JobType 'WS' -PackageName $Global:AppName -PackageVersion $Global:AppRelease -LogPath $Global:LogFile -Action 'INSTALL'
	Log_SectionHeader -Name 'Begin'
	Job_WriteLog -Text ("[Init]: Starting package: '" + $Global:AppName + "' Release: '" + $Global:AppRelease + "'")
	if (!(Sys_IsMinimumRequiredDiskspaceAvailable -Drive 'c:' -MinimumRequiredDiskspace 1500)) { Exit-PpMissingDiskSpace }
	Initialize-PpInputObject
	if ($global:DownloadPackage -and $Global:InputObject) { Start-PSDownloadPackage }
	Initialize-PpVariables -DllPath $Global:DllPath

	Job_WriteLog -Text ("[Init]: `$Global:Packageroot:` '" + $Global:Packageroot + "'")
	Job_WriteLog -Text ("[Init]: `$Global:AppName:` '" + $Global:AppName + "'")
	Job_WriteLog -Text ("[Init]: `$Global:AppRelease:` '" + $Global:AppRelease + "'")
	Job_WriteLog -Text ("[Init]: `$Global:LogFile:` '" + $Global:LogFile + "'")
	Job_WriteLog -Text ("[Init]: `$Global:TempFolder:` '" + $Global:TempFolder + "'")
	Job_WriteLog -Text ("[Init]: `$Global:DllPath:` '" + $Global:DllPath + "'")
	Job_WriteLog -Text ("[Init]: `$global:DownloadPackage`: '" + $global:DownloadPackage + "'")
}

function Get-ADInfoFromDT {
	Job_WriteLog -Text "global:ADUseDT: $global:ADUseDT | Getting data from deployment template"

	$global:FullDomain = Get-PpCMSDeploymentTemplateVariable -Section 'Domain' -Variable 'domainName' -MustExist $false
	if ([string]::IsNullOrWhiteSpace($global:FullDomain)) {
		Job_WriteLog -Text 'joinDomain is null or white space, then it must be an workgroup machine'
		Exit-PpScript -ExitCode 0 -ExitMessage 'Workgroup machine'
	}

	$global:ADJoinUser = Get-PpCMSDeploymentTemplateVariable -Section 'Domain' -Variable 'domainUserName'
	$global:OUPath = Get-PpCMSDeploymentTemplateVariable -Section 'Domain' -Variable 'computerObjectOU'

	Job_WriteLog -Text 'Getting domainUserPassword from Deployment Templates'
	#Job_DisableLog
	$Password = Get-PpCMSDeploymentTemplateVariable -Section 'Domain' -Variable 'domainUserPassword'
	#Job_EnableLog

	$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
	$global:ADCredential = New-Object System.Management.Automation.PSCredential("$global:ADJoinUser@$global:FullDomain", $SecurePassword)

	$global:ADServerPreferred = Get-PpCMSDeploymentTemplateVariable -Section 'Domain' -Variable 'joinDomain'

	$TempSplit = $global:ADServerPreferred.Split('.')
	$global:OUPathRemove = $null
	for ($i = 1; $i -lt $TempSplit.Count; $i++) {
		if ($null -eq $global:OUPathRemove) {
			$global:OUPathRemove = "LDAP://$global:ADServerPreferred/DC=$($TempSplit[$i])"
		} else {
			$global:OUPathRemove = "$global:OUPathRemove,DC=$($TempSplit[$i])"
		}
	}
	Job_WriteLog -Text "global:OUPathRemove: $global:OUPathRemove"

	Job_WriteLog -Text 'Done getting AD data from deployment templates'

	if ($global:LogSensativeData) {
		$LogPrefix ='Log Sensative Data:'

		Job_WriteLog -Text "$LogPrefix global:FullDomain: $global:FullDomain"
		Job_WriteLog -Text "$LogPrefix global:ADJoinUser: $global:ADJoinUser"
		Job_WriteLog -Text "$LogPrefix global:OUPath: $global:OUPath"
		Job_WriteLog -Text "$LogPrefix global:ADUserPassword: $Password"
		Job_WriteLog -Text "$LogPrefix global:ADServerPreferred: $global:ADServerPreferred"
		Job_WriteLog -Text "$LogPrefix global:OUPathRemove: $global:OUPathRemove"
	}
}

function Get-CCSInfoFromDT {
	Job_WriteLog -Text 'Getting CCS data from deployment template'

	$global:CCSUser = Get-PpCMSDeploymentTemplateVariable -Section 'customValues' -Variable 'CCSUser'
	$global:CCSUrl = Get-PpCMSDeploymentTemplateVariable -Section 'customValues' -Variable 'CCSUrl'

	Job_WriteLog -Text 'Getting CCS password from Deployment Templates'
	Job_DisableLog
	$Password = Get-PpCMSDeploymentTemplateVariable -Section 'customValues' -Variable 'CCSPassword'
	Job_EnableLog

	$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
	$global:CCSCredential = New-Object System.Management.Automation.PSCredential($global:CCSUser, $SecurePassword)

	Job_WriteLog -Text 'Done getting CCS data from deployment template'
}

function PreInstall {
	Log_SectionHeader -Name 'PreInstall'

	Job_WriteLog -Text 'Importing module Microsoft.PowerShell.Management'
	Import-Module Microsoft.PowerShell.Management -UseWindowsPowerShell -NoClobber -WarningAction:SilentlyContinue

	if ($global:ADUseDT) {
		Get-ADInfoFromDT
	} else {
		Job_WriteLog -Text 'Creating SecureString'
		$SecureString = $global:ADJoinSecurePassword | ConvertTo-SecureString -Key $global:ADJoinKeyString
		Job_WriteLog -Text 'Creating AD join credential'
		$global:ADCredential = New-Object System.Management.Automation.PSCredential("$global:ADJoinUser@$global:FullDomain", $SecureString)
	}

	Job_WriteLog -Text 'Is the computer part of a domain?'
	$global:ComSys = Get-CimInstance Win32_ComputerSystem
	if ($global:ComSys.PartOfDomain -eq $true) {
		Job_WriteLog -Text 'Computer is part of a domain'
		Job_WriteLog -Text 'Unjoining computer from domain'

		try {
			$global:ComSys | Invoke-CimMethod -MethodName UnjoinDomainOrWorkGroup -Arguments @{
				FUnjoinOptions = 0
				Password       = $global:ADCredential.GetNetworkCredential().Password
				UserName       = $global:ADCredential.UserName
			}

			Job_WriteLog -Text 'DONE - Unjoining computer from domain'
		} catch {
			Job_WriteLog -Text "Failed to unjoin computer from domain. Error: $($_.Exception.Message)"
			Exit-PSScript $Error
		}
	} else {
		Job_WriteLog -Text 'Computer is not part of a domain'
	}

	try {
		Job_WriteLog -Text 'Add computer to workgroup WORKGROUP'
		Add-Computer -WorkgroupName WORKGROUP -Force -ErrorAction SilentlyContinue
		Job_WriteLog -Text 'DONE - Add computer to workgroup WORKGROUP'
	} catch {
		Job_WriteLog -Text "Failed to add computer to workgroup WORKGROUP. Error: $($_.Exception.Message)"
	}

	if ($global:CCSUrl -or $global:CCSUseDT) {
		Job_WriteLog -Text "global:CCSUseDT: $global:CCSUseDT"

		if ($global:CCSUseDT) {
			Get-CCSInfoFromDT
		} else {
			Job_WriteLog -Text 'CCS Url is set.'

			Job_WriteLog -Text 'Creating SecureString'
			$SecureString = $global:CCSSecurePassword | ConvertTo-SecureString -Key $global:CCSKeyString
			$global:CCSCredential = New-Object System.Management.Automation.PSCredential($global:CCSUser, $SecureString)
		}

		$Splat = @{
			ComputerName     = $env:COMPUTERNAME
			Domain           = $global:FullDomain
			URL              = $global:CCSUrl
			CCSCredential    = $global:CCSCredential
			DomainCredential = $global:ADCredential
			DomainOUPath     = $global:OUPathRemove
		}
		Remove-CCSADComputer @Splat
	}
}

function Install {
	Log_SectionHeader -Name 'Install'

	Job_WriteLog -Text 'Joining computer to domain'

	try {
		Add-Computer -DomainName $global:FullDomain -OUPath $global:OUPath -Credential $global:ADCredential -Server $global:ADServerPreferred
		Job_WriteLog -Text 'DONE - Joining computer to domain'
	} catch {
		Job_WriteLog -Text "Failed to join computer to domain. Error: $($_.Exception.Message)"
		Exit-PpScript $Error
	}

	Job_RebootWS -Text 'Rebooting to join domain'
}
############
### Main ###
############
try {
	InitializeBasic
	Import-Module Capa.PowerShell.Module.PowerPack -ErrorAction Stop
	Begin
	PreInstall
	Install
	Exit-PpScript $Error
} catch {
	$line = $_.InvocationInfo.ScriptLineNumber
	$global:cs.Job_WriteLog("***************** Something bad happend at line $$($line): $$($_.Exception.Message)")
	Exit-PpScript $_.Exception.HResult
}