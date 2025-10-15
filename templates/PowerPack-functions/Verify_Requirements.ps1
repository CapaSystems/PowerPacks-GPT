function Verify_Requirements {
    param (
        [Parameter(Mandatory = $false)]
        [int]$OsSystem = 0,
        [Parameter(Mandatory = $false)]
        [string]$DisplayVersion,
        [Parameter(Mandatory = $false)]
        [string]$OsBuild,
        [Parameter(Mandatory = $false)]
        [int]$FreeDiskSpace = 0,
        [Parameter(Mandatory = $false)]
        [int]$Behavior = 1
    )
    $LogPrefix = 'Verify_Requirements:'
    $PassRequirements = $true
    $NotPassedRequirements = @()

    $cs.Job_WriteLog("$LogPrefix OsSystem: $OsSystem | DisplayVersion: $DisplayVersion | OsBuild: $OsBuild | FreeDiskSpace: $FreeDiskSpace | Behavior: $Behavior")

    $CurrentDiskSpace = $cs.Sys_GetFreeDiskSpace()

    $cs.Job_WriteLog("$LogPrefix gsOsSystem: $global:gsOsSystem")
    $cs.Job_WriteLog("$LogPrefix gsDisplayVersion: $global:gsDisplayVersion")
    $cs.Job_WriteLog("$LogPrefix gsOsBuild: $global:gsOsBuild")
    $cs.Job_WriteLog("$LogPrefix Current disk space: $CurrentDiskSpace MB")


    switch ($OsSystem) {
        0 {
            # Do nothing, this is the default case
        }
        1 {
            # Check if the OS is Windows 10
            if ($global:gsOsSystem -like '*Windows 10*') {
                $cs.Job_WriteLog("$LogPrefix Os system is Windows 10")
            } else {
                $cs.Job_WriteLog("$LogPrefix Error: Os system is not Windows 10")
                $PassRequirements = $false
                $NotPassedRequirements += 'Os system is not Windows 10'
            }
        }
        2 {
            # Check if the OS is Windows 11
            if ($global:gsOsSystem -like '*Windows 11*') {
                $cs.Job_WriteLog("$LogPrefix Os system is Windows 11")
            } else {
                $cs.Job_WriteLog("$LogPrefix Error: Os system is not Windows 11")
                $PassRequirements = $false
                $NotPassedRequirements += 'Os system is not Windows 11'
            }
        }
        9999 {
            # Don't care
        }
        default {
            $cs.Job_WriteLog("$LogPrefix Error: Invalid OS system specified: $OsSystem")
            throw "Invalid OS system specified: $OsSystem"
        }
    }

    if ([string]::IsNullOrWhiteSpace($DisplayVersion) -eq $false) {
        if ($global:gsDisplayVersion -like $DisplayVersion) {
            $cs.Job_WriteLog("$LogPrefix Display version $DisplayVersion matches $global:gsDisplayVersion")
        } else {
            $cs.Job_WriteLog("$LogPrefix Error: Display version $DisplayVersion does not match $global:gsDisplayVersion")
            $PassRequirements = $false
            $NotPassedRequirements += "Display version $DisplayVersion does not match $global:gsDisplayVersion"
        }
    }

    if ([string]::IsNullOrWhiteSpace($OsBuild) -eq $false) {
        if ($global:gsOsBuild -like $OsBuild) {
            $cs.Job_WriteLog("$LogPrefix Os build $OsBuild matches $global:gsOsBuild")
        } else {
            $cs.Job_WriteLog("$LogPrefix Error: Os build $OsBuild does not match $global:gsOsBuild")
            $PassRequirements = $false
            $NotPassedRequirements += "Os build $OsBuild does not match $global:gsOsBuild"
        }
    }

    if ($FreeDiskSpace -gt 0) {
        if ($CurrentDiskSpace -ge $FreeDiskSpace) {
            $cs.Job_WriteLog("$LogPrefix Free disk space is sufficient: $CurrentDiskSpace MB available")
        } else {
            $cs.Job_WriteLog("$LogPrefix Error: Free disk space is insufficient: $CurrentDiskSpace MB available, $FreeDiskSpace MB required")
            $PassRequirements = $false
            $NotPassedRequirements += "Free disk space is insufficient: $CurrentDiskSpace MB available, $FreeDiskSpace MB required"
        }
    }

    if ($PassRequirements -eq $true) {
        $cs.Job_WriteLog("$LogPrefix All requirements passed")
    } else {
        $cs.Job_WriteLog("$LogPrefix Not all requirements passed:")
        foreach ($requirement in $NotPassedRequirements) {
            $cs.Job_WriteLog("$LogPrefix - $requirement")
        }

        Exit-PSScript -exitcode $Behavior -exitmessage "$LogPrefix Not all requirements passed"
    }
}