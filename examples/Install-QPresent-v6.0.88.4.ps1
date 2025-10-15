[CmdletBinding()]
param(
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
[bool]$global:DownloadPackage = $true # Set to $true if you want to download the kit folder from the server

# DO NOT CHANGE THESE VARIABLES
$global:Packageroot = $Packageroot
$global:AppName = $AppName
$global:AppRelease = $AppRelease
$global:LogFile = $LogFile
$global:TempFolder = $TempFolder
$global:DllPath = $DllPath
$global:InputObject = $InputObject

###################
#### FUNCTIONS ####
###################
function PreInstall {
	$cs.Log_SectionHeader('PreInstall', 'o')
}

function InstallQplant {
	$cs.Log_SectionHeader('InstallQplant', 'o')

	$Source = Join-Path $global:Packageroot 'kit' '1 - Qplant' 'QPlant'
	$Destination = Join-Path $global:gsProgramFiles 'QPlant'

	$cs.File_CopyTree($Source, $Destination)

	$ShortcutPath = Join-Path $global:gsCommonPrograms 'TAI-Plataforma.lnk'
	$Obj = New-Object -ComObject WScript.Shell
	$Shortcut = $Obj.CreateShortcut($ShortcutPath)
	$Shortcut.TargetPath = Join-Path $Destination 'TAIPlataforma.exe'
	$Shortcut.WorkingDirectory = $Destination
	$Shortcut.Save()
}

function InstallQplantUpdate {
	$cs.Log_SectionHeader('InstallQplantUpdate', 'o')

	$Source = Join-Path $global:Packageroot 'kit' '2 - Qplant update' 'C1_8_q104'
	$Destination = Join-Path $global:gsProgramFiles 'QPlant'

	$cs.File_CopyTree($Source, $Destination)
}

function RegistrerQplant {
	$cs.Log_SectionHeader('RegisterQplant', 'o')

	$Destination = Join-Path $global:gsProgramFiles 'QPlant'
	<# $FilesToRegistre = Get-ChildItem -Path $Destination -Recurse -Include *.dll, *.ocx
	foreach ($File in $FilesToRegistre) {
		$cs.Job_WriteLog("Registering file: $($File.FullName)")
		$RetVal = $cs.Shell_Execute('C:\Windows\SysWOW64\regsvr32.exe', "/s `"$($File.FullName)`"")

		switch ($RetVal) {
			4 {
				$RetVal = $cs.Shell_Execute('C:\Windows\System32\regsvr32.exe', "/s `"$($File.FullName)`"")
				if ($RetVal -ne 0) {
					Exit-PSScript $RetVal
				}
			}
			default {
				Exit-PSScript $RetVal
			}
		}
	} #>

	$FilesToRegistre = @(
		'msvbvm60.dll'
		, 'COMCAT.DLL'
		, 'OLEPRO32.DLL'
		, 'OLEAUT32.DLL'
		, 'tiholyx8.dll'
		, 'vbscript.dll'
		, 'TDBWSnk6.dll'
		, 'xadb8.ocx'
		, 'truedc8.ocx'
		, 'vsvport8.ocx'
		, 'tishare8.dll'
		, 'titext8.ocx'
		, 'C1Query80UI.ocx'
		, 'vsflex8.ocx'
		, 'Vsflex7l.ocx'
		, 'vsrpt8.ocx'
		, 'tdbl8.ocx'
		, 'olch3x8.ocx'
		, 'tidate8.ocx'
		, 'vsdraw8.ocx'
		, 'tinumbl8.ocx'
		, 'c1awk.ocx'
		, 'ticaldr8.ocx'
		, 'vsprint8.ocx'
		, 'vsflex8d.ocx'
		, 'vsflex8n.ocx'
		, 'timask8.ocx'
		, 'titime8.ocx'
		, 'olch2x8.ocx'
		, 'tdbg8.ocx'
		, 'C1Query8.OCX'
		, 'tinumb8.ocx'
		, 'todl8.ocx'
		, 'vsstr8.ocx'
		, 'c1sizer.ocx'
		, 'todg8.ocx'
		, 'ticon3d8.ocx'
		, 'vsflex8l.ocx'
		, 'TeeChart.OCX'
		, 'MSMAPI32.OCX'
		, 'todgub7.dll'
		, 'todg7.ocx'
		, 'tdbg7.ocx'
		, 'MSSTDFMT.DLL'
		, 'MSHFLXGD.OCX'
		, 'MSCHRT20.OCX'
		, 'MSDATLST.OCX'
		, 'MSDATGRD.OCX'
		, 'MSADODC.OCX'
		, 'MSBIND.DLL'
		, 'MSDATREP.OCX'
		, 'MSDATREP.DLL'
		, 'RICHTX32.OCX'
		, 'CMCT3ES.DLL'
		, 'Comct332.ocx'
		, 'mscomct2.ocx'
		, 'Mscomctl.ocx'
		, 'Comdlg32.ocx'
		, 'TABCTL32.OCX'
		, 'MSCOMM32.OCX'
		, 'MSFLXGRD.OCX'
		, 'PICCLP32.OCX'
		, 'MSWINSCK.OCX'
		, 'MSCOMCTL.OCX'
		, 'MSADODC.OCX'
		, 'DBLIST32.OCX'
		, 'DBGRID32.OCX'
		, 'crystl32.ocx'
		, 'xadb7.ocx'
		, 'scrrun.dll'
		, 'msjet35.dll'
		, 'DAO350.DLL'
		, 'olch2xu8.ocx'
		, "Spell8.ocx"
		, "olch3xu8.ocx"
		, "tdcl8.ocx"
		, "todgub8.dll"
		, "vsflex8u.ocx"
		, "vspdf8.ocx"
		, "Thes8.ocx"
	)

	foreach ($File in $FilesToRegistre) {
		$FilePath = Join-Path $Destination $File
		if (Test-Path $FilePath) {
			$cs.Job_WriteLog("Registering file: $FilePath")
			$RetVal = $cs.Shell_Execute('C:\Windows\SysWOW64\regsvr32.exe', "/s `"$FilePath`"")

			switch ($RetVal) {
				4 {
					$RetVal = $cs.Shell_Execute('C:\Windows\System32\regsvr32.exe', "/s `"$FilePath`"")
					if ($RetVal -ne 0) {
						Exit-PSScript $RetVal
					}
				}
				0 {
					$cs.Job_WriteLog("File registered successfully: $FilePath")
				}
				default {
					Exit-PSScript $RetVal
				}
			}
		}
		else {
			$cs.Job_WriteLog("File not found for registration: $FilePath")
		}
	}
}

function InstallQplantMDAC {
	$cs.Log_SectionHeader('InstallQplantMDAC', 'o')

	$ExePath = Join-Path $global:Packageroot 'kit' '3 - Qplant MDAC' 'MDAC_TYP.EXE'
	$RetVal = $cs.Shell_Execute($ExePath, '/Q')
	if ($RetVal -ne 0) {
		$cs.Job_WriteLog("MDAC installation failed with return code: $RetVal")
		Exit-PSScript $RetVal
	}
}

function New-RandomPassword {
	param (
		[Parameter(Mandatory = $false)]
		[int]$Length = 14,
		[string]$Characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+?'
	)

	$password = -join (1..$Length | ForEach-Object { Get-Random -InputObject $Characters.ToCharArray() })
	return $password
}

function InstallOracle {
	$cs.Log_SectionHeader('InstallOracle', 'o')

	$OracleLogFolder = "C:\Program Files (x86)\Oracle\Inventory\logs"
	$OracleOldLogFolder = Join-Path $OracleLogFolder "History"
	#$TempFolder = "C:\Temp\Oracle"
	$TempRoot = "C:\CorsaAPP"
	$TempFolder = Join-Path $TempRoot 'Oracle_19-32b' "client32"
	$Source = Join-Path $global:Packageroot 'kit' '4 - Oracle'
	$ExePath = Join-Path $TempFolder 'setup.exe'
	$ResponseFile = Join-Path $TempFolder 'corsa.rsp'
	$Arguments = "-silent -responseFile `"$ResponseFile`" -ignorePrereq -waitForCompletion -noconsole"

	if ($cs.File_ExistDir($OracleLogFolder)) {
		$cs.File_CreateDir($OracleOldLogFolder)

		$Files = Get-ChildItem -Path $OracleLogFolder -File
		foreach ($File in $Files) {
			$cs.File_CopyFile($File.FullName, (Join-Path $OracleOldLogFolder $File.Name), $true)
			$cs.File_DelFile($File.FullName)
		}
	}

	#$cs.File_DelTree($TempFolder)
	$cs.File_DelTree($TempRoot)
	$cs.File_CopyTree($Source, $TempFolder)

	# Handle SEVERE: PRCZ-1082 : Failed to add Windows user or Windows group "MRADTEST03$" to Windows group "USERS"
	#$RetVal = $cs.Shell_ExecuteWithTimeout($ExePath, $Arguments, $true, 600000) # 10 minutes timeout
	$UserName = "OracleInstall"
	$Password = New-RandomPassword
	#$PSCredential = New-Object System.Management.Automation.PSCredential($UserName, (ConvertTo-SecureString $Password -AsPlainText -Force))
	$taskName = "PowerPackUserJob"
	$RetVal = 0

	try {
		$cs.UsrMgr_CreateLocalUser($UserName, "Oracle Installer User", $Password, "Used to install Oracle client software.", $true, $false)
		$cs.UsrMgr_AddUserToLocalGroup($UserName, "S-1-5-32-544") # Administrators group

		$cs.Job_WriteLog("Running Oracle installer with user: $UserName")
		$cs.Job_WriteLog("Command: $ExePath")
		$cs.Job_WriteLog("Arguments: $Arguments")

		$action = New-ScheduledTaskAction -Execute $ExePath -Argument $Arguments
		Register-ScheduledTask -TaskName $taskName -Action $action -RunLevel Highest -User $UserName -Password $Password
		Start-ScheduledTask -TaskName $taskName
		$TaskState = (Get-ScheduledTask -TaskName 'PowerPackUserJob' -ErrorAction SilentlyContinue).State
		if ($TaskState -eq 'Running') {
			while ($TaskState -eq 'Running') {
				Start-Sleep -Seconds 1
				$count++
				$TaskState = (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).State
				if ($cs -and $count % 10 -eq 0) { $cs.Job_WriteLog("Scheduled Task '$taskName' current state: $TaskState") }
				if ($count -ge 1800) { break }
			}
			$TaskState = (Get-ScheduledTask -TaskName $taskName).State
			if ($cs) { $cs.Job_WriteLog("Scheduled Task '$taskName' ended with state: $TaskState") }
		}
	}
	catch {
		$cs.Job_WriteLog("Error during Oracle installation: $($_.Exception.Message)")
		$RetVal = -1  # Set a default error code
	}
	finally {
		Get-ScheduledTask | Where-Object { $_.taskname -ilike 'PowerPackUserJob' } | Unregister-ScheduledTask -Confirm:$false
		$cs.UsrMgr_DeleteLocalUserAccount($UserName)
	}

	$Files = Get-ChildItem -Path $OracleLogFolder -File
	foreach ($File in $Files) {
		$cs.File_CopyFile($File.FullName, (Join-Path $global:AppLogFolder $File.Name), $true)
	}

	# DO NOT DELETE THE TEMP FOLDER, the Oracle installer may leave files there that are needed for the application to run.
	#$cs.File_DelTree($TempRoot)

	if ($RetVal -ne 0) {
		$cs.Job_WriteLog("Oracle installation failed with return code: $RetVal")
		Exit-PSScript $RetVal
	}
 else {
		$cs.Job_WriteLog("Oracle installed successfully.")
	}
}

function OracleExtra {
  $cs.Log_SectionHeader('OracleExtra', 'o')

  $Destination = "C:\CorsaAPP\Oracle\product\19.0.0\client_1\network\admin"
  $Source1 = Join-Path $global:Packageroot 'kit' '5 - Oracle Extra' 'tnsnames.ora'
  $Source2 = Join-Path $global:Packageroot 'kit' '5 - Oracle Extra' 'sqlnet.ora'

  $cs.File_CopyFile($Source1, (Join-Path $Destination 'tnsnames.ora'), $true)
  $cs.File_CopyFile($Source2, (Join-Path $Destination 'sqlnet.ora'), $true)

}
function Install {
	$cs.Log_SectionHeader('Install', 'o')

	InstallQplant
	InstallQplantUpdate
	RegistrerQplant
	InstallQplantMDAC
	InstallOracle
	OracleExtra
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
	Exit-PSScript 0
}
catch {
	$line = $_.InvocationInfo.ScriptLineNumber
	$cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")
	Exit-PSScript $_.Exception.HResult
}