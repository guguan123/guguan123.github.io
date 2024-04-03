Add-Type -AssemblyName System.Runtime.WindowsRuntime 
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0] 

Function Await($WinRtTask, $ResultType) { 
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType) 
    $netTask = $asTask.Invoke($null, @($WinRtTask)) 
    $netTask.Wait(-1) | Out-Null 
    $netTask.Result 
} 

Function AwaitAction($WinRtAction) { 
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0] 
    $netTask = $asTask.Invoke($null, @($WinRtAction)) 
    $netTask.Wait(-1) | Out-Null 
} 

Function EnableDisableWiFiAdapter($enable) {
    try {
        $wifiAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*Wireless*' }
        if ($wifiAdapter) {
            if ($enable) {
                Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
                Start-Sleep -Seconds 5
            } else {
                Start-Sleep -Seconds 5
                Disable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
            }
        } else {
            Write-Host "Wireless adapter not found."
            exit
        }
    } catch {
        Write-Host "An error occurred while trying to enable/disable the wireless adapter: $_"
        exit
    }
}

try {
    # Check and enable WiFi adapter before starting tethering
    EnableDisableWiFiAdapter $true

    $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile() 

    if ($connectionProfile -eq $null) {
        Write-Host "No internet connection profile found. Please check your network connection."
        exit
    }

    $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile) 

    if ($tetheringManager.TetheringOperationalState -eq 1) { 
        Await ($tetheringManager.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]) 
        Write-Host "Network sharing has been disabled."
        # Disable WiFi adapter after stopping tethering
        EnableDisableWiFiAdapter $false
    } else { 
        Await ($tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]) 
        Write-Host "Network sharing has been enabled."
    }
} catch {
    Write-Host "An error occurred: $_"
}