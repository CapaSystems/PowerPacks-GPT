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

# DO NOT CHANGE THESE VARIABLES
$global:Packageroot = $Packageroot
$global:AppName = $AppName
$global:AppRelease = $AppRelease
$global:LogFile = $LogFile
$global:TempFolder = $TempFolder
$global:DllPath = $DllPath
$global:InputObject = $InputObject
$global:DownloadPackage = $true # Set to $true if you want to download the kit folder from the server

$global:RebootAtEnd = $false

###################
#### FUNCTIONS ####
###################
function PreInstall {
  #MARK: PreInstall
  <#
    PreInstall runs before the package download and if $global:DownloadPackage is set to $true.
    Use this function to check for prerequisites, such as disk space, registry keys, or other requirements.
  #>
  $cs.Log_SectionHeader("PreInstall", 'o')
  if (!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:', 10000)) { Exit-PSScript 3333 } # 1500 mb minimum disk space required


}

function Install-CerToLocalMachineRoot {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter()][string]$FriendlyName
  )
  $LogPretag = "Install-CerToLocalMachineRoot:"
  $cs.Job_WriteLog("$LogPretag Path: $Path | FriendlyName: $FriendlyName")

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Certificate file not found: $Path"
  }

  $fileCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Path
  $thumb = ($fileCert.Thumbprint -replace '\s', '').ToUpper()

  $storePath = 'Cert:\LocalMachine\Root'
  $existing = Get-ChildItem $storePath | Where-Object Thumbprint -eq $thumb

  if ($existing) {
    if ($FriendlyName -and $existing.FriendlyName -ne $FriendlyName) {
      try { $existing.FriendlyName = $FriendlyName } catch { $cs.Job_WriteLog("Could not set FriendlyName for $($thumb): $_") }
    }
    $cs.Job_WriteLog("$LogPretag Thumb already present: $thumb")
    return
  } else {
    $cs.Job_WriteLog("$LogPretag Thumb already exists: $thumb")
  }

  $cs.Job_WriteLog("$LogPretag Importing certificate: $Path")
  Import-Certificate -FilePath $Path -CertStoreLocation $storePath | Out-Null

  # Set FriendlyName if desired
  $installed = Get-ChildItem $storePath | Where-Object Thumbprint -eq $thumb
  if ($installed -and $FriendlyName) {
    try { $installed.FriendlyName = $FriendlyName } catch { $cs.Job_WriteLog("Could not set FriendlyName for $($thumb): $_") }
  }

  $cs.Job_WriteLog("Imported certificate $($thumb) from $Path")
}

function Install {
  #MARK: Install
  $cs.Log_SectionHeader("Install", 'o')
  $WorkingDir = Join-Path $global:Packageroot "kit"
  $WorkingDirTemp = "C:\Temp\VS2022"
  $certDir = Join-Path -Path $WorkingDir -ChildPath 'certificates'

  $certs = @(
    @{ Path = Join-Path $certDir 'manifestRootCertificate.cer'; FriendlyName = 'Microsoft Root Certificate Authority 2011' }
    @{ Path = Join-Path $certDir 'manifestCounterSignRootCertificate.cer'; FriendlyName = 'Microsoft Root Certificate Authority 2010' }
    @{ Path = Join-Path $certDir 'vs_installer_opc.RootCertificate.cer'; FriendlyName = 'Microsoft Root Certificate Authority 2010' }
  )
  foreach ($c in $certs) {
    Install-CerToLocalMachineRoot -Path $c.Path -FriendlyName $c.FriendlyName
  }

  if($cs.File_ExistDir($WorkingDirTemp)) {
    $cs.File_DelTree($WorkingDirTemp)
  }

  $cs.File_CopyTree($WorkingDir, $WorkingDirTemp)

  $cs.Job_WriteLog("env:Temp: $env:TEMP")
  $cs.Job_WriteLog("env:TMP: $env:TMP")

  $Command = Join-Path $WorkingDirTemp "vs_setup.exe"
  $Arguments = "--noWeb --wait --quiet --force --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.Azure --add Microsoft.VisualStudio.Workload.Python --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.Data"
  $RetValue = $cs.Shell_Execute($Command, $Arguments, $true, 0, $true, $WorkingDirTemp)
  $cs.Job_WriteLog("Installation returned: $RetValue")
  switch ([int]$RetValue) {
    0 {  }
    3010 {
      $global:RebootAtEnd = $true
      $cs.Job_WriteLog("Need a reboot to finish installation")
    }
    Default {
      Exit-PSScript $RetValue
    }
  }

  $cs.File_DelTree($WorkingDirTemp)
}

function PostInstall {
  #MARK: PostInstall
  $cs.Log_SectionHeader("PostInstall", 'o')

}

##############
#### MAIN ####
##############
try {
  if ($global:InputObject) { $pgkit = "" }else { $pgkit = "kit" }
  Import-Module (Join-Path $global:Packageroot $pgkit "PSlib.psm1") -ErrorAction stop
  $cs = Add-PSDll
  $cs.Job_Start("WS", $global:AppName, $global:AppRelease, $global:LogFile, "INSTALL")

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
  if ($global:RebootAtEnd) {
    $cs.Job_RebootWS("Need a reboot to finish installation")
  }
  Exit-PSScript 0
}
catch {
  $line = $_.InvocationInfo.ScriptLineNumber
  $cs.Job_WriteLog("*****************", "Something bad happend at line $($line): $($_.Exception.Message)")
  Exit-PSScript $_.Exception.HResult
}