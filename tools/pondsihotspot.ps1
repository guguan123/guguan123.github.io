param(
    [switch]$NoDisableAdapter,         # 禁用无线网络适配器的开关，如果在关闭热点时不想禁用无线网络适配器，则使用此开关
    [switch]$EnableHotspot,            # 启用热点的开关
    [switch]$DisableHotspot,           # 禁用热点的开关
    [switch]$EnableAdapter,            # 启用无线网络适配器的开关
    [switch]$DisableAdapter            # 禁用无线网络适配器的开关
)

# 参数示例：
# --NoDisableAdapter 或 -NDA: 在关闭WiFi热点时，不禁用无线网络适配器。
# --EnableHotspot 或 -EH: 直接开启WiFi热点。
# --DisableHotspot 或 -DH: 直接关闭WiFi热点。
# --EnableAdapter 或 -EA: 直接启用无线网络适配器。
# --DisableAdapter 或 -DA: 直接禁用无线网络适配器。

Add-Type -AssemblyName System.Runtime.WindowsRuntime  # 加载 Windows Runtime 程序集
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

# 等待异步操作完成的函数
Function Await($WinRtTask, $ResultType) { 
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType) 
    $netTask = $asTask.Invoke($null, @($WinRtTask)) 
    $netTask.Wait(-1) | Out-Null 
    $netTask.Result 
} 

# 等待异步操作完成的函数（针对没有返回结果的操作）
Function AwaitAction($WinRtAction) { 
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0] 
    $netTask = $asTask.Invoke($null, @($WinRtAction)) 
    $netTask.Wait(-1) | Out-Null 
} 

# 启用或禁用 WiFi 适配器的函数
Function EnableDisableWiFiAdapter($enable) {
    try {
        $wifiAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*Wireless*' }  # 获取无线网络适配器
        if ($wifiAdapter) {
            if ($enable) {
                Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false  # 启用适配器
            } else {
                Disable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false  # 禁用适配器
            }
        } else {
            Write-Host "Wireless adapter not found."  # 如果未找到适配器则显示消息并退出
            exit
        }
    } catch {
        Write-Host "An error occurred while trying to enable/disable the wireless adapter: $_"  # 处理异常情况
        exit
    }
}

# 启用或禁用热点的函数
Function ManageHotspot($enable) {
    try {
        $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()  # 获取网络连接配置文件
        if ($connectionProfile -eq $null) {
            Write-Host "No internet connection profile found. Please check your network connection."  # 如果找不到连接配置文件，则显示消息并退出
            exit
        }

        $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)  # 创建网络热点管理器

        if ($enable) { 
            Await ($tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])  # 开启热点
            Write-Host "Network sharing has been enabled."  # 显示消息
        } else { 
            Await ($tetheringManager.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])  # 关闭热点
            Write-Host "Network sharing has been disabled."  # 显示消息
            if (!$NoDisableAdapter) {  # 如果未指定禁用适配器，则禁用适配器
                EnableDisableWiFiAdapter $false
                Start-Sleep -Seconds 5  # 等待5秒钟以确保适配器已停用
            }
        }
    } catch {
        Write-Host "An error occurred: $_"  # 处理异常情况
    }
}

# 解析命令行参数并执行相应操作
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
    # 如果没有给出直接的命令，则根据当前状态执行默认操作
    try {
        EnableDisableWiFiAdapter $true
        Start-Sleep -Seconds 5  # 等待5秒钟以确保适配器启用
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