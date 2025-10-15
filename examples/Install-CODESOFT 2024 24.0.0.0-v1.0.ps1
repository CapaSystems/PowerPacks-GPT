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
$global:DownloadPackage = $true # Set to $true if you want to download the kit folder from the server

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
  #MARK: PreInstall
  <#
    PreInstall runs before the package download and if $global:DownloadPackage is set to $true.
    Use this function to check for prerequisites, such as disk space, registry keys, or other requirements.
  #>
  $cs.Log_SectionHeader('PreInstall', 'o')
  if (!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:', 1500)) { Exit-PSScript 3333 } # 1500 mb minimum disk space required


}

function Invoke-ShellExecute {
  param (
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $false)]
    [string]$Arguments
  )
  $RetVal = $cs.Shell_Execute($Path, $Arguments)

  if ($RetVal -ne 0) {
    Exit-PSScript $RetVal
  }
}

function Install {
  #MARK: Install
  $cs.Log_SectionHeader('Install', 'o')

  $TempFolder = 'C:\Temp'
  $SetupPrerequisites = Join-Path $global:Packageroot 'kit' 'SetupPrerequisites'

  $cs.File_CreateDir($TempFolder)

  # Enable .NET Framework 3.5 if not already enabled
  $cs.Job_WriteLog('Checking if .NET Framework 3.5 is enabled...')
  if (-not (Get-WindowsOptionalFeature -Online -FeatureName NetFx3).State -eq 'Enabled') {
    $cs.Job_WriteLog('Enabling .NET Framework 3.5...')
    Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart
  }

  # Install Windows6.1-KB2670838-x86
  if ($global:gsWindowsVersion -eq "6.1"){
    $Path = 'C:\Windows\System32\wusa.exe'
    $MSUFile = Join-Path $SetupPrerequisites '{DBFB32E6-820A-4B5D-BD0D-F6878F2A31DB}' 'Windows6.1-KB2670838-x86.msu'
    $Arguments = "`"$MSUFile`" /quiet /norestart"
    Invoke-ShellExecute -Path $Path -Arguments $Arguments
  } else {
    $cs.Job_WriteLog('Skipping Windows6.1-KB2670838-x86 installation as the OS version is not 6.1')
  }

  # Install Windows6.1-KB2670838-x64
  if ($global:gsWindowsVersion -eq "6.1"){
    $Path = 'C:\Windows\System32\wusa.exe'
    $MSUFile = Join-Path $SetupPrerequisites '{DBFB32E6-820A-4B5D-BD0D-F6878F2A31DB}' 'Windows6.1-KB2670838-x64.msu'
    $Arguments = "`"$MSUFile`" /quiet /norestart"
    Invoke-ShellExecute -Path $Path -Arguments $Arguments
  } else {
    $cs.Job_WriteLog('Skipping Windows6.1-KB2670838-x64 installation as the OS version is not 6.1')
  }

  # Install VC 2013 Redist\vcredist_x64.exe
  if (-not ($cs.Reg_ExistKey('HKLM', 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A749D8E6-B613-3BE3-8F5F-045C84EBA29B}'))) {
    $LocalFile = Join-Path $SetupPrerequisites '{49CE81AF-01AB-4DE6-8995-598B5F682F66}' 'vcredist_x64.exe'
    $Arguments = '/q'
    Invoke-ShellExecute -Path $LocalFile -Arguments $Arguments
  } else {
    $cs.Job_WriteLog('Skipping VC 2013 Redist installation as it is already installed')
  }

  # Install VC 2015, 2017 and 2019 Redist\vcredist_x64.exe
  if (-not ($cs.Reg_ExistKey('HKLM', 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'))) {
    $LocalFile = Join-Path $SetupPrerequisites '{86831979-CF5A-4924-9AEB-207707CA8B05}' 'vcredist_x64.exe'
    $Arguments = '/q'
    Invoke-ShellExecute -Path $LocalFile -Arguments $Arguments
  } else {
    $cs.Job_WriteLog('Skipping VC 2015, 2017 and 2019 Redist installation as it is already installed')
  }

  # Install .NET 2.0 SP2 framework
  $ProductType = (Get-CimInstance Win32_OperatingSystem).ProductType
  if ($global:gsWindowsVersion -eq '6.1' -and ($ProductType -eq 2 -or $ProductType -eq 3)) {
    $LocalFile = 'C:\Windows\System32\Dism.exe'
    $Arguments = '/online /enable-feature /featurename:NetFx2-ServerCore /featurename:NetFx2-ServerCore-WOW64'
    Invoke-ShellExecute -Path $LocalFile -Arguments $Arguments
  } else {
    $cs.Job_WriteLog('Skipping .NET 2.0 SP2 framework installation as the OS version is not 6.1 or the product type is not Server')
  }

  # Install AccessDatabaseEngine
  $LocalFile = Join-Path $SetupPrerequisites '{A3AD10F4-2330-4D1B-9C22-ECDFE3E341AE}' "AccessDatabaseEngine.exe"
  $Arguments = '/quiet'
  Invoke-ShellExecute -Path $LocalFile -Arguments $Arguments

  # Install Microsoft.Net 4.8 Full
  if (-not ($cs.Reg_ExistVariable('HKLM', 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', "Release"))) {
    $LocalFile = Join-Path $SetupPrerequisites '{1835D2E6-079C-4A15-9215-52D44083C8C4}' 'ndp48-x86-x64-allos-enu.exe'
    $Arguments = '/q /norestart'
    Invoke-ShellExecute -Path $LocalFile -Arguments $Arguments
  } else {
    $cs.Job_WriteLog('Skipping Microsoft.Net 4.8 Full installation as it is already installed')
  }

  # Install Codesoft
  $TempLog = Join-Path $TempFolder 'codesoft-msi.log'
  $DebugLog = Join-Path $TempFolder 'codesoft-setup.log'
  #$Path = Join-Path $global:Packageroot 'kit' 'Setup.exe'
  $Path = 'C:\Windows\System32\msiexec.exe'
  $MSIPath = Join-Path $global:Packageroot 'kit' 'CODESOFT 2024.msi'
  $MSTPath = Join-Path $global:Packageroot 'kit' '1033.mst'

  $cs.File_DelFile($TempLog)
  #$Arguments = "/s /v`"/qn /norestart TRANSFORMS=\`"$MSTPath\`" /L*v \`"$TempLog\`"`" /debuglog`"$DebugLog`""
  $Arguments = "/i `"$MSIPath`" TRANSFORMS=`"$MSTPath`" /qn /norestart /l*v `"$TempLog`""

  Invoke-ShellExecute -Path $Path -Arguments $Arguments
}

function PostInstall {
  #MARK: PostInstall
  $cs.Log_SectionHeader('PostInstall', 'o')

}

##############
#### MAIN ####
##############
try {
  if ($global:InputObject) { $pgkit = '' }else { $pgkit = 'kit' }
  Import-Module (Join-Path $global:Packageroot $pgkit 'PSlib.psm1') -ErrorAction stop
  $cs = Add-PSDll
  $cs.Job_Start('WS', $global:AppName, $global:AppRelease, $global:LogFile, 'INSTALL')

  $cs.Job_WriteLog("[Init]: Starting package: '" + $global:AppName + "' Release: '" + $global:AppRelease + "'")
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
  if ($global:DownloadPackage -and $global:InputObject) { Start-PSDownloadPackage }
  Install
  PostInstall
  Exit-PSScript 0
} catch {
  $line = $_.InvocationInfo.ScriptLineNumber
  $cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")
  Exit-PSScript $_.Exception.HResult
}