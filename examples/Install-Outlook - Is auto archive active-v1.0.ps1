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
function Install {
	$cs.Log_SectionHeader('Install', 'o')
	$Path = "Software\Microsoft\Office\16.0\Outlook\Preferences"
	$Name = "DoAging"
	$OkValue = 0

	$Result = $false
	$RegKeys = (Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList').PSChildName

	$UsersRegKey = @()
	$UsersRegKey += $RegKeys
	$UsersRegKey += 'DEFAULT'

	try {
		foreach ($User in $UsersRegKey) {
			if ($Result) {
				break
			}

			Write-Host "$LogPreTag Running for $User"
			$cs.Job_WriteLog("Running for $User")

			$split = $User -split '-'
			# Skip if the user is not a user or the default user
			$split = $User -split '-'
			if ($split[3] -ne '21' -and $User -ne 'DEFAULT') {
				Write-Host "$LogPreTag Skipping $User"
				$cs.Job_WriteLog("Skipping $User")
				continue
			}

			# Sets user specific variables
			switch ($User) {
				'DEFAULT' {
					$ProfileImagePath = 'C:\Users\DEFAULT'
					$Temp_Registry_Root = 'registry::HKEY_LOCAL_MACHINE'
					$RegistryCoreKey = 'TempHive\'
					$HKUExists = $false
				}
				Default {
					$ProfileImagePath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$User" -Name 'ProfileImagePath').ProfileImagePath
					if ($ProfileImagePath) {
						if (Test-Path -Path "registry::HKEY_USERS\$User") {
							$Temp_Registry_Root = 'registry::HKEY_USERS'
							$RegistryCoreKey = "$User\"
							$HKUExists = $true
						} else {
							$Temp_Registry_Root = 'registry::HKEY_LOCAL_MACHINE'
							$RegistryCoreKey = 'TempHive\'
							$HKUExists = $false
						}
					} else {
						Write-Host "$LogPreTag ProfileImagePath is empty for $User. Skipping..."
						$cs.Job_WriteLog("ProfileImagePath is empty for $User. Skipping...")
						continue
					}
				}
			}

			# Load the NTUSER.DAT file if it exists
			$NTUserDatFile = Join-Path $ProfileImagePath 'NTUSER.DAT'
			if ($RegistryCoreKey -eq 'TempHive\' -and (Test-Path -Path $NTUserDatFile)) {
				$ArgumentList = "/c reg load HKEY_LOCAL_MACHINE\TempHive `"$NTUserDatFile`""
				Write-Host "$LogPreTag Calling cmd.exe with argument: $ArgumentList"
				$cs.Job_WriteLog("Calling cmd.exe with argument: $ArgumentList")

				$RetValue = (Start-Process -FilePath 'cmd.exe' -ArgumentList $ArgumentList -NoNewWindow -Wait -PassThru).ExitCode
				if ($RetValue -ne 0) {
					Write-Host "$LogPreTag The registry hive for $User could not be mounted. Skipping..."
					$cs.Job_WriteLog("The registry hive for $User could not be mounted. Skipping...")
					continue
				}
			} elseif ($HKUExists) {
				# Do nothing
			}	else {
				Write-Host "$LogPreTag NTUSER.DAT does not exist for $User. Skipping..."
				$cs.Job_WriteLog("NTUSER.DAT does not exist for $User. Skipping...")
				continue
			}

			# Set the registry value
			$RegKeyPathTemp = "$RegistryCoreKey$Path"
			$RegPath = "$Temp_Registry_Root\$RegKeyPathTemp"

			$Value = Get-ItemProperty -Path $RegPath -Name $Name -ErrorAction SilentlyContinue
			if ($Value) {
				if ($Value.$Name -ne $OkValue) {
					Write-Host "$LogPreTag The registry value for $User is already set to $OkValue. Skipping..."
					$cs.Job_WriteLog("The registry value for $User is already set to $OkValue. Skipping...")
					$Result = $true
				}
			}

			try {
				$Result.Handle.Close()
			} catch {}

			Write-Host "$LogPreTag Result: $Result"
			$cs.Job_WriteLog("Result: $Result")

			# Unload the NTUSER.DAT file if it was loaded
			if ($RegistryCoreKey -eq 'TempHive\') {
				[gc]::collect()
				[gc]::WaitForPendingFinalizers()
				Start-Sleep -Seconds 2
				Start-Process -FilePath 'cmd.exe' -ArgumentList '/c reg unload HKLM\TempHive' -NoNewWindow -Wait
			}
		}

		return $Result
	} finally {
		$PathTest = Test-Path -Path 'registry::HKEY_LOCAL_MACHINE\TempHive'
		Write-Host "$LogPreTag PathTest: $PathTest"
		$cs.Job_WriteLog("PathTest: $PathTest")
		if ($PathTest) {
			[gc]::collect()
			[gc]::WaitForPendingFinalizers()
			Start-Sleep -Seconds 2
			Start-Process -FilePath 'cmd.exe' -ArgumentList '/c reg unload HKLM\TempHive' -NoNewWindow -Wait
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


	$Status = Install

	if ($Status) {
		Exit-PSScript 1
	}

	Exit-PSScript 0
} catch {
	$line = $_.InvocationInfo.ScriptLineNumber
	$cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")
	Exit-PSScript $_.Exception.HResult
}