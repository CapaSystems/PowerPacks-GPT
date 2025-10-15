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
function MSI-Remove-By-Name {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,
    [Parameter(Mandatory = $false)]
    [string]$Version = $null
  )
  $LogPreTag = 'MSI-Remove-By-Name:'
  $cs.Job_Writelog("$LogPreTag DisplayName: $($DisplayName) Version: $($Version)")

  $RegPaths = @('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
  #region
  foreach ($RegPath in $RegPaths) {
    $RegKeys = $cs.Reg_EnumKey('HKLM', $RegPath, $true)
    foreach ($Item in $RegKeys) {
      $cs.job_writelog("$LogPreTag Running for $($Item)")

      $RegDisplayName = $cs.Reg_GetString('hklm', "$RegPath\$Item", 'DisplayName')
      if ($RegDisplayName -notlike $DisplayName) {
        $cs.job_writelog("$LogPreTag Skipping $($Item) as DisplayName does not match")
        continue
      }

      if ([string]::IsNullOrEmpty($Version) -eq $false) { 
        if ($cs.Reg_ExistVariable('hklm', "$RegPath\$Item", 'DisplayVersion') -eq $false) {
          $cs.job_writelog("$LogPreTag Skipping $($Item) as DisplayVersion does not exist")
          continue
        }

        $RegVersion = $cs.Reg_GetString('hklm', "$RegPath\$Item", 'DisplayVersion')
        if ([version]$RegVersion -ne [version]$Version) {
          $cs.job_writelog("$LogPreTag Skipping $($Item) as Version does not match")
          continue
        }
      }

      if ($cs.Reg_ExistVariable('hklm', "$RegPath\$Item", 'UninstallString') -eq $false) {
        $cs.job_writelog("$LogPreTag Skipping $($Item) as UninstallString does not exist")
        continue
      }

      $UninstallString = $cs.Reg_GetString('hklm', "$RegPath\$Item", 'UninstallString')
      if ([string]::IsNullOrEmpty($UninstallString)) {
        $cs.job_writelog("$LogPreTag Skipping $($Item) as UninstallString is empty")
        continue
      }
      elseif ($UninstallString -notlike 'msiexec*') {
        $cs.job_writelog("$LogPreTag Skipping $($Item) as UninstallString does not start with msiexec")
        continue
      }

      $cs.job_writelog("$LogPreTag Uninstallating $($Item)")
      $retvalue = $cs.Shell_Execute('msiexec', "/x $item /qn REBOOT=REALLYSUPPRESS")
      $cs.Job_WriteLog("Uninstall of $item completed with status: $retvalue")
      if ($retvalue -ne 0 -or $retvalue -ne 3010) { 
        Exit-PSScript $retvalue 
      }
    }
  }
}

function Install {
  $cs.Log_SectionHeader("Install", 'o')

  MSI-Remove-By-Name -DisplayName "TeamViewer*"
}

##############
#### MAIN ####
##############
try {
  ##############################################
  #load core PS lib - don't mess with this!
  if ($global:InputObject) { $pgkit = "" }else { $pgkit = "kit" }
  Import-Module (Join-Path $global:Packageroot $pgkit "PSlib.psm1") -ErrorAction stop
  #load Library dll
  $cs = Add-PSDll
  ##############################################

  #Begin
  $cs.Job_Start("WS", $global:AppName, $global:AppRelease, $global:LogFile, "INSTALL")
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

  Install
  Exit-PSScript $Error
}
catch {
  $line = $_.InvocationInfo.ScriptLineNumber
  $cs.Job_WriteLog("*****************", "Something bad happend at line $($line): $($_.Exception.Message)")
  Exit-PSScript $_.Exception.HResult
}