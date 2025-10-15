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
$global:SqlServer = 'MRACAPA01'
$global:SqlDB = 'CapaInstaller'

$global:Debug = $true

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

	$ModulePath = Join-Path $global:Packageroot 'kit' 'SqlServer'
	$cs.Job_WriteLog("Importing module $ModulePath")
	Import-Module $ModulePath
	$cs.Job_WriteLog('Module imported')
}

function Get-AllParentFolders {
	$LogPrefix = 'Get-AllParentFolders:'
	$cs.Job_WriteLog("$LogPrefix Getting all parent folders")

	$query = "SELECT [ID]
      ,[NAME]
      ,[TYPE]
      ,[PARENT]
      ,[CMPID]
      ,[GUID]
      ,[RELEASE]
      ,[BUID]
  FROM [dbo].[JOBROOT]
	WHERE [PARENT] IS NULL"

	$Folders = Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

	$cs.Job_WriteLog("$LogPrefix Found $($Folders.Count) folders")

	return $Folders
}

function Get-AllChildFolders {
	param(
		$ParentFolderId
	)
	$LogPrefix = 'Get-AllChildFolders:'
	$cs.Job_WriteLog("$LogPrefix Getting all child folders for parent folder $ParentFolderId")

	$query = "SELECT [ID]
			,[NAME]
			,[TYPE]
			,[PARENT]
			,[CMPID]
			,[GUID]
			,[RELEASE]
			,[BUID]
	FROM [dbo].[JOBROOT]
	WHERE [PARENT] = $ParentFolderId"

	$Folders = Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

	$cs.Job_WriteLog("$LogPrefix Found $($Folders.Count) folders")

	return $Folders
}

function Get-IsJobsLinkedToFolder {
	param(
		$FolderId
	)
	$LogPrefix = 'Get-IsJobsLinkedToFolder:'
	$cs.Job_WriteLog("$LogPrefix Checking if there are jobs linked to folder $FolderId")

	$query = "SELECT COUNT(*) AS [COUNT]
	FROM [dbo].[JOBJOBROOT]
	WHERE [JOBROOTID] = $FolderId"

	$JobsCount = Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

	$cs.Job_WriteLog("$LogPrefix Found $JobsCount jobs linked to folder $FolderId")

	$Return = $JobsCount.COUNT -gt 0
	$cs.Job_WriteLog("$LogPrefix Return: $Return")

	return $Return
}

function Invoke-DeleteFolderRecursive {
	param(
		$Folder
	)
	$LogPrefix = 'Invoke-DeleteFolderRecursive:'

	$AllChildFolders = Get-AllChildFolders -ParentFolderId $Folder.ID

	foreach ($ChildFolder in $AllChildFolders) {
		Invoke-DeleteFolderRecursive -Folder $ChildFolder
	}

	$IsJobsLinkedToFolder = Get-IsJobsLinkedToFolder -FolderId $Folder.ID

	if ($IsJobsLinkedToFolder) {
		$cs.Job_WriteLog("$LogPrefix Folder $($Folder.NAME) has jobs linked to it. Skipping deletion")
		return
	}

	$AllChildFolders = Get-AllChildFolders -ParentFolderId $Folder.ID
	if ($AllChildFolders.Count -gt 0) {
		$cs.Job_WriteLog("$LogPrefix Folder $($Folder.NAME) has child folders. Skipping deletion")
		return
	}

	$cs.Job_WriteLog("$LogPrefix Deleting folder $($Folder.NAME) with ID $($Folder.ID)")
	$query = "DELETE FROM [dbo].[JOBROOT]
	WHERE [ID] = $($Folder.ID)"
	Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate
	$cs.Job_WriteLog("$LogPrefix Folder $($Folder.NAME) deleted")
}

function Install {
	$cs.Log_SectionHeader('Install', 'o')

	$AllParentFolders = Get-AllParentFolders

	foreach ($Folder in $AllParentFolders) {
		$FolderName = $Folder.NAME
		$cs.Job_WriteLog("Processing folder $FolderName")

		Invoke-DeleteFolderRecursive -Folder $Folder
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
	$cs = Add-PsDll
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
	Exit-PSScript $Error
} catch {
	$line = $_.InvocationInfo.ScriptLineNumber
	$cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")
	Exit-PSScript $_.Exception.HResult
}