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
$global:SqlServer = 'CapaInstaller.DK'
$global:SqlDB = 'CMS'

$global:Debug = $false

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



function Get-AllCIBUJobs {
	$LogPrefix = 'Get-AllCIBUJobs:'
	$cs.Job_WriteLog("$LogPrefix Getting all Jobs linked to BUs")

	$query = "SELECT [BUID]
   ,BUJOB.[JOBID]
   ,IIF(JOB.[TYPE] = 1, 'Computer', 'User') AS [TYPE]
   , JOB.CMPID
 FROM [dbo].[BUJOB]
Join JOB on JOB.JOBID = BUJOB.JOBID"
	$jobs = Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

	$cs.Job_WriteLog("$LogPrefix Found $($jobs.Count) jobs")

	return $jobs
}

function Get-AllCIFolders {
	$LogPrefix = 'Get-AllCIFolders:'
	$cs.Job_WriteLog("$LogPrefix Getting all folders")

	$query = 'SELECT [ID]
   ,[NAME]
   ,[TYPE]
   ,[PARENT]
   ,[CMPID]
   ,[GUID]
   ,[RELEASE]
   ,[BUID]
 FROM [dbo].[JOBROOT]'
	$folders = Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

	if ($global:Debug) {
		$cs.Job_WriteLog("$LogPrefix First folder in list: ID: $($folders[0].ID) | Name: $($folders[0].NAME) | Type: $($folders[0].TYPE) | Parent: $($folders[0].PARENT) | CMPID: $($folders[0].CMPID) | GUID: $($folders[0].GUID) | RELEASE: $($folders[0].RELEASE) | BUID: $($folders[0].BUID)")
	}
	$cs.Job_WriteLog("$LogPrefix Found $($folders.Count) folders")

	return $folders
}

function Get-AllCIBUJobFolders {
	$LogPrefix = 'Get-AllCIBUJobFolders:'
	$cs.Job_WriteLog("$LogPrefix Getting all jobs in BUs folders")

	$query = 'SELECT JJR.JOBID
  ,JJR.JOBROOTID
  ,JR.[NAME]
  ,JR.[TYPE]
  ,JR.PARENT
  ,JR.CMPID
  ,JR.BUID
 FROM [dbo].[JOBJOBROOT] JJR
JOIN JOBROOT JR ON JR.ID = JJR.JOBROOTID'
	$folders = Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

	$cs.Job_WriteLog("$LogPrefix Found $($folders.Count) folders")

	return $folders
}

function Get-FolderstructureRecursive {
	param (
		$FolderID
	)
	$Folder = $Global:Folders | Where-Object { $_.ID -eq $FolderID }
	$ParentFolder = $Global:Folders | Where-Object { $_.ID -eq $Folder.PARENT }
	$FolderStructure = @()
	$FolderStructure += $Folder
	if ($ParentFolder) {
		$FolderStructure += Get-FolderstructureRecursive -FolderID $ParentFolder.ID
	}

	return $FolderStructure
}

function Get-JobFolderStructureInRoot {
	param (
		[int]$JobID
	)

	$Folder = $Global:JobFolders | Where-Object { $_.JOBID -eq $JobID -and [string]::IsNullOrEmpty($_.BUID) }
	$FolderStructure = Get-FolderstructureRecursive -FolderID $Folder.JOBROOTID

	if ($global:Debug) {
		$cs.Job_WriteLog("Folder structure in root for Job ID $JobID")
		$FolderStructure | ForEach-Object {

			$cs.Job_WriteLog("  ID: $($_.ID) | Name: $($_.NAME) | Type: $($_.TYPE) | Parent: $($_.PARENT) | CMPID: $($_.CMPID) | GUID: $($_.GUID) | RELEASE: $($_.RELEASE) | BUID: $($_.BUID)")
		}
	}

	return $FolderStructure
}

function Get-JobFolderStructureInBU {
	param (
		[int]$JobID
	)

	$Folder = $Global:JobFolders | Where-Object { $_.JOBID -eq $JobID -and $_.BUID -eq 1 }
	$FolderStructure = Get-FolderstructureRecursive -FolderID $Folder.JOBROOTID

	if ($global:Debug) {
		$cs.Job_WriteLog("Folder structure in BU for Job ID $JobID")
		$FolderStructure | ForEach-Object {
			$cs.Job_WriteLog("  ID: $($_.ID) | Name: $($_.NAME) | Type: $($_.TYPE) | Parent: $($_.PARENT) | CMPID: $($_.CMPID) | GUID: $($_.GUID) | RELEASE: $($_.RELEASE) | BUID: $($_.BUID)")
		}
	}

	return $FolderStructure
}

function Get-ParentFolder {
	param (
		[int]$FolderID
	)
	$LogPrefix = 'Get-ParentFolder:'
	$cs.Job_WriteLog("$LogPrefix Getting parent folder for folder ID $FolderID")

	$query = "SELECT [ID]
   ,[NAME]
   ,[TYPE]
   ,[PARENT]
   ,[CMPID]
   ,[GUID]
   ,[RELEASE]
   ,[BUID]
 FROM [dbo].[JOBROOT]
  WHERE ID = $FolderID"
	$folder = Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

	$cs.Job_WriteLog("$LogPrefix Found parent folder $($folder.Name) (ID: $($folder.ID))")

	return $folder
}

function Get-FolderStructureAsString {
	param (
		$FolderStructure,
		$IsRecursive = $false
	)
	if ($FolderStructure.Count -eq 0) {
		return ''
	}	elseif ($FolderStructure.Count -eq 1) {
		$FolderStructureAsString = "$($FolderStructure.Name)\"
	} else {
		if ($IsRecursive) {
			$FolderStructureAsString = $FolderStructure.Name -join '\'
		} else {
			$FolderStructureAsString = ($FolderStructure.Name[-1.. - ($FolderStructure.Count)]) -join '\'
		}
	}

	return $FolderStructureAsString
}

function Get-ParentFolderInBu {
	param (
		$ParentFolder,
		$BUID,
		$JobRootStructure
	)
	$LogPrefix = 'Get-ParentFolderInBu:'
	$cs.Job_WriteLog("$LogPrefix Getting parent folder in BU for folder $($ParentFolder.NAME) (ID: $($ParentFolder.ID)) | BUID: $BUID")

	$query = "SELECT [ID]
      ,[NAME]
      ,[TYPE]
      ,[PARENT]
      ,[CMPID]
      ,[GUID]
      ,[RELEASE]
      ,[BUID]
  FROM [dbo].[JOBROOT]
  WHERE NAME = '$($ParentFolder.NAME)'
  AND TYPE = '$($ParentFolder.TYPE)'
  AND CMPID = '$($ParentFolder.CMPID)'
  AND BUID = $BUID"
	$folder = Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

	if ($folder.Count -gt 1) {
		$cs.Job_WriteLog("$LogPrefix Found more than one folder with the same name $($ParentFolder.NAME) in BU. Trying to find the correct one")
		$ParentFolderInBu = $null
		$JobRootStructureAsString = Get-FolderStructureAsString -FolderStructure $JobRootStructure -IsRecursive $true

		$cs.Job_WriteLog("$LogPrefix JobRootStructureAsString: $JobRootStructureAsString")

		foreach ($Item in $folder) {
			$cs.Job_WriteLog("$LogPrefix Checking folder $($Item.NAME) (ID: $($Item.ID))")

			$FolderStructure = Get-FolderstructureRecursive -FolderID $Item.ID

			$FolderStructureAsString = Get-FolderStructureAsString -FolderStructure $FolderStructure
			$cs.Job_WriteLog("$LogPrefix FolderStructureAsString: $FolderStructureAsString")

			$Check = $JobRootStructureAsString -like "$FolderStructureAsString*"
			$cs.Job_WriteLog("$LogPrefix Folder structure check: $Check")

			if ($Check) {
				$ParentFolderInBu = $Item
				break
			}
		}
		if ($ParentFolderInBu) {
			$cs.Job_WriteLog("$LogPrefix Found parent folder $($ParentFolderInBu.NAME) (ID: $($ParentFolderInBu.ID))")
			return $ParentFolderInBu
		}
	}

	$cs.Job_WriteLog("$LogPrefix Found only one folder $($folder.Name) (ID: $($folder.ID))")
	$cs.Job_WriteLog("$LogPrefix Found parent folder $($folder.Name) (ID: $($folder.ID))")

	return $folder
}

function Get-CiFolder {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[Parameter(Mandatory = $true)]
		[string]$Type,
		[Parameter(Mandatory = $false)]
		[string]$Parent,
		[Parameter(Mandatory = $true)]
		[string]$CmpID,
		[Parameter(Mandatory = $false)]
		[string]$BUID
	)
	$LogPrefix = 'Get-CiFolder:'
	$cs.Job_WriteLog("$LogPrefix Getting folder with name $Name | Type: $Type | Parent: $Parent | CMPID: $CmpID | BUID: $BUID")

	$query = "SELECT [ID]
      ,[NAME]
      ,[TYPE]
      ,[PARENT]
      ,[CMPID]
      ,[GUID]
      ,[RELEASE]
      ,[BUID]
  FROM [dbo].[JOBROOT]
  WHERE NAME = '$Name'
  AND TYPE = '$Type'
  AND CMPID = '$CmpID'"

	if ($Parent) {
		$query += " AND PARENT = $Parent"
	}
	if ($BUID) {
		$query += " AND BUID = $BUID"
	}

	$folder = Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

	$cs.Job_WriteLog("$LogPrefix Found folder $($folder.Name) (ID: $($folder.ID))")

	return $folder
}

function Invoke-SameFolderStructureInBU {
	Param (
		$JobRootStructure,
		$Job
	)
	$LogPrefix = "JOBID: $($Job.JOBID): Invoke-SameFolderStructureInBU:"

	if ([string]::IsNullOrWhiteSpace($JobRootStructure)) {
		$cs.Job_WriteLog("$LogPrefix Job has no folder structure in root. Moving job out of folders")
		$query = "DELETE FROM [dbo].[JOBJOBROOT]
  WHERE JOBID = $($Job.JOBID)"
		Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate
		return
	}

	$cs.Job_WriteLog("$LogPrefix Creating folder structure in BU")
	if ($JobRootStructure.Count -gt 1) {
		$JobRootStructure = $JobRootStructure[-1.. - ($JobRootStructure.Count)]
	}

	foreach ($CurrentFolder in $JobRootStructure) {
		if ([string]::IsNullOrWhiteSpace($CurrentFolder.PARENT)) {
			$Guid = ([guid]::NewGuid()).Guid

			$query = "IF NOT EXISTS (
  SELECT 1 FROM [dbo].[JOBROOT]
  WHERE NAME = '$($CurrentFolder.NAME)'
   AND TYPE = '$($CurrentFolder.TYPE)'
   AND PARENT IS NULL
   AND CMPID = $($CurrentFolder.CMPID)
   AND BUID = $($Job.BUID)
)
BEGIN
  INSERT INTO [dbo].[JOBROOT] ([NAME], [TYPE], [PARENT], [CMPID], [BUID], [GUID])
  VALUES ('$($CurrentFolder.NAME)', '$($CurrentFolder.TYPE)', NULL, '$($CurrentFolder.CMPID)', '$($Job.BUID)', '$Guid')
END
"
			Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate

			if ($global:Debug) {
				$cs.Job_WriteLog("$LogPrefix $CurrentFolder")
				$cs.Job_WriteLog("$LogPrefix Calling Get-CiFolder with Name: $($CurrentFolder.NAME) | Type: $($CurrentFolder.TYPE) | CMPID: $($CurrentFolder.CMPID) | BUID: $($Job.BUID)")
			}
			$NewFolder = Get-CiFolder -Name $CurrentFolder.NAME -Type $CurrentFolder.TYPE -CmpID $CurrentFolder.CMPID -BUID $Job.BUID
		} else {
			$ParentFolder = Get-ParentFolder -FolderID $CurrentFolder.PARENT
			$ParentFolderInBu = Get-ParentFolderInBu -ParentFolder $ParentFolder -BUID $Job.BUID -JobRootStructure $JobRootStructure
			$Guid = ([guid]::NewGuid()).Guid

			$query = "IF NOT EXISTS (
    SELECT 1 FROM [dbo].[JOBROOT]
    WHERE NAME = '$($CurrentFolder.NAME)'
      AND TYPE = '$($CurrentFolder.TYPE)'
      AND PARENT = $($ParentFolderInBu.ID)
      AND CMPID = $($CurrentFolder.CMPID)
      AND BUID = $($Job.BUID)
  )
  BEGIN
    INSERT INTO [dbo].[JOBROOT] ([NAME], [TYPE], [PARENT], [CMPID], [BUID], [GUID])
    VALUES ('$($CurrentFolder.NAME)', '$($CurrentFolder.TYPE)', $($ParentFolderInBu.ID), $($CurrentFolder.CMPID), $($Job.BUID), '$Guid')
  END
  "
			try {
				Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate
			} catch {
				$cs.Job_WriteLog("$LogPrefix Error: $($_.Exception.Message)")
			}

			$NewFolder = Get-CiFolder -Name $CurrentFolder.NAME -Type $CurrentFolder.TYPE -Parent $ParentFolderInBu.ID -CmpID $CurrentFolder.CMPID -BUID $Job.BUID
		}
	}
	$cs.Job_WriteLog("$LogPrefix DONE - Creating folder structure in BU")

	$query = "IF EXISTS (
  SELECT 1
  FROM [dbo].[JOBJOBROOT] JJR
  JOIN JOBROOT JR ON JR.ID = JJR.JOBROOTID
    WHERE JJR.JOBID = $($Job.JOBID)
    AND JR.BUID = $($Job.BUID)
  )
  BEGIN
    UPDATE JJR
  SET JJR.JOBROOTID = $($NewFolder.ID)
  FROM [dbo].[JOBJOBROOT] JJR
  JOIN JOBROOT JR ON JR.ID = JJR.JOBROOTID
  WHERE JJR.JOBID = $($Job.JOBID)
  AND JR.BUID = $($Job.BUID)
  END
  ELSE
  BEGIN
    INSERT INTO [dbo].[JOBJOBROOT] ([JOBID], [JOBROOTID])
    VALUES ($($Job.JOBID), $($NewFolder.ID))
  END
  "

	$cs.Job_WriteLog("$LogPrefix Moving job to folder ID $($NewFolder.ID)")
	Invoke-Sqlcmd -ServerInstance $global:SqlServer -Database $global:SqlDB -Query $query -TrustServerCertificate
	$cs.Job_WriteLog("$LogPrefix DONE - Moving job to folder ID $($NewFolder.ID)")
}

function Install {
	$cs.Log_SectionHeader('Install', 'o')

	$Global:Jobs = Get-AllCIBUJobs
	$Global:Folders = Get-AllCIFolders
	$Global:JobFolders = Get-AllCIBUJobFolders

	foreach ($Job in $Global:Jobs) {
		try {
			$LogPrefix = "JOBID: $($Job.JOBID):"
			$cs.Job_WriteLog("Running for Job ID $($Job.JOBID)")

			$cs.Job_WriteLog("$LogPrefix Getting folder structure in root")
			$FolderStructureRoot = Get-JobFolderStructureInRoot -JobID $Job.JOBID
			$FolderStructureRootAsString = Get-FolderStructureAsString -FolderStructure $FolderStructureRoot
			$cs.Job_WriteLog("$LogPrefix Got folder structure: $FolderStructureRootAsString")

			$cs.Job_WriteLog("$LogPrefix Getting folder structure in BU")
			$FolderStructureBU = Get-JobFolderStructureInBU -JobID $Job.JOBID
			if ($FolderStructureBU.Count -ne 0) {
				$FolderStructureBUAsString = Get-FolderStructureAsString -FolderStructure $FolderStructureBU
			}
			$cs.Job_WriteLog("$LogPrefix Got folder structure: $FolderStructureBUAsString")

			if ($FolderStructureRootAsString -eq $FolderStructureBUAsString) {
				$cs.Job_WriteLog("$LogPrefix Folder structure is the same. Skipping...")
				continue
			}
			$cs.Job_WriteLog("$LogPrefix Folder structure is different. Setting it to the same as in root")

			Invoke-SameFolderStructureInBU -JobRootStructure $FolderStructureRoot -Job $Job
		} catch {
			$cs.Job_WriteLog("Something went wrong for Job ID $($Job.JOBID)")
			$cs.Job_WriteLog("Error: $_.Exception.Message")
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