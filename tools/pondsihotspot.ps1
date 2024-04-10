# by https://github.com/guguan123

param(
    [switch]$NoAdministratorRequired,   # 忽略权限检测
    [switch]$Help,                      # 获取帮助
    [switch]$CheckAdapterStatus,        # 检查WiFi网卡状态
    [switch]$CheckHotspotStatus,        # 查看WiFi热点状态
    [switch]$EnableHotspot,             # 启用热点的开关
    [switch]$DisableHotspot,            # 禁用热点的开关
    [switch]$EnableAdapter,             # 启用无线网络适配器的开关
    [switch]$DisableAdapter             # 禁用无线网络适配器的开关
)


# 参数示例：
# -EnableHotspot: 直接开启WiFi热点。
# -DisableHotspot: 直接关闭WiFi热点。
# -EnableAdapter: 直接启用无线网络适配器。
# -DisableAdapter: 直接禁用无线网络适配器。
# -NoAdministratorRequired: 忽略管理员权限检测运行脚本。
# -help: 获取帮助
# -CheckAdapterStatus: 检查WiFi网卡状态
# -CheckHotspotStatus: 查看WiFi热点状态
#
# 如果无输入参数则自动开/关热点


# 获取当前操作系统版本信息
$osVersion = [System.Environment]::OSVersion.Version
# 定义 Windows 10 的最低版本
$win10Version = New-Object System.Version "10.0"
if ($osVersion -lt $win10Version) {
    Write-Warning "System versions lower than Windows 10!"
}
# 获取当前PowerShell版本信息（暂不需要）
#$psMajorVersion = $PSVersionTable.PSVersion.Major
#if ($psMajorVersion -lt 7) {
#    Write-Warning "PowerShell version is $($PSVersionTable.PSVersion). You are using a version lower than PowerShell 7!"
#}

# 解析命令行参数并执行相应操作
# 检查参数是否包含帮助开关
if ($Help -or $args -contains "-?") {
    # 获取当前脚本文件的完整路径
    $scriptPath = $MyInvocation.MyCommand.Name
    # 使用Split-Path获取文件名部分
    $scriptFileName = Split-Path -Path $scriptPath -Leaf
    # Output help information
    Write-Host "Usage: $($scriptFileName) [options]"
    Write-Host ""
    Write-Host "-EnableHotspot"
    Write-Host "    Directly enables WiFi hotspot."
    Write-Host ""
    Write-Host "-DisableHotspot"
    Write-Host "    Directly disables WiFi hotspot."
    Write-Host ""
    Write-Host "-EnableAdapter"
    Write-Host "    Directly enables the wireless network adapter."
    Write-Host ""
    Write-Host "-DisableAdapter"
    Write-Host "    Directly disables the wireless network adapter."
    Write-Host ""
    Write-Host "-NoAdministratorRequired"
    Write-Host "    Runs the script ignoring administrator privileges."
    Write-Host ""
    Write-Host "$($scriptFileName) -Help | -?"
    Write-Host ""
    Write-Host "If no input parameters are provided, it automatically toggles the hotspot."
    Return
}
# 检查WiFi网卡状态的逻辑（该功能未完善！）
elseif ($CheckAdapterStatus) {
    $wifiAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*Wireless*' }
    if ($wifiAdapters.Count -gt 0) {
        foreach ($adapter in $wifiAdapters) {
            $status = if ($adapter.Status -eq "Up") { "Enabled" } else { "Disabled" }
            Write-Host "Adapter Name: $($adapter.Name), Status: $status"
        }
    } else {
        Write-Host "No wireless network adapter found."
    }
    exit
}

# 获取当前用户的 Windows 身份验证
$WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
# 创建 Windows 身份验证的 WindowsPrincipal 对象
$WindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($WindowsIdentity)
# 检查用户是否属于管理员组
$IsAdmin = $WindowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$IsAdmin) {
    Write-Error "The script requires administrator privileges to run!"
    if (!$NoAdministratorRequired -or $args -contains "-NAR") {
        Return
    }
}

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
        }
    } catch {
        Write-Host "An error occurred: $_"  # 处理异常情况
    }
}

if ($CheckHotspotStatus) {  # 该功能未完善！
    # 查看WiFi热点状态的逻辑
    $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
    if ($connectionProfile -eq $null) {
        Write-Host "No internet connection profile found. Please check your network connection."
        exit
    }
    $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)
    $tetheringOperationalState = if ($tetheringManager.TetheringOperationalState -eq 1) { "On" } else { "Off" }
    $tetheringConfiguration = $tetheringManager.GetCurrentTetheringConfiguration()
    $ssid = $tetheringConfiguration.SSID
    $passphrase = "Not accessible through API" # Windows API does not expose the hotspot password for security reasons
    Write-Host "Hotspot Status: $($tetheringOperationalState), SSID: $($ssid), Password: $($passphrase)"
    exit
}
elseif ($EnableAdapter) {
    EnableDisableWiFiAdapter $true
}
elseif ($EnableHotspot) {
    if ($EnableAdapter) {
        Start-Sleep -Seconds 5  # 如果还附带有"-EnableAdapter"开关就等待5秒钟以确保适配器启用
    }
    ManageHotspot $true
}
elseif ($DisableHotspot) {
    ManageHotspot $false
}
elseif ($DisableAdapter) {
    EnableDisableWiFiAdapter $false
}
else {
    # 如果没有给出直接的命令，则根据当前状态执行默认操作
    try {
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
# SIG # Begin signature block
# MIIgmgYJKoZIhvcNAQcCoIIgizCCIIcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcjyPMr8/5mxBgLH2rF+GpOZc
# MYCgghrPMIIDvzCCAqegAwIBAgIIfKPu4huhs+YwDQYJKoZIhvcNAQELBQAwZDEL
# MAkGA1UEBhMCQ04xEDAOBgNVBAgTB0d1YW5nWGkxDjAMBgNVBAcTBVl1TGluMRIw
# EAYDVQQKEwlHdUd1YW4xMjMxHzAdBgkqhkiG9w0BCQEWEGd1Z3VhbjEyM0BxcS5j
# b20wHhcNMjQwNDA1MDM1MjAwWhcNNDkwNDA1MDM1MjAwWjBdMQswCQYDVQQGEwJD
# TjEQMA4GA1UECBMHR3VhbmdYaTEOMAwGA1UEBxMFWXVMaW4xEjAQBgNVBAoTCUd1
# R3VhbjEyMzEYMBYGCSqGSIb3DQEJARYJZ3VndWFuMTIzMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAuR7aM+RsmN7OkNJn0lB2aZ3NTqqU94DO3hxx3XUB
# hQPdLdxIurCr53mYG580F6v6F9xzGgh9krb4MhXwuG0Qo0lXWo3tpHcrJS7j8cIn
# wcdnchB3WKHytVFzJN2+xzIdb21yP0FbEnn5AswGxdL5bKRfqQXJ5HfCalaFFg/5
# SlJG38agxgMy4iybeKuCcGDyZ9abDMkZoiDMMxPgCRgIhIjrZnL5JLQGBBVWTHxV
# 7ykImxC3QK5UAYdul5dgNNjkhw8L9bf2aRhr3PqeSHf1+vzEz2jffWhkDG1MUPdn
# e9NOrR5R86kBCPSWShYhgXL5V/D2RKqS+nxylwaxgnSm3wIDAQABo3wwejAJBgNV
# HRMEAjAAMAsGA1UdDwQEAwIEsDBgBgNVHSUEWTBXBggrBgEFBQcDAgYIKwYBBQUH
# AwMGCCsGAQUFBwMEBgorBgEEAYI3AgEVBgorBgEEAYI3AgEWBggrBgEFBQcDFQYJ
# KoZIhvcvAQEFBgorBgEEAYI3CgMMMA0GCSqGSIb3DQEBCwUAA4IBAQCf4Wy7d2JL
# l0+WMWtl8PNJ8dTkqJaZWB6AssXa7TPK34K3wkXvDw4/7nT/+qmuQsq5EkMXiU7L
# gCOel6ZBbLHnWmrwRxdTKzGRDz124Pa0JJMAI+oQWEy7rRTE6I1t7zZwSknXXMtj
# wxvTiGUU39+8UxhqKLWIfKmeV0ETxUdGNeZa/XLxpDEoP+tgLBcjNxS8/00vu3NX
# 7L5s0KrqzDrltLtMwwExvopBYvK6M9RMD5ZZQjz2/hvz3aMuaLP0SaxpR2xtee9k
# vY4U89+WDtLEQ3YZnm9nkCAf2OCbkGBI0XuVOS5XQZ+027UKd4ZdcAcOUUSyZef7
# 9VC4t2kD9/ywMIID/zCCAuegAwIBAgIIP6ep/yxWKNwwDQYJKoZIhvcNAQELBQAw
# FDESMBAGA1UEAxMJUEMyNDEyLUNBMCAXDTI0MDQwNTAzMjYwMFoYDzIwNTQwNDA1
# MDMyNjAwWjBkMQswCQYDVQQGEwJDTjEQMA4GA1UECBMHR3VhbmdYaTEOMAwGA1UE
# BxMFWXVMaW4xEjAQBgNVBAoTCUd1R3VhbjEyMzEfMB0GCSqGSIb3DQEJARYQZ3Vn
# dWFuMTIzQHFxLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALke
# 2jPkbJjezpDSZ9JQdmmdzU6qlPeAzt4ccd11AYUD3S3cSLqwq+d5mBufNBer+hfc
# cxoIfZK2+DIV8LhtEKNJV1qN7aR3KyUu4/HCJ8HHZ3IQd1ih8rVRcyTdvscyHW9t
# cj9BWxJ5+QLMBsXS+WykX6kFyeR3wmpWhRYP+UpSRt/GoMYDMuIsm3irgnBg8mfW
# mwzJGaIgzDMT4AkYCISI62Zy+SS0BgQVVkx8Ve8pCJsQt0CuVAGHbpeXYDTY5IcP
# C/W39mkYa9z6nkh39fr8xM9o331oZAxtTFD3Z3vTTq0eUfOpAQj0lkoWIYFy+Vfw
# 9kSqkvp8cpcGsYJ0pt8CAwEAAaOCAQEwgf4wDwYDVR0TAQH/BAUwAwEB/zAdBgNV
# HQ4EFgQUGGUGzIug0FeLt2NVJOVW3J27gtEwHwYDVR0jBBgwFoAUIwKCUEDFPOOA
# GOndGAsNJGoMsN4wQQYDVR0fBDowODA2oDSgMoYwZmlsZTovLy8vV0lOLUxhcHRv
# cDI0MTIvQ2VydEVucm9sbC9QQzI0MTItQ0EuY3JsMFsGCCsGAQUFBwEBBE8wTTBL
# BggrBgEFBQcwAoY/ZmlsZTovLy8vV0lOLUxhcHRvcDI0MTIvQ2VydEVucm9sbC9X
# SU4tTGFwdG9wMjQxMl9QQzI0MTItQ0EuY3J0MAsGA1UdDwQEAwIBhjANBgkqhkiG
# 9w0BAQsFAAOCAQEAppVuWmB5v39TjKiIwGWXv/jSPO+92e5yhfXoOWnxICL1lp3X
# LigYB5nYa+cuingBRWEa0ztPjPHPjgG70CeEx/miZJkPw920YI1yGsBsIJDzR98b
# tr2xOvwfKcFU4+r02MfxtXq/yv4KjDc3SVn8SneRgVkZGR0L5epByjjP/joQ+HkG
# Q7jQYYE+vUOIbZ5reZtMMd1du5rmruUJQ0pyDePVejAf5CnFHpKwlzsjY3S350Pv
# TF7CIJAtngOrPAHuweYi9HtRXSAgv2kEvJrKL7bOFmwppNKWa/LK6fVBVfedBNWL
# OwV8I0Yc3sPMCq0T53SDGzVIpkc9FSZ/wg7NXDCCBY0wggR1oAMCAQICEA6bGI75
# 0C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAwMDAw
# MFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGln
# aUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2uexuE
# DcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNw
# wrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs0
# 6wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e
# 5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtV
# gkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8oU85
# tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m1O+S
# kjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y1Yxw
# LEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkliWzl
# DlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFr
# b7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOCATow
# ggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/nupiu
# HA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQE
# AwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqgOKA2
# hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290
# Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/
# Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNK
# ei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0SbQyHr
# lnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4
# oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxYoA5A
# Y8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0VysGMNN
# n3O3AamfV6peKOK5lDCCBq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJ
# KoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQg
# VHJ1c3RlZCBSb290IEc0MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVow
# YzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQD
# EzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGlu
# ZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklR
# VcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54P
# Mx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupR
# PfDWVtTnKC3r07G1decfBmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvo
# hGS0UvJ2R/dhgxndX7RUCyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV
# 5huowWR0QKfAcsW6Th+xtVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYV
# VSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6i
# c/rnH1pslPJSlRErWHRAKKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/Ci
# PMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5
# K6jzRWC8I41Y99xh3pP+OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oi
# qMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuld
# yF4wEr1GnrXTdrnSDmuZDNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAG
# AQH/AgEAMB0GA1UdDgQWBBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAW
# gBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAww
# CgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkq
# hkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvH
# UF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0M
# CIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCK
# rOX9jLxkJodskr2dfNBwCnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rA
# J4JErpknG6skHibBt94q6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZ
# xhOACcS2n82HhyS7T6NJuXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScs
# PT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1M
# rfvElXvtCl8zOYdBeHo46Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXse
# GYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWY
# MbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYp
# hwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPww
# ggbCMIIEqqADAgECAhAFRK/zlJ0IOaa/2z9f5WEWMA0GCSqGSIb3DQEBCwUAMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwHhcNMjMwNzE0MDAwMDAwWhcNMzQxMDEzMjM1OTU5WjBIMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xIDAeBgNVBAMTF0RpZ2lDZXJ0IFRp
# bWVzdGFtcCAyMDIzMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAo1NF
# hx2DjlusPlSzI+DPn9fl0uddoQ4J3C9Io5d6OyqcZ9xiFVjBqZMRp82qsmrdECmK
# HmJjadNYnDVxvzqX65RQjxwg6seaOy+WZuNp52n+W8PWKyAcwZeUtKVQgfLPywem
# MGjKg0La/H8JJJSkghraarrYO8pd3hkYhftF6g1hbJ3+cV7EBpo88MUueQ8bZlLj
# yNY+X9pD04T10Mf2SC1eRXWWdf7dEKEbg8G45lKVtUfXeCk5a+B4WZfjRCtK1ZXO
# 7wgX6oJkTf8j48qG7rSkIWRw69XloNpjsy7pBe6q9iT1HbybHLK3X9/w7nZ9MZll
# R1WdSiQvrCuXvp/k/XtzPjLuUjT71Lvr1KAsNJvj3m5kGQc3AZEPHLVRzapMZoOI
# aGK7vEEbeBlt5NkP4FhB+9ixLOFRr7StFQYU6mIIE9NpHnxkTZ0P387RXoyqq1AV
# ybPKvNfEO2hEo6U7Qv1zfe7dCv95NBB+plwKWEwAPoVpdceDZNZ1zY8SdlalJPrX
# xGshuugfNJgvOuprAbD3+yqG7HtSOKmYCaFxsmxxrz64b5bV4RAT/mFHCoz+8LbH
# 1cfebCTwv0KCyqBxPZySkwS0aXAnDU+3tTbRyV8IpHCj7ArxES5k4MsiK8rxKBMh
# SVF+BmbTO77665E42FEHypS34lCh8zrTioPLQHsCAwEAAaOCAYswggGHMA4GA1Ud
# DwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMI
# MCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6
# FtltTYUvcyl2mi91jGogj57IbzAdBgNVHQ4EFgQUpbbvE+fvzdBkodVWqWUxo97V
# 40kwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNybDCB
# kAYIKwYBBQUHAQEEgYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBYBggrBgEFBQcwAoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNy
# dDANBgkqhkiG9w0BAQsFAAOCAgEAgRrW3qCptZgXvHCNT4o8aJzYJf/LLOTN6l0i
# kuyMIgKpuM+AqNnn48XtJoKKcS8Y3U623mzX4WCcK+3tPUiOuGu6fF29wmE3aEl3
# o+uQqhLXJ4Xzjh6S2sJAOJ9dyKAuJXglnSoFeoQpmLZXeY/bJlYrsPOnvTcM2Jh2
# T1a5UsK2nTipgedtQVyMadG5K8TGe8+c+njikxp2oml101DkRBK+IA2eqUTQ+OVJ
# dwhaIcW0z5iVGlS6ubzBaRm6zxbygzc0brBBJt3eWpdPM43UjXd9dUWhpVgmagNF
# 3tlQtVCMr1a9TMXhRsUo063nQwBw3syYnhmJA+rUkTfvTVLzyWAhxFZH7doRS4wy
# w4jmWOK22z75X7BC1o/jF5HRqsBV44a/rCcsQdCaM0qoNtS5cpZ+l3k4SF/Kwtw9
# Mt911jZnWon49qfH5U81PAC9vpwqbHkB3NpE5jreODsHXjlY9HxzMVWggBHLFAx+
# rrz+pOt5Zapo1iLKO+uagjVXKBbLafIymrLS2Dq4sUaGa7oX/cR3bBVsrquvczro
# SUa31X/MtjjA2Owc9bahuEMs305MfR5ocMB3CtQC4Fxguyj/OOVSWtasFyIjTvTs
# 0xf7UGv/B3cfcZdEQcm4RtNsMnxYL2dHZeUbc7aZ+WssBkbvQR7w8F/g29mtkIBE
# r4AQQYoxggU1MIIFMQIBATBwMGQxCzAJBgNVBAYTAkNOMRAwDgYDVQQIEwdHdWFu
# Z1hpMQ4wDAYDVQQHEwVZdUxpbjESMBAGA1UEChMJR3VHdWFuMTIzMR8wHQYJKoZI
# hvcNAQkBFhBndWd1YW4xMjNAcXEuY29tAgh8o+7iG6Gz5jAJBgUrDgMCGgUAoHgw
# GAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFjAjBgkqhkiG9w0BCQQx
# FgQUuSNINWB/mO7WfGSpwnV/EqcsG1EwDQYJKoZIhvcNAQEBBQAEggEAguvOdeqC
# hS0BGQzG5OLOjlJtrS9M71HZD7xv9b0JHVOiLADnBAaA2m4KA17zbhwO2owOvPEw
# UZaMe816LiWsTPbNy7k5Atf2pcb7eROYmO/wVnrbC+0FaWtY9fVitZfV84/sB5WG
# JuTg4nKzlVgRnTzTZB2MfUvQ2sI8zTUtrTc5e/qXHqZmPjI79xSjB7F8RY5YTdUj
# xD61ivWXCqHuAovR3tDtIcGR7uumf6Gl2z8iBaaFg/4a9pImns3mEl1+PYDC88y0
# dh7bQONVFj7mFMr78TOXOh0H4hutLRi9ka727r8XLudMNVtwt1XYtmQrmPsm+8/S
# dwi7X0PA7CYK/aGCAyAwggMcBgkqhkiG9w0BCQYxggMNMIIDCQIBATB3MGMxCzAJ
# BgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGln
# aUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EC
# EAVEr/OUnQg5pr/bP1/lYRYwDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMx
# CwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNDA0MTAxMzI0NTBaMC8GCSqG
# SIb3DQEJBDEiBCBwxwweZRpOnNpEy3WAGxOtQD3VQ7/8sBqOzB+EUVeS3jANBgkq
# hkiG9w0BAQEFAASCAgCbPqykXNxtdlueew3G3ds+FQXylh8wRahsLzfDZmUWdIOq
# WIUdYJiRjFKwJcIfaJ4ZOhdqEDNaTu9h03+shHwKZ+4nvxP42jrP5YNV0g1Poxi4
# D3i5OiQbeK8TJu1TuxOkaWlh4t1Napzp5pbzUjQ6s1Ad6CTKp2Z4N3lgryw8I6Q4
# aw3fQ19/TYzoKwenClbv3HGsSITtTH64a7rIVPjxhs5qPFBS+Ig+ABjo5qb+08Xd
# VkXYg+7zRks19VJwKs8cRmbUMJ9PamJg1IYh/5YJNuU9w73C5kYk/CCIuqM+GdBZ
# FEUDv0sfZOJdplEqfBptNiqJBsGXdYZl7ILG2HRe3ej9NgodiZtokck6TZ92GBCI
# bcJZzY5zEGkHKQgv9WzAWYdy9LondiLNItt5+d5kc5a5fj1rmNDMB2M5lPLY3qL3
# 4cGCjhHOqcodpaK2XRayIOcjvFDDXKgE0HaUSYfCD8oCT5qAW21poIV1oRs4DqfY
# G/dkfCiE33Q247uwiaemUsbH+E0ukHVfsSJVL2AF+An1qRK+Npn9TJy0V/Xp6iLE
# PoxacH9rE587ppMxuTbOt+ADixf6uPwz3rxgsJs0sPTDPrLa/tDd9advuDmmlnUj
# 9AAtKGHaDjQumb71AoyoaGxZEcnbNxEgpiw4U/ffeGmvXEz/a5egGs6OZMZYIA==
# SIG # End signature block
