# by https://github.com/guguan123

param(
    [switch]$NoAdministratorRequired,   # 忽略权限检测
    [switch]$Help,                      # 获取帮助
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
#
# 如果无输入参数则自动开/关热点


# 获取当前操作系统版本信息
$osVersion = [System.Environment]::OSVersion.Version
# 定义 Windows 10 的最低版本
$win10Version = New-Object System.Version "10.0"
if ($osVersion -lt $win10Version) {
    Write-Host "Warning: System versions lower than Windows 10"
}

# 解析命令行参数并执行相应操作
# 检查参数是否包含帮助开关
if ($Help -or $args -contains "-?") {
    # 获取当前脚本文件的完整路径
    $scriptPath = $MyInvocation.MyCommand.Name
    # 使用Split-Path获取文件名部分
    $scriptFileName = Split-Path -Path $scriptPath -Leaf
    # Output help information
    Write-Host "Usage: $scriptFileName [options]"
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
    Write-Host "$scriptFileName -Help | -?"
    Write-Host ""
    Write-Host "If no input parameters are provided, it automatically toggles the hotspot."
    exit
}
# 如果没有帮助开关，则执行脚本的其他逻辑

# 获取当前用户的 Windows 身份验证
$WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
# 创建 Windows 身份验证的 WindowsPrincipal 对象
$WindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($WindowsIdentity)
# 检查用户是否属于管理员组
$IsAdmin = $WindowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$IsAdmin) {
    Write-Host "The script requires administrator privileges to run"
    if (!$NoAdministratorRequired -or $args -contains "-NAR") {
        Exit
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


if ($EnableAdapter) {
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
# MIIgvwYJKoZIhvcNAQcCoIIgsDCCIKwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDcmX5khLl/fUJZ
# NiPZnqmEgoZeBXnT/k8beF3EjaR4sqCCGs8wggO/MIICp6ADAgECAgh8o+7iG6Gz
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
# CisGAQQBgjcCARYwLwYJKoZIhvcNAQkEMSIEIKBXB9BywpT57+Kv6JnjM1K13QBA
# i/u1MX4v1X+5hsbFMA0GCSqGSIb3DQEBAQUABIIBAK1KjSVvmM3VSQIPhJfepguE
# BhLgh4qtanX4TbkE/5tDiCPjJokusTv5B37ntpjSaNYBt9zPyvvjpqtopTA0yk43
# ea4yJIE5bD0vNHWjg90y1ZmmN3CxPaa9hIZhiL4t2TbtVVjaqUwpv5nBZ/hRbPgz
# ocveEGm27aMZriN4JlDSNLS5lKURCbKfjWAOHYp2D+9rusxbV0tgIIPFFIkvS/vK
# bDWrXMd5QwVRwjSNptQv6E/pZnf4LQUQ/9BicnMD5sZpZ+c7Xwox3b8V8m5G0+iD
# DLdUTsKOV9lym0N6YCOWH9cez4jRacLOIvsEHnEyQ4E/HxZGPLJBNv/EEkeQc96h
# ggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhAFRK/zlJ0IOaa/
# 2z9f5WEWMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEH
# ATAcBgkqhkiG9w0BCQUxDxcNMjQwNDA1MDQxMjQ2WjAvBgkqhkiG9w0BCQQxIgQg
# L/xIcJkGNuxTqo6V/P13RJexxkUsy/Vt5kXREnJND4wwDQYJKoZIhvcNAQEBBQAE
# ggIARhz4jqk4fdoubZI999h/3onHrv+EKTa5BGQH+H3owbKcDyNO69HF6qo2Jvo+
# 6xD0z9yFvAG9o/NOsomQA9gnunuE+acZ8V5mpeGhDExlKDJcFnDZDVqzPb68PKh+
# JPwk4pN+vfmpVgrP2W+nBrq2bzc35aFdKUHFeUw3+gFmNASNs51AIaKV/ER45VEz
# 8JvXMTSOXujDpmtSbEmg5/sucd0yfC3JRNKqnofdBhz7TSEOUNj8Z/sjkChiTord
# d6kbZYnFpAzIUUpcZ1Yjc0ji41oC9Ra6dyoWQjITjRlEh0Km7ro4XEyUHesQtnjF
# 2XeyRZB+Q/lZ6tHu1q6WVb6eokyluRNBBTdfZNe0pL8eJ6uq9C+AA533ZgIhtpxZ
# DgTUAMGMuavm+sDpUah9FwoJyyULD6EZcHOnZv48S4sKsjxIbb5WojcMQ+Erk6tR
# 7fLS+xgaBAdQJhlTrbpLvqaPm2JZo4Ptplgg7ZY2nwIX3uuO5F4G8VSDC3/mBZX5
# hgxWAHyOGIcm8E2sjjiocpeGlGv2P7mdt52G3YnB9C6cnRBPdxY3oV6W0Wl2d6Eo
# Cb6lAWMdt+qK3b0haA718TkUV6x0iz1Z5a7xZzNNWPJ7RzqA03FKM0C3nmoyg5+/
# eJ20SIiq3UrVxl9+Lb/QIctJ+Vy0bLVk0wSL+njdYuo2pc8=
# SIG # End signature block
