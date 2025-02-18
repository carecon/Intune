# Detection Script: Intel ICLS Client Driver Version Check

# Define minimum required version
$minVersion = [System.Version]"1.75.121.0"

# Get all Intel ICLS drivers installed
$driver = Get-WmiObject Win32_PnPSignedDriver | Where-Object {
    $_.DeviceName -like "*Intel(R) ICLS Client*" -and $_.DriverVersion
}

# Check the version
if ($driver) {
    $currentVersion = [System.Version]$driver.DriverVersion

    if ($currentVersion -lt $minVersion) {
        Write-Output "Intel ICLS Client driver version is $currentVersion, which is below or equal to $minVersion."
        exit 1 # Non-compliant
    } else {
        Write-Output "Intel ICLS Client driver version is $currentVersion, which is compliant."
        exit 0 # Compliant
    }
} else {
    Write-Output "Intel ICLS Client driver is not installed."
    exit 1 # Non-compliant as the driver is missing
}
