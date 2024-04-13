# from > https://github.com/guguan123/guguan123.github.io/blob/main/tools/pondsihotspot.ps1
# author > guguan123@qq.com
# AC certificate for self-signing > https://guguan123.github.io/keys/PC2412-AC.cer

param(
    [switch]$Version,                   # 查看版本信息
    [switch]$Help,                      # 获取帮助
    [switch]$Force,                     # 忽略权限检测
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
# -Force: 忽略管理员权限检测运行脚本。
# -help: 获取帮助
# -CheckAdapterStatus: 检查WiFi网卡状态
# -CheckHotspotStatus: 查看WiFi热点状态
# -Version: 查看版本信息
# 如果无输入参数则自动开/关热点
#
# tip: Start-Process ms-settings:network-mobilehotspot  # 打开热点设置（Windows设置程序）


# 检查当前操作系统信息
if ([System.Environment]::OSVersion.Platform -eq 'Win32NT') {
    # 定义 Windows 10 的最低版本
    $win10Version = New-Object System.Version "10.0"
    # 对比当前操作系统版本信息是否低于10
    if ([System.Environment]::OSVersion.Version -lt $win10Version) {
        Write-Warning "System versions lower than Windows 10!"
    }
} else {
    Write-Warning "This system is not running Windows."
    if (!$Force) {
        Exit 1
    }
}
# 获取当前PowerShell版本信息（暂不需要）
#$psMajorVersion = $PSVersionTable.PSVersion.Major
#if ($psMajorVersion -lt 7) {
#    Write-Warning "PowerShell version is $($PSVersionTable.PSVersion). You are using a version lower than PowerShell 7!"
#}


# 检查管理员权限
function Test-AdministratorRights {
    # 检查是否有管理员权限
    if (!$Force) {
        # 获取当前用户的 Windows 身份验证
        $WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        # 创建 Windows 身份验证的 WindowsPrincipal 对象
        $WindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($WindowsIdentity)
        # 检查用户是否属于管理员组
        $IsAdmin = $WindowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } else { # 如果输入 -Force 开关就强制认为有管理员权限
        $IsAdmin = $true
    }
    return $IsAdmin
}

# 等待异步操作完成的函数
Function Await($WinRtTask, $ResultType) { 
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType) 
    $netTask = $asTask.Invoke($null, @($WinRtTask)) 
    $netTask.Wait(-1) | Out-Null 
    $netTask.Result 
} 

# 等待异步操作完成的函数（针对没有返回结果的操作）
Function AwaitAction($WinRtAction) { 
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0] 
    $netTask = $asTask.Invoke($null, @($WinRtAction)) 
    $netTask.Wait(-1) | Out-Null 
}

# 检查WiFi网卡状态（该功能未完善！）
function Get-WifiAdapterStatus {
    $wifiAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*Wireless*' }
    if ($wifiAdapters.Count -gt 0) {
        $wifiAdapters
    } else {
        Write-Output "No wireless network adapter found."
    }
}

# 查看WiFi热点状态（该功能未完善！）
function Get-WiFiHotspotStatus {
    if (!$tetheringManager.TetheringOperationalState) {
        if ($tetheringManager.TetheringOperationalState -eq 1) {
            $tetheringConfiguration = $tetheringManager.GetCurrentTetheringConfiguration()
            $passphrase = "Not accessible through API" # Windows API does not expose the hotspot password for security reasons
            Write-Output "Hotspot Status: On, SSID: $($tetheringConfiguration.SSID), Password: $($passphrase)"
        } else {
            Write-Output "Hotspot Status: Off"
        }
    }
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
            Write-Output "Wireless adapter not found."  # 如果未找到适配器则显示消息并退出
            exit
        }
    } catch {
        Write-Error "An error occurred while trying to enable/disable the wireless adapter: $_"  # 处理异常情况
        exit
    }
}

# 启用或禁用热点的函数
Function ManageHotspot($enable) {
    try {
        if ($enable) { 
            Await ($tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])  # 开启热点
            Write-Output "Network sharing has been enabled."  # 显示消息
        } else { 
            Await ($tetheringManager.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])  # 关闭热点
            Write-Output "Network sharing has been disabled."  # 显示消息
        }
    } catch {
        Write-Output "An error occurred: $_"  # 处理异常情况
    }
}

# 设置全局变量
$IsAdmin = Test-AdministratorRights   # 当前是否以管理员的方式运行
if ($IsAdmin) {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime  # 加载 Windows Runtime 程序集
    # 获取 AsTask 方法
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
}
$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()  # 获取网络连接配置文件
if ($null -eq $connectionProfile) {Write-Warning "No internet connection profile found. Please check your network connection."} # 如果找不到连接配置文件，则显示消息并退出
$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)  # 创建网络热点管理器

# 解析命令行参数并执行相应操作
# 检查参数是否包含帮助开关
if ($Version) {
    Write-Output "pondsihotspot.ps1 v0.4"
    Write-Output "Last changed on 2022-4-12"
}
elseif ($Help) {
    # 使用$MyInvocation.MyCommand.Name获取当前脚本文件的完整路径；使用Split-Path获取文件名部分
    $scriptFileName = Split-Path -Path $MyInvocation.MyCommand.Name -Leaf
    # Output help information
    Write-Output "Usage: $($scriptFileName) [options]"
    Write-Output ""
    Write-Output "-EnableHotspot"
    Write-Output "    Directly enables WiFi hotspot."
    Write-Output ""
    Write-Output "-DisableHotspot"
    Write-Output "    Directly disables WiFi hotspot."
    Write-Output ""
    Write-Output "-EnableAdapter"
    Write-Output "    Directly enables the wireless network adapter."
    Write-Output ""
    Write-Output "-DisableAdapter"
    Write-Output "    Directly disables the wireless network adapter."
    Write-Output ""
    Write-Output "-Force"
    Write-Output "    Runs the script ignoring administrator privileges."
    Write-Output ""
    Write-Output "$($scriptFileName) -Help"
    Write-Output ""
    Write-Output "-Version"
    Write-Output "    Displays the version of $($scriptFileName). Additional parameters are ignored."
    Write-Output ""
    Write-Output "If no input parameters are provided, it automatically toggles the hotspot."
}
elseif ($CheckAdapterStatus) {Get-WifiAdapterStatus}
elseif ($CheckHotspotStatus) {Get-WiFiHotspotStatus}
elseif ($EnableAdapter) {
    if ($IsAdmin) {
        EnableDisableWiFiAdapter $true
    } else {
        Write-Error "The script requires administrator privileges to run!"
        Exit 1
    }
}
elseif ($EnableHotspot) {
    if ($IsAdmin) {
        if ($EnableAdapter) {
            Start-Sleep -Seconds 5  # 如果还附带有"-EnableAdapter"开关就等待5秒钟以确保适配器启用
        }
        ManageHotspot $true
    } else {
        Write-Error "The script requires administrator privileges to run!"
        Exit 1
    }
}
elseif ($DisableHotspot) {
    if ($IsAdmin) {
        ManageHotspot $false
    } else {
        Write-Error "The script requires administrator privileges to run!"
        Exit 1
    }
}
elseif ($DisableAdapter) {
    if ($IsAdmin) {
        EnableDisableWiFiAdapter $false
    } else {
        Write-Error "The script requires administrator privileges to run!"
        Exit 1
    }
}
elseif (-not $args) {
    if ($IsAdmin) {
        # 如果没有给出直接的命令，则根据当前状态执行默认操作
        try {
            if ($tetheringManager.TetheringOperationalState -eq 1) { 
                ManageHotspot $false
            } else { 
                ManageHotspot $true
            }
        } catch {
            Write-Output "An error occurred: $_"
        }
    } else {
        Write-Error "The script requires administrator privileges to run!"
        Exit 1
    }
}
elseif ($args) {
    $scriptFileName = Split-Path -Path $MyInvocation.MyCommand.Name -Leaf
    Write-Output "$($scriptFileName): unknown option $($args)"
    Exit 1
}
# SIG # Begin signature block
# MIIgvwYJKoZIhvcNAQcCoIIgsDCCIKwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAN7/m0+Fq3Zo8D
# IkdL5CxxXOkdbUq5KwVH58em2cLfX6CCGs8wggO/MIICp6ADAgECAgh8o+7iG6Gz
# 5jANBgkqhkiG9w0BAQsFADBkMQswCQYDVQQGEwJDTjEQMA4GA1UECBMHR3VhbmdY
# aTEOMAwGA1UEBxMFWXVMaW4xEjAQBgNVBAoTCUd1R3VhbjEyMzEfMB0GCSqGSIb3
# DQEJARYQZ3VndWFuMTIzQHFxLmNvbTAeFw0yNDA0MDUwMzUyMDBaFw00OTA0MDUw
# MzUyMDBaMF0xCzAJBgNVBAYTAkNOMRAwDgYDVQQIEwdHdWFuZ1hpMQ4wDAYDVQQH
# EwVZdUxpbjESMBAGA1UEChMJR3VHdWFuMTIzMRgwFgYJKoZIhvcNAQkBFglndWd1
# YW4xMjMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC5Htoz5GyY3s6Q
# 0mfSUHZpnc1OqpT3gM7eHHHddQGFA90t3Ei6sKvneZgbnzQXq/oX3HMaCH2Stvgy
# FfC4bRCjSVdaje2kdyslLuPxwifBx2dyEHdYofK1UXMk3b7HMh1vbXI/QVsSefkC
# zAbF0vlspF+pBcnkd8JqVoUWD/lKUkbfxqDGAzLiLJt4q4JwYPJn1psMyRmiIMwz
# E+AJGAiEiOtmcvkktAYEFVZMfFXvKQibELdArlQBh26Xl2A02OSHDwv1t/ZpGGvc
# +p5Id/X6/MTPaN99aGQMbUxQ92d7006tHlHzqQEI9JZKFiGBcvlX8PZEqpL6fHKX
# BrGCdKbfAgMBAAGjfDB6MAkGA1UdEwQCMAAwCwYDVR0PBAQDAgSwMGAGA1UdJQRZ
# MFcGCCsGAQUFBwMCBggrBgEFBQcDAwYIKwYBBQUHAwQGCisGAQQBgjcCARUGCisG
# AQQBgjcCARYGCCsGAQUFBwMVBgkqhkiG9y8BAQUGCisGAQQBgjcKAwwwDQYJKoZI
# hvcNAQELBQADggEBAJ/hbLt3YkuXT5Yxa2Xw80nx1OSolplYHoCyxdrtM8rfgrfC
# Re8PDj/udP/6qa5CyrkSQxeJTsuAI56XpkFssedaavBHF1MrMZEPPXbg9rQkkwAj
# 6hBYTLutFMTojW3vNnBKSddcy2PDG9OIZRTf37xTGGootYh8qZ5XQRPFR0Y15lr9
# cvGkMSg/62AsFyM3FLz/TS+7c1fsvmzQqurMOuW0u0zDATG+ikFi8roz1EwPlllC
# PPb+G/Pdoy5os/RJrGlHbG1572S9jhTz35YO0sRDdhmeb2eQIB/Y4JuQYEjRe5U5
# LldBn7TbtQp3hl1wBw5RRLJl5/v1ULi3aQP3/LAwggP/MIIC56ADAgECAgg/p6n/
# LFYo3DANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDEwlQQzI0MTItQ0EwIBcNMjQw
# NDA1MDMyNjAwWhgPMjA1NDA0MDUwMzI2MDBaMGQxCzAJBgNVBAYTAkNOMRAwDgYD
# VQQIEwdHdWFuZ1hpMQ4wDAYDVQQHEwVZdUxpbjESMBAGA1UEChMJR3VHdWFuMTIz
# MR8wHQYJKoZIhvcNAQkBFhBndWd1YW4xMjNAcXEuY29tMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAuR7aM+RsmN7OkNJn0lB2aZ3NTqqU94DO3hxx3XUB
# hQPdLdxIurCr53mYG580F6v6F9xzGgh9krb4MhXwuG0Qo0lXWo3tpHcrJS7j8cIn
# wcdnchB3WKHytVFzJN2+xzIdb21yP0FbEnn5AswGxdL5bKRfqQXJ5HfCalaFFg/5
# SlJG38agxgMy4iybeKuCcGDyZ9abDMkZoiDMMxPgCRgIhIjrZnL5JLQGBBVWTHxV
# 7ykImxC3QK5UAYdul5dgNNjkhw8L9bf2aRhr3PqeSHf1+vzEz2jffWhkDG1MUPdn
# e9NOrR5R86kBCPSWShYhgXL5V/D2RKqS+nxylwaxgnSm3wIDAQABo4IBATCB/jAP
# BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQYZQbMi6DQV4u3Y1Uk5VbcnbuC0TAf
# BgNVHSMEGDAWgBQjAoJQQMU844AY6d0YCw0kagyw3jBBBgNVHR8EOjA4MDagNKAy
# hjBmaWxlOi8vLy9XSU4tTGFwdG9wMjQxMi9DZXJ0RW5yb2xsL1BDMjQxMi1DQS5j
# cmwwWwYIKwYBBQUHAQEETzBNMEsGCCsGAQUFBzAChj9maWxlOi8vLy9XSU4tTGFw
# dG9wMjQxMi9DZXJ0RW5yb2xsL1dJTi1MYXB0b3AyNDEyX1BDMjQxMi1DQS5jcnQw
# CwYDVR0PBAQDAgGGMA0GCSqGSIb3DQEBCwUAA4IBAQCmlW5aYHm/f1OMqIjAZZe/
# +NI8773Z7nKF9eg5afEgIvWWndcuKBgHmdhr5y6KeAFFYRrTO0+M8c+OAbvQJ4TH
# +aJkmQ/D3bRgjXIawGwgkPNH3xu2vbE6/B8pwVTj6vTYx/G1er/K/gqMNzdJWfxK
# d5GBWRkZHQvl6kHKOM/+OhD4eQZDuNBhgT69Q4htnmt5m0wx3V27muau5QlDSnIN
# 49V6MB/kKcUekrCXOyNjdLfnQ+9MXsIgkC2eA6s8Ae7B5iL0e1FdICC/aQS8msov
# ts4WbCmk0pZr8srp9UFV950E1Ys7BXwjRhzew8wKrRPndIMbNUimRz0VJn/CDs1c
# MIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBl
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJv
# b3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7J
# IT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxS
# D1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb
# 7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1ef
# VFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoY
# OAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSa
# M0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI
# 8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9L
# BADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfm
# Q6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDr
# McXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15Gkv
# mB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
# FgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGL
# p6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0G
# CSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6p
# Grsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1W
# z/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp
# 8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglo
# hJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8S
# uFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIGrjCCBJagAwIBAgIQ
# BzY3tyRUfNhHrP0oZipeWzANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjIwMzIzMDAw
# MDAwWhcNMzcwMzIyMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5
# NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAxoY1BkmzwT1ySVFVxyUDxPKRN6mXUaHW0oPRnkyibaCwzIP5WvYR
# oUQVQl+kiPNo+n3znIkLf50fng8zH1ATCyZzlm34V6gCff1DtITaEfFzsbPuK4CE
# iiIY3+vaPcQXf6sZKz5C3GeO6lE98NZW1OcoLevTsbV15x8GZY2UKdPZ7Gnf2ZCH
# RgB720RBidx8ald68Dd5n12sy+iEZLRS8nZH92GDGd1ftFQLIWhuNyG7QKxfst5K
# fc71ORJn7w6lY2zkpsUdzTYNXNXmG6jBZHRAp8ByxbpOH7G1WE15/tePc5OsLDni
# pUjW8LAxE6lXKZYnLvWHpo9OdhVVJnCYJn+gGkcgQ+NDY4B7dW4nJZCYOjgRs/b2
# nuY7W+yB3iIU2YIqx5K/oN7jPqJz+ucfWmyU8lKVEStYdEAoq3NDzt9KoRxrOMUp
# 88qqlnNCaJ+2RrOdOqPVA+C/8KI8ykLcGEh/FDTP0kyr75s9/g64ZCr6dSgkQe1C
# vwWcZklSUPRR8zZJTYsg0ixXNXkrqPNFYLwjjVj33GHek/45wPmyMKVM1+mYSlg+
# 0wOI/rOP015LdhJRk8mMDDtbiiKowSYI+RQQEgN9XyO7ZONj4KbhPvbCdLI/Hgl2
# 7KtdRnXiYKNYCQEoAA6EVO7O6V3IXjASvUaetdN2udIOa5kM0jO0zbECAwEAAaOC
# AV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFLoW2W1NhS9zKXaa
# L3WMaiCPnshvMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcw
# AoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJv
# b3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwB
# BAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQB9WY7Ak7ZvmKlEIgF+
# ZtbYIULhsBguEE0TzzBTzr8Y+8dQXeJLKftwig2qKWn8acHPHQfpPmDI2AvlXFvX
# bYf6hCAlNDFnzbYSlm/EUExiHQwIgqgWvalWzxVzjQEiJc6VaT9Hd/tydBTX/6tP
# iix6q4XNQ1/tYLaqT5Fmniye4Iqs5f2MvGQmh2ySvZ180HAKfO+ovHVPulr3qRCy
# Xen/KFSJ8NWKcXZl2szwcqMj+sAngkSumScbqyQeJsG33irr9p6xeZmBo1aGqwpF
# yd/EjaDnmPv7pp1yr8THwcFqcdnGE4AJxLafzYeHJLtPo0m5d2aR8XKc6UsCUqc3
# fpNTrDsdCEkPlM05et3/JWOZJyw9P2un8WbDQc1PtkCbISFA0LcTJM3cHXg65J6t
# 5TRxktcma+Q4c6umAU+9Pzt4rUyt+8SVe+0KXzM5h0F4ejjpnOHdI/0dKNPH+ejx
# mF/7K9h+8kaddSweJywm228Vex4Ziza4k9Tm8heZWcpw8De/mADfIBZPJ/tgZxah
# ZrrdVcA6KYawmKAr7ZVBtzrVFZgxtGIJDwq9gdkT/r+k0fNX2bwE+oLeMt8EifAA
# zV3C+dAjfwAL5HYCJtnwZXZCpimHCUcr5n8apIUP/JiW9lVUKx+A+sDyDivl1vup
# L0QVSucTDh3bNzgaoSv27dZ8/DCCBsIwggSqoAMCAQICEAVEr/OUnQg5pr/bP1/l
# YRYwDQYJKoZIhvcNAQELBQAwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYg
# U0hBMjU2IFRpbWVTdGFtcGluZyBDQTAeFw0yMzA3MTQwMDAwMDBaFw0zNDEwMTMy
# MzU5NTlaMEgxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjEg
# MB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1wIDIwMjMwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCjU0WHHYOOW6w+VLMj4M+f1+XS512hDgncL0ijl3o7
# Kpxn3GIVWMGpkxGnzaqyat0QKYoeYmNp01icNXG/OpfrlFCPHCDqx5o7L5Zm42nn
# af5bw9YrIBzBl5S0pVCB8s/LB6YwaMqDQtr8fwkklKSCGtpqutg7yl3eGRiF+0Xq
# DWFsnf5xXsQGmjzwxS55DxtmUuPI1j5f2kPThPXQx/ZILV5FdZZ1/t0QoRuDwbjm
# UpW1R9d4KTlr4HhZl+NEK0rVlc7vCBfqgmRN/yPjyobutKQhZHDr1eWg2mOzLukF
# 7qr2JPUdvJscsrdf3/Dudn0xmWVHVZ1KJC+sK5e+n+T9e3M+Mu5SNPvUu+vUoCw0
# m+PebmQZBzcBkQ8ctVHNqkxmg4hoYru8QRt4GW3k2Q/gWEH72LEs4VGvtK0VBhTq
# YggT02kefGRNnQ/fztFejKqrUBXJs8q818Q7aESjpTtC/XN97t0K/3k0EH6mXApY
# TAA+hWl1x4Nk1nXNjxJ2VqUk+tfEayG66B80mC866msBsPf7Kobse1I4qZgJoXGy
# bHGvPrhvltXhEBP+YUcKjP7wtsfVx95sJPC/QoLKoHE9nJKTBLRpcCcNT7e1NtHJ
# XwikcKPsCvERLmTgyyIryvEoEyFJUX4GZtM7vvrrkTjYUQfKlLfiUKHzOtOKg8tA
# ewIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwFgYD
# VR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZI
# AYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9zKXaaL3WMaiCPnshvMB0GA1UdDgQW
# BBSltu8T5+/N0GSh1VapZTGj3tXjSTBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8v
# Y3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRSU0E0MDk2U0hBMjU2
# VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEFBQcBAQSBgzCBgDAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFgGCCsGAQUFBzAChkxodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRSU0E0MDk2U0hB
# MjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCBGtbeoKm1
# mBe8cI1PijxonNgl/8ss5M3qXSKS7IwiAqm4z4Co2efjxe0mgopxLxjdTrbebNfh
# YJwr7e09SI64a7p8Xb3CYTdoSXej65CqEtcnhfOOHpLawkA4n13IoC4leCWdKgV6
# hCmYtld5j9smViuw86e9NwzYmHZPVrlSwradOKmB521BXIxp0bkrxMZ7z5z6eOKT
# GnaiaXXTUOREEr4gDZ6pRND45Ul3CFohxbTPmJUaVLq5vMFpGbrPFvKDNzRusEEm
# 3d5al08zjdSNd311RaGlWCZqA0Xe2VC1UIyvVr1MxeFGxSjTredDAHDezJieGYkD
# 6tSRN+9NUvPJYCHEVkft2hFLjDLDiOZY4rbbPvlfsELWj+MXkdGqwFXjhr+sJyxB
# 0JozSqg21Llyln6XeThIX8rC3D0y33XWNmdaifj2p8flTzU8AL2+nCpseQHc2kTm
# Ot44OwdeOVj0fHMxVaCAEcsUDH6uvP6k63llqmjWIso765qCNVcoFstp8jKastLY
# OrixRoZruhf9xHdsFWyuq69zOuhJRrfVf8y2OMDY7Bz1tqG4QyzfTkx9HmhwwHcK
# 1ALgXGC7KP845VJa1qwXIiNO9OzTF/tQa/8Hdx9xl0RBybhG02wyfFgvZ0dl5Rtz
# tpn5aywGRu9BHvDwX+Db2a2QgESvgBBBijGCBUYwggVCAgEBMHAwZDELMAkGA1UE
# BhMCQ04xEDAOBgNVBAgTB0d1YW5nWGkxDjAMBgNVBAcTBVl1TGluMRIwEAYDVQQK
# EwlHdUd1YW4xMjMxHzAdBgkqhkiG9w0BCQEWEGd1Z3VhbjEyM0BxcS5jb20CCHyj
# 7uIbobPmMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKEC
# gAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwG
# CisGAQQBgjcCARYwLwYJKoZIhvcNAQkEMSIEIKd+CplFg/6qwnbtkuYhhkUxtPOF
# TWGgRQt0mdSYNzdZMA0GCSqGSIb3DQEBAQUABIIBAHOO+SpHw/RoBr3UjJY1Sr6+
# +0gAbstrEy+jCAo55dOZrId/MMsOJxrlXzt1T1CbheRZf5JkEgEdArlsxGGiIWeg
# t4BNUcH2z1VLo+VvVT/cfzXzJn4NFlAlYSgZTgHGqnOiPg5YmUyQAfiKe5VqEigr
# U1bE9UVBSKjAfaZEEZsOn4LETzufsQLz8+58I+68KxVsOrfvPxgAdCLWRPeD8Bcr
# vWynIAjFqSKOj5uq63iTntT4Q0tWnlCZnz1WMVZpzEj+JPTjg0KuvHH7yZ34h8nx
# qps9OpzXtasknaWALfHjmvFfm2ZY5gebIg1p2Oj5RuDR2e83gTGwug4Y74Gv8yGh
# ggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhAFRK/zlJ0IOaa/
# 2z9f5WEWMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEH
# ATAcBgkqhkiG9w0BCQUxDxcNMjQwNDEzMDYzMjU0WjAvBgkqhkiG9w0BCQQxIgQg
# 5TYx43Q5lzwSGwLY7QdssxMaAm6ojsAnVGdpU/4uoS8wDQYJKoZIhvcNAQEBBQAE
# ggIAAVHgAVUQV6CrFa/XrlHY8UWxsB8XBdVT1MnTpx90ffWT8xZ1iZ05J0TTFG27
# i0xebsC8M0oj7Fh31SQap6jSGpNeI3SzAW0c6aosaFX9TTOIQFP+wR0NMhWum1PV
# OKjFoLveVuCxlLi1kY0utQNW+peObk16wO9JXCRqbLzakcOCsq3wjoH3KToHvoeA
# CJ0wsBFKgc66zTPO99ifu9i15gdfkR7RTY4cdUaPPc6CIyd9cgtKzB3WpdzRCm1u
# JnSzYgyuwMwU0ytlAorJ1QCdK3fslkTrTTrjF+RRZTWwJEHiWVcjI0fRr7lczkgk
# vry3KOhmFUJFp2rkJYuNOM4NJS3aKKNK3c6Vk+hxKzkbiWSJSZmTIe1K1xBTH1G7
# ea78Jo2Vfs4ry1UFGSFb+roR78RyBl/Hs5ETTPZDsBtnlvh4AxWC2a+zOqBC8PLW
# q6RU8WRXROf3VPi2izXz0WU3zFb+SnfQi/pfqfc86mkT5Vlor1mTFltl3LRIA3U1
# oJyfqRNixMpvLAd3W4tcysgs3CLk9BPQdpU4DlnsRcIHgaZW9FH01bI9J40oWU7r
# VkoomBkj16olsDYLmJGS1JAahQIxWiC8tOv/FhwriwIDaP6EUkKpG97xgmVUFpU9
# TkgVGvTc4vtl2QhHlRMpgMkOoi5sNWxQrQDMJmSCzhShWvI=
# SIG # End signature block
