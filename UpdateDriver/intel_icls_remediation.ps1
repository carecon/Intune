# Remediation Script: Update Intel ICLS Client Driver
# $DownloadUrl = "https://catalog.s.download.windowsupdate.com/c/msdownload/update/driver/drvs/2024/07/7998a64c-fd32-42b7-896f-56a80d76dd67_e1aa3a5e4ae4953c6ebcfe3f746bb60c0bf640af.cab"
# 1.75.121
$DownloadUrl = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/driver/drvs/2024/11/5ef23cdc-3295-444f-b181-5eed05f7a16b_81c964a896ee188116b708d0a8de4a4c53bb9f88.cab"
$DestinationPath = "$env:TEMP\IntelICLS_Update.cab"
$ExtractPath = "$env:TEMP\IntelICLS_Driver"
$minVersion = [System.Version]"1.75.121.0"

# Function to download the CAB file
function Download-File {
    param([string]$Url, [string]$Path)
    Invoke-WebRequest -Uri $Url -OutFile $Path
    Write-Output "Driver CAB file downloaded to $Path"
}

# Function to expand the CAB file
function Expand-Cab {
    param([string]$CabPath, [string]$OutputPath)
    if (Test-Path -Path $OutputPath) {
        Remove-Item -Path $OutputPath -Recurse -Force
    }
    New-Item -Path $OutputPath -ItemType Directory -Force
    expand -F:* $CabPath $OutputPath
    Write-Output "CAB file expanded to $OutputPath"
}

# Function to install the driver
function Install-Driver {
    param([string]$DriverPath)
    pnputil.exe /add-driver "$DriverPath" /install
    Write-Output "Driver installed from $DriverPath"
}

# Check the current version of the Intel ICLS Client driver
$driver = Get-WmiObject Win32_PnPSignedDriver | Where-Object {
    $_.DeviceName -like "*Intel(R) ICLS Client*" -and $_.DriverVersion
}

if ($driver) {
    $currentVersion = [System.Version]$driver.DriverVersion
    Write-Output "Current driver version: $currentVersion"

    if ($currentVersion -lt $minVersion) {
        Write-Output "Driver version is below $minVersion. Starting update process..."
        
        # Download, extract, and install driver
        Download-File -Url $DownloadUrl -Path $DestinationPath
        Expand-Cab -CabPath $DestinationPath -OutputPath $ExtractPath
        
        # Find the INF file
        $InfFile = Get-ChildItem -Path $ExtractPath -Filter "*.inf" -Recurse | Select-Object -First 1

        if ($InfFile) {
            Write-Output "Found INF file: $($InfFile.FullName)"
            Install-Driver -DriverPath $InfFile.FullName
            Write-Output "Driver update completed successfully."
        } else {
            Write-Error "No INF file found in extracted CAB contents."
        }
    } else {
        Write-Output "Driver version is compliant. No action needed."
    }
} else {
    Write-Output "Intel ICLS Client driver is not installed. Attempting to install..."

    # Download, extract, and install driver
    Download-File -Url $DownloadUrl -Path $DestinationPath
    Expand-Cab -CabPath $DestinationPath -OutputPath $ExtractPath

    # Find the INF file
    $InfFile = Get-ChildItem -Path $ExtractPath -Filter "*.inf" -Recurse | Select-Object -First 1

    if ($InfFile) {
        Write-Output "Found INF file: $($InfFile.FullName)"
        Install-Driver -DriverPath $InfFile.FullName
        Write-Output "Driver installation completed successfully."
    } else {
        Write-Error "No INF file found in extracted CAB contents."
    }
}


#Remove the old driver
# Define the target driver and version
$targetDriver = "iclsclient.inf"
$maxVersion = [Version]"1.75.121.0"

# Enumerate all drivers using pnputil
Write-Host "Enumerating drivers..." -ForegroundColor Cyan
$driversOutput = pnputil /enum-drivers

# Initialize an array to store driver details
$drivers = @()

# Parse the output for driver details
$currentDriver = @{}
foreach ($line in $driversOutput) {
    if ($line -match "^Published Name:\s+(oem\d+\.inf)$") {
        $currentDriver.PublishedName = $matches[1]
    }
    elseif ($line -match "^Original Name:\s+(\S+)$") {
        $currentDriver.OriginalName = $matches[1]
    }
    elseif ($line -match "^Driver Version:\s+\S+\s+(\d+\.\d+\.\d+\.\d+)$") {
        $currentDriver.DriverVersion = [Version]$matches[1]
    }

    # When all necessary fields are captured, add the driver to the list
    if ($currentDriver.PublishedName -and $currentDriver.OriginalName -and $currentDriver.DriverVersion) {
        $drivers += [PSCustomObject]@{
            PublishedName = $currentDriver.PublishedName
            OriginalName  = $currentDriver.OriginalName
            DriverVersion = $currentDriver.DriverVersion
        }
        $currentDriver = @{} # Reset for the next driver
    }
}

# Filter for the target driver with a version <1.75.121.0
$oldDrivers = $drivers | Where-Object {
    $_.OriginalName -eq $targetDriver -and $_.DriverVersion -lt $maxVersion
}

if ($oldDrivers) {
    Write-Host "Found the following outdated drivers:" -ForegroundColor Yellow
    $oldDrivers | Format-Table -AutoSize

    # Remove each outdated driver
    foreach ($driver in $oldDrivers) {
        Write-Host "Removing driver: $($driver.PublishedName) ($($driver.DriverVersion))" -ForegroundColor Red
        #pnputil /delete-driver $($driver.PublishedName) /uninstall /force
        pnputil /delete-driver $($driver.PublishedName) /uninstall
    }
    Write-Host "Driver removal complete." -ForegroundColor Green
} else {
    Write-Host "No outdated drivers found." -ForegroundColor Green
}
