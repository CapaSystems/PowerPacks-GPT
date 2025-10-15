[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$Packageroot,
  [Parameter(Mandatory=$true)]
  [string]$AppName,
  [Parameter(Mandatory=$true)]
  [string]$AppRelease,
  [Parameter(Mandatory=$true)]
  [string]$LogFile,
  [Parameter(Mandatory=$true)]
  [string]$TempFolder,
  [Parameter(Mandatory=$true)]
  [string]$DllPath,
  [Parameter(Mandatory=$false)]
  [Object]$InputObject=$null
)
###################
#### VARIABLES ####
###################
$global:PlaintextPassword = '' # The BIOS password you want to use when removing. If DecryptionKey and EncryptedPassword are set, this will be ignored.

# The decryption key for the password.
$global:DecryptionKey = @(1, 103, 53, 48, 244, 16, 186, 44, 190, 19, 156, 231, 221, 70, 1, 26, 107, 243, 25, 137, 174, 15, 45, 137, 213,180,83,209,91,154,1,248)
# The encrypted password.
$global:EncryptedPassword = '76492d1116743f0423413b16050a5345MgB8AEgAbwBVAGoAcgBKAGkAKwAzAHMAMQBQARgA4AE4ATABlAE4AMgA5AEEAPQA9AHwANAA4ADkAMgBlADcAMAA5AGMAOAAxAGUAMgBkADUAZgBjADcAZQA3AGUAYgAwAGYANQA4ADYAYQA3AGIAZABhkANQBlADAAZQA3ADEANgBlAGUAYgAzADcANAA3AGIAYQBlAGYANQBkAGIANwBlADMANwA5ADYAYQBhAGUANQBmADkANwADMANwA3ADIAMgA0ADAAZQBkADYAYgA4AGQAMwBiADIAYgA0ADEAZAA4ADUAZQAxADYAYgA5ADQA'

# DO NOT CHANGE THESE VARIABLES
$global:ModuleVersion = '1.8.1'

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
  $cs.Log_SectionHeader("PreInstall",'o')

  $cs.Job_WriteLog('Importing HP.Private module')
	Import-Module (Join-Path $global:Packageroot 'kit' 'HP.Private' ) -Force

	$cs.Job_WriteLog('Importing HP.ClientManagement module')
	Import-Module (Join-Path $global:Packageroot 'kit' 'HP.ClientManagement' $global:ModuleVersion 'HP.UEFI.psm1') -Force
	Import-Module (Join-Path $global:Packageroot 'kit' 'HP.ClientManagement') -Force
}

function Install {
  $cs.Log_SectionHeader("Install",'o')

  if (Get-HPBIOSSetupPasswordIsSet) {
		$cs.Job_WriteLog('BIOS password is set.')

    # Decrypting the password to plaintext
    $cs.Job_WriteLog('Decrypting the password')
		if ($global:DecryptionKey -and $global:EncryptedPassword) {
			$SecureString = $global:EncryptedPassword | ConvertTo-SecureString -Key $global:DecryptionKey
			$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
			$global:PlaintextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
		}

    $cs.Job_WriteLog('Removing BIOS password')
    Clear-HPBIOSSetupPassword -Password $global:PlaintextPassword
	} else {
		$cs.Job_WriteLog('BIOS password is not set')
	}
}

##############
#### MAIN ####
##############
try {
  ##############################################
  #load core PS lib - don't mess with this!
  if ($global:InputObject){$pgkit=""}else{$pgkit="kit"}
  Import-Module (Join-Path $global:Packageroot $pgkit "PSlib.psm1") -ErrorAction stop
  #load Library dll
  $cs=Add-PSDll
  ##############################################

  #Begin
  $cs.Job_Start("WS",$global:AppName,$global:AppRelease,$global:LogFile,"INSTALL")
  $cs.Job_WriteLog("[Init]: Starting package: '" + $global:AppName + "' Release: '" + $global:AppRelease + "'")
  if(!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:',1500)){Exit-PSScript 3333}
  if ($global:DownloadPackage -and $global:InputObject){Start-PSDownloadPackage}

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
}
catch {
    $line = $_.InvocationInfo.ScriptLineNumber
    $cs.Job_WriteLog("*****************","Something bad happend at line $($line): $($_.Exception.Message)")
    Exit-PSScript $_.Exception.HResult
}