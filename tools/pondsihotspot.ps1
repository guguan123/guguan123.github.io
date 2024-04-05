param(
    [switch]$NoDisableAdapter,
    [switch]$EnableHotspot,
    [switch]$DisableHotspot,
    [switch]$EnableAdapter,
    [switch]$DisableAdapter
)

# 参数示例：
# --NoDisableAdapter 或 -NDA: 在关闭WiFi热点时，不禁用无线网络适配器。
# --EnableHotspot 或 -EH: 直接开启WiFi热点。
# --DisableHotspot 或 -DH: 直接关闭WiFi热点。
# --EnableAdapter 或 -EA: 直接启用无线网络适配器。
# --DisableAdapter 或 -DA: 直接禁用无线网络适配器。

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

Function ManageHotspot($enable) {
    try {
        $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
        if ($connectionProfile -eq $null) {
            Write-Host "No internet connection profile found. Please check your network connection."
            exit
        }

        $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile) 

        if ($enable) { 
            Await ($tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]) 
            Write-Host "Network sharing has been enabled."
        } else { 
            Await ($tetheringManager.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]) 
            Write-Host "Network sharing has been disabled."
            if (!$NoDisableAdapter) {
                EnableDisableWiFiAdapter $false
            }
        }
    } catch {
        Write-Host "An error occurred: $_"
    }
}

# Parse command line arguments and take action
if ($EnableAdapter) {
    EnableDisableWiFiAdapter $true
}
elseif ($DisableAdapter) {
    EnableDisableWiFiAdapter $false
}
elseif ($EnableHotspot) {
    EnableDisableWiFiAdapter $true
    ManageHotspot $true
}
elseif ($DisableHotspot) {
    ManageHotspot $false
}
else {
    # Default behavior based on current state if no direct commands are given
    try {
        EnableDisableWiFiAdapter $true
        $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
        if ($connectionProfile -eq $null) {
            Write-Host "No internet connection profile found. Please check your network connection."
            exit
        }
        $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)
        if ($tetheringManager.TetheringOperationalState -eq 1) { 
            ManageHotspot $false
        } else { 
            ManageHotspot $true
        }
    } catch {
        Write-Host "An error occurred: $_"
    }
}