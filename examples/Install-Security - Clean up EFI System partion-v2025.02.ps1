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

try {
	##############################################
	#load core PS lib - don't mess with this!
	if ($InputObject) { $pgkit = '' }else { $pgkit = 'kit' }
	Import-Module (Join-Path $Packageroot $pgkit 'PSlib.psm1') -ErrorAction stop
	#load Library dll
	$cs = Add-PsDll
	##############################################

	### Download package kit
	[bool]$global:DownloadPackage = $false

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

	$ScriptError = $Error

	$cs.Log_SectionHeader('Install', 'o')

	# Find systemdisken
	$SystemDisk = Get-Disk | Where-Object { $_.IsSystem -eq $true }
	$cs.Job_WriteLog("Got SystemDisk | Count: $($SystemDisk.count)")

	# Find EFI-partitionen
	$EFIPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object { $_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' }
	$cs.Job_WriteLog("Got EFI Partition | Count: $($EFIPartition.count)")

	# Find det sidste ledige drevbogstav
	$UsedLetters = Get-Volume | Select-Object -ExpandProperty DriveLetter
	$AllLetters = [char[]]([char]'D'..[char]'Z')
	$FreeLetters = $AllLetters | Where-Object { $_ -notin $UsedLetters }
	$cs.Job_WriteLog("Found free letters count: $($FreeLetters.count)")

	$LastFreeLetter = $FreeLetters[-1]
	$cs.Job_WriteLog("LastFreeLetter: $LastFreeLetter")

	# Monter EFI-partitionen til et midlertidigt drevbogstav
	$cs.Job_WriteLog("Mounting EFI to drive letter $LastFreeLetter")
	$EFIPartition | Set-Partition -NewDriveLetter $LastFreeLetter
	$cs.Job_WriteLog("DONE - Mounting EFI to drive letter $LastFreeLetter")

	# Slet HP bin filer
	$PathHP = Join-Path "$($LastFreeLetter):\" 'EFI' 'HP' 'DEVFW'
	$PathFirmware = Join-Path $PathHP 'firmware.bin'
	if (Test-Path $PathFirmware) {
		$cs.Job_WriteLog("Found path: $PathFirmware")
		$cs.Job_WriteLog("Deleting $PathFirmware")
		Remove-Item -Path $PathFirmware -Force
		$cs.Job_WriteLog("DONE - Deleting $PathFirmware")
	} else {
		$cs.Job_WriteLog("Did not find path: $PathFirmware")
		$cs.Job_WriteLog("Deleting all files in $PathHP")
		$Items = Get-ChildItem -Path $PathHP
		foreach ($Item in $Items) {
			try {
				$cs.Job_WriteLog("Deleting file: $($Item.FullName)")
				$Item | Remove-Item -Force
			} catch {
				$cs.Job_WriteLog("Failed to remove file: $($Item.FullName) | Error: $($_.Exception.HResult)")
			}
		}
		$cs.Job_WriteLog("DONE - Deleting all files in $PathHP")
	}

	# Få oplysninger om størrelsen og den frie plads
	$EFIInfo = Get-Volume -DriveLetter $LastFreeLetter
	$Size = [math]::Round($EFIInfo.Size / 1MB, 2)
	$FreeSpace = [math]::Round($EFIInfo.SizeRemaining / 1MB, 2)


	# Udskriv oplysningerne
	$cs.Job_WriteLog("EFI-partitionen Size: $Size MB")
	$cs.Job_WriteLog("EFI-partitionen Freespace: $FreeSpace MB")


	# Gem værdierne i registreringsdatabasen
	$RegistryPath = 'HKLM:\SOFTWARE\CapaSystems\CapaInstaller\Custom\EFI'
	if (-not (Test-Path $RegistryPath)) {
		$cs.Job_WriteLog("Registry path does not exist | Path: $RegistryPath")
		$cs.Job_WriteLog("Creating registry path: $RegistryPath")
		New-Item -Path $RegistryPath -Force
		$cs.Job_WriteLog("DONE - Creating registry path: $RegistryPath")
	}
	$cs.Job_WriteLog("Setting path: $RegistryPath | Name: EFI Size MB | Value: $Size")
	Set-ItemProperty -Path $RegistryPath -Name 'EFI Size MB' -Value $Size
	$cs.Job_WriteLog("Setting path: $RegistryPath | Name: EFI FreeSpace MB | Value: $FreeSpace")
	Set-ItemProperty -Path $RegistryPath -Name 'EFI FreeSpace MB' -Value $FreeSpace


	# Frigiv drevbogstavet
	$cs.Job_WriteLog("Unmounting partition $LastFreeLetter")
	$EFIPartition | Remove-PartitionAccessPath -AccessPath "$($LastFreeLetter):\"
	$cs.Job_WriteLog("DONE - Unmounting partition $LastFreeLetter")

	Exit-PSScript $ScriptError

} catch {
	$cs.Log_SectionHeader('Catch', 'o')

	$line = $_.InvocationInfo.ScriptLineNumber
	$cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")

	$cs.Job_WriteLog("Unmounting partition $LastFreeLetter")
	$EFIPartition | Remove-PartitionAccessPath -AccessPath "$($LastFreeLetter):\"
	$cs.Job_WriteLog("DONE - Unmounting partition $LastFreeLetter")

	Exit-PSScript $_.Exception.HResult
}
