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

function PSAppDeployToolkit {
  param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType = 'Install',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [System.String]$DeployMode = 'Silent',

    [Parameter(Mandatory = $false)]
    [bool]$AllowRebootPassThru,

    [Parameter(Mandatory = $false)]
    [bool]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [bool]$DisableLogging,

    [Parameter(Mandatory = $false)]
    [ValidateSet('x86', 'x64')]
    [System.String]$Architecture = 'x64',

    [Parameter(Mandatory = $false)]
    [string]$Codehandle = ''
  )
  $LogPreTag = 'PSAppDeployToolkit:'
  $cs.Job_Writelog("$LogPreTag DeploymentType: $($DeploymentType) | DeployMode: $($DeployMode) | AllowRebootPassThru: $($AllowRebootPassThru) | TerminalServerMode: $($TerminalServerMode) | DisableLogging: $($DisableLogging) | Architecture: $($Architecture)")

  try {
    #region Archive old logs
    $ConfigFile = Join-Path $Packageroot 'Config' 'config.psd1'
    $cs.Job_WriteLog("$LogPreTag Config file: $ConfigFile")

    if (-not (Test-Path -Path $ConfigFile)) {
      $cs.Job_WriteLog("$LogPreTag Config file does not exist: $ConfigFile")
      throw "Config file does not exist: $ConfigFile"
    }

    $cs.Job_WriteLog("$LogPreTag Importing configuration file: $ConfigFile")
    $Config = Import-PowerShellDataFile -Path $ConfigFile -SkipLimitCheck
    $cs.Job_WriteLog("$LogPreTag Configuration file imported successfully.")

    $cs.Job_WriteLog("$LogPreTag Archiving old logs")
    if ($global:Debug -eq $false) {
      $cs.Job_DisableLog()
    }

    $cs.Job_WriteLog("$LogPreTag Collecting paths for archiving logs")
    $Paths = New-Object Collections.Generic.List[String]
    $Paths.Add($Config.MSI.LogPath)
    $cs.Job_WriteLog("$LogPreTag Config.MSI.LogPath: $($Config.MSI.LogPath)")
    $Paths.Add($Config.MSI.LogPathNoAdminRights)
    $cs.Job_WriteLog("$LogPreTag Config.MSI.LogPathNoAdminRights: $($Config.MSI.LogPathNoAdminRights)")
    $Paths.Add($Config.Toolkit.LogPath)
    $cs.Job_WriteLog("$LogPreTag Config.Toolkit.LogPath: $($Config.Toolkit.LogPath)")
    $Paths.Add($Config.Toolkit.LogPathNoAdminRights)
    $cs.Job_WriteLog("$LogPreTag Config.Toolkit.LogPathNoAdminRights: $($Config.Toolkit.LogPathNoAdminRights)")

    $PSADTLogPath = 'C:\Windows\Logs\Invoke-AppDeployToolkit.exe'
    $Paths.Add($PSADTLogPath)
    $cs.Job_WriteLog("$LogPreTag PSADT Log Path: $PSADTLogPath")

    foreach ($Path in $Paths) {
      if (-not (Test-Path -Path $Path)) {
        $cs.Job_WriteLog("$LogPreTag Path does not exist: $Path")
        continue
      }

      $Files = Get-ChildItem -Path "$Path\*.log" -Force
      $cs.Job_WriteLog("$LogPreTag Found $($Files.Count) log files in $Path")

      $ArchivePath = Join-Path $Path 'Archive'

      foreach ($File in $Files) {
        $DestinationPath = Join-Path $ArchivePath $File.Name
        $cs.File_CopyFile($File.FullName, $DestinationPath, $true)
        $cs.File_DelFile($File.FullName)
      }
    }

    $cs.Job_EnableLog()
    #endregion

    #region Install App
    if ($Architecture -ne 'x64') {
      $ProcessArguments = '/32'
    } else {
      # Uses PowerShell Core if available
      # TODO: Add when 4.1.0 is released
      #$ProcessArguments = '/Core'

      $ProcessArguments = ''
    }

    $ProcessArguments = "$ProcessArguments -DeploymentType $DeploymentType -DeployMode $DeployMode"

    if ($AllowRebootPassThru) {
      $ProcessArguments = "$ProcessArguments -AllowRebootPassThru"
    }
    if ($TerminalServerMode) {
      $ProcessArguments = "$ProcessArguments -TerminalServerMode"
    }
    if ($DisableLogging) {
      $ProcessArguments = "$ProcessArguments -DisableLogging"
    }

    $ProcessPath = Join-Path $Packageroot 'Invoke-AppDeployToolkit.exe'

    $ExitCode = $cs.Shell_Execute($ProcessPath, $ProcessArguments)
    $cs.Job_WriteLog("$LogPreTag The installation of $ProcessPath returned: $ExitCode")
    #endregion

    #region Import logs that are created by the toolkit
    $cs.Job_WriteLog("$LogPreTag Importing logs from the toolkit")
    $Files = @()
    foreach ($Path in $Paths) {
      if (-not (Test-Path -Path $Path)) {
        continue
      }

      $Files += Get-ChildItem -Path "$Path\*.log" -Force
    }
    $UniqueFiles = $Files | Select-Object -Unique
    $cs.Job_WriteLog("$LogPreTag Found $($UniqueFiles.Count) unique log files in the toolkit paths")

    foreach ($File in $UniqueFiles) {
      $DestinationPath = Join-Path $global:AppLogFolder $File.Name
      $cs.File_CopyFile($File.FullName, $DestinationPath, $true)
    }
    #endregion

    # https://psappdeploytoolkit.com/docs/reference/exit-codes
    switch ($ExitCode) {
      0 {
        $cs.Job_WriteLog("$LogPreTag The installation was successful")
      }
      60001 {
        $cs.Job_WriteLog("$LogPreTag An error occurred in Invoke-AppDeployToolkit.ps1. Check your script syntax use.")
      }
      60002 {
        $cs.Job_WriteLog("$LogPreTag Error when running Start-ADTProcess function.")
      }
      60003 {
        $cs.Job_WriteLog("$LogPreTag Administrator privileges required for Start-ADTProcessAsUser function.")
      }
      60004 {
        $cs.Job_WriteLog("$LogPreTag Failure when loading .NET WinForms / WPF Assemblies.")
      }
      60005 {
        $cs.Job_WriteLog("$LogPreTag Failure when displaying the Blocked Application dialog.")
      }
      60006 {
        $cs.Job_WriteLog("$LogPreTag AllowSystemInteractionFallback option was not selected in the config XML file, so toolkit will not fall back to SYSTEM context with no interaction.")
      }
      60007 {
        $cs.Job_WriteLog("$LogPreTag Invoke-AppDeployToolkit.ps1 failed to dot source AppDeployToolkitMain.ps1 either because it could not be found or there was an error while it was being dot sourced.")
      }
      60008 {
        $cs.Job_WriteLog("$LogPreTag The -UserName parameter in the Start-ADTProcessAsUser function has a default value that is empty because no logged in users were detected when the toolkit was launched.")
      }
      60009 {
        $cs.Job_WriteLog("$LogPreTag Invoke-AppDeployToolkit.exe failed before PowerShell.exe process could be launched.")
      }
      60010 {
        $cs.Job_WriteLog("$LogPreTag Invoke-AppDeployToolkit.exe failed before PowerShell.exe process could be launched.")
      }
      60011 {
        $cs.Job_WriteLog("$LogPreTag Invoke-AppDeployToolkit.exe failed to execute the PowerShell.exe process.")
      }
      60012 {
        $cs.Job_WriteLog("$LogPreTag A UI prompt can time out or the user may defer the installation, which produces exit code 60012.")
        #Exit-PSScript 3326
      }
      60013 {
        $cs.Job_WriteLog("$LogPreTag If Start-ADTProcess function captures an exit code out of range for int32 then return this custom exit code.")
      }
      default {			}
    }

    if ([string]::IsNullOrEmpty($Codehandle) -eq $false) {
      $cs.Job_WriteLog("$LogPrefix A Codehandle has been specified with value: $Codehandle")

      $Codehandle = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Codehandle))
      $CodehandleObj = ConvertFrom-Json $Codehandle

      $ExistCode = $CodehandleObj | Where-Object { $_.code -eq $ExitCode }
      if ([string]::IsNullOrEmpty($ExistCode)) {
        $cs.Job_WriteLog("$LogPrefix The exit code $ExitCode is not in the list of handled codes")
        Exit-PSScript $ExitCode
      } else {
        $CodehandleId = $ExistCode.option.id

        $cs.Job_WriteLog("$LogPrefix The exit code $ExitCode is in the list of handled codes. Action to take: $CodehandleId")

        switch ($CodehandleId) {
          'success' {
            $cs.Job_WriteLog("$LogPrefix The installation was successful")
            return
          }
          'notcompliant' {
            $cs.Job_WriteLog("$LogPrefix The installation was not compliant")
            Exit-PSScript 3327
          }
          'failure' {
            $cs.Job_WriteLog("$LogPrefix The installation failed with exit code $ExitCode")
            Exit-PSScript $ExitCode
          }
          'retrylater' {
            $cs.Job_WriteLog("$LogPrefix The installation failed with exit code $ExitCode, but will be retried later")
            Exit-PSScript 3326
          }
          default {
            $cs.Job_WriteLog("$LogPrefix Option not handled: $CodehandleId")
            Exit-PSScript $ExitCode
          }
        }
      }
    } else {
      $cs.Job_WriteLog("$LogPrefix No Codehandle specified. Exit code: $ExitCode")

      if ($ExitCode -ne 0) {
        $cs.Job_WriteLog("$LogPrefix The installation failed with exit code $ExitCode")
        Exit-PSScript $ExitCode
      }
    }
  } finally {
    $cs.Job_EnableLog()
  }
}

try {
  ##############################################
  #load core PS lib - don't mess with this!
  if ($InputObject) { $pgkit = '' }else { $pgkit = 'kit' }
  Import-Module (Join-Path $Packageroot $pgkit 'PSlib.psm1') -ErrorAction stop
  #load Library dll
  $cs = Add-PSDll
  ##############################################

  ### Download package kit
  [bool]$global:DownloadPackage = $true

  #Begin
  $cs.Job_Start('WS', $AppName, $AppRelease, $LogFile, 'INSTALL')
  $cs.Job_WriteLog("[Init]: Starting package: '" + $AppName + "' Release: '" + $AppRelease + "'")
  if (!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:', 1500)) { Exit-PSScript 3333 }
  if ($global:DownloadPackage -and $InputObject) { Start-PSDownloadPackage }

  $cs.Job_WriteLog("[Init]: `$PackageRoot:` '" + $Packageroot + "'")
  $cs.Job_WriteLog("[Init]: `$AppName:` '" + $AppName + "'")
  $cs.Job_WriteLog("[Init]: `$AppRelease:` '" + $AppRelease + "'")
  $cs.Job_WriteLog("[Init]: `$LogFile:` '" + $LogFile + "'")
  $cs.Job_WriteLog("[Init]: `$global:AppLogFolder:` '" + $global:AppLogFolder + "'")
  $cs.Job_WriteLog("[Init]: `$TempFolder:` '" + $TempFolder + "'")
  $cs.Job_WriteLog("[Init]: `$DllPath:` '" + $DllPath + "'")
  $cs.Job_WriteLog("[Init]: `$global:DownloadPackage`: '" + $global:DownloadPackage + "'")
  $cs.Job_WriteLog("[Init]: `$global:PSLibVersion`: '" + $global:PSLibVersion + "'")

  $Packageroot = Join-Path $Packageroot 'kit'
  $CodeHandlePath = Join-Path $Packageroot 'Codehandle.json'
  $CodeHandleJson = Get-Content -Path $CodeHandlePath -Raw
  $CodeHandleBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($CodeHandleJson))


  $Splat = @{
    DeploymentType      = 'Install'
    DeployMode          = 'Silent'
    AllowRebootPassThru = $false
    TerminalServerMode  = $false
    DisableLogging      = $false
    Architecture        = 'x64'
    Codehandle          = $CodeHandleBase64
  }
  PSAppDeployToolkit @Splat

  Exit-PSScript 0

} catch {
  $line = $_.InvocationInfo.ScriptLineNumber
  $cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")
  Exit-PSScript $_.Exception.HResult
}
