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
$global:Language = "da-DK"
$global:GeoId = "0x3d" #https://learn.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations?redirectedfrom=MSDN
$global:InputTip = "0406:00000406" #https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs?view=windows-11

# DO NOT CHANGE THESE VARIABLES
$global:Packageroot = $Packageroot
$global:AppName = $AppName
$global:AppRelease = $AppRelease
$global:LogFile = $LogFile
$global:TempFolder = $TempFolder
$global:DllPath = $DllPath
$global:InputObject = $InputObject
[bool]$global:DownloadPackage = $false # Set to $true if you want to download the kit folder from the server

###################
#### FUNCTIONS ####
###################
function PreInstall {
  $cs.Log_SectionHeader("PreInstall", 'o')

  $Languages = Get-Language
  $cs.Job_WriteLog("Found $($Languages.Count) languages installed")

  foreach ($Language in $Languages) {
    $cs.Job_WriteLog("Language: $($Language.LanguageId)")
  }

  $ExistsLanguage = $Languages.LanguageId.Contains($global:Language)
  $cs.Job_WriteLog("ExistsLanguage: $ExistsLanguage")

  if ($ExistsLanguage -eq $false) {
    Install-Language -Language $global:Language
  }

  <#
  $Jobs = Get-Job
  $cs.Job_WriteLog("Current jobs running: $($Jobs.Count)")

  if ($Jobs.Count -eq 0 -and $ExistsLanguage -eq $false) {
    $cs.Job_WriteLog("Running Install-Language as job")
    Install-Language -Language $global:Language -AsJob

    #PACKAGE_CANCELLED_RETRY_LATER
    Exit-PSScript 3326 -exitmessage "Install is running i the background"
  }
  elseif ($Jobs.Count -gt 0){
    if ($Jobs.Command.Contains("Install-LanguageAsJob")) {
      $cs.Job_WriteLog("Job is currently running to install a language")

      #PACKAGE_CANCELLED_RETRY_LATER
      Exit-PSScript 3326 -exitmessage "The installlation is still running i the background"
    }
  }
  #>
}

function Install {
  $cs.Log_SectionHeader("Install", 'o')

  $cs.Job_WriteLog("Set-SystemPreferredUILanguage")
  try {
    Set-SystemPreferredUILanguage -Language $global:Language
  }
  catch {
    $cs.Job_WriteLog("Set-SystemPreferredUILanguage failed. Error: $($_.Exception.Message)")
    Exit-PSScript $Error
  }

  $cs.Job_WriteLog("Set-WinUILanguageOverride")
  Set-WinUILanguageOverride -Language $global:Language

  $cs.Job_WriteLog("Set-WinUserLanguageList")
  $List = New-WinUserLanguageList -Language $global:Language
  Set-WinUserLanguageList -LanguageList $List -Force

  $cs.Job_WriteLog("Set-WinSystemLocale")
  Set-WinSystemLocale -SystemLocale $global:Language

  $cs.Job_WriteLog("Set-Culture")
  Set-Culture $global:Language

  $cs.Job_WriteLog("Set-WinHomeLocation")
  Set-WinHomeLocation -GeoId $global:GeoId

  $cs.Job_WriteLog("Set-WinDefaultInputMethodOverride")
  Set-WinDefaultInputMethodOverride -InputTip $global:InputTip

  $cs.Job_WriteLog("Copy-UserInternationalSettingsToSystem")
  Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
}

function PostInstall {
  $cs.Log_SectionHeader("PostInstall", 'o')
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

  PreInstall
  Install
  PostInstall
  Exit-PSScript $Error
}
catch {
  $line = $_.InvocationInfo.ScriptLineNumber
  $cs.Job_WriteLog("*****************", "Something bad happend at line $($line): $($_.Exception.Message)")
  Exit-PSScript $_.Exception.HResult
}