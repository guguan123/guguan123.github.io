# guguan123
一个几乎啥也不懂的初中生写的没啥用的一坨静态网站。
index.html和index_zh.html是用apache2 default page改的，增加了中英文切换和黑暗模式。

### tools/URL_redirect.html
这个页面是用来给没有地址栏的浏览器准备的（指Apple watch的隐藏浏览器），在地址栏输入网址后点击“GO”或者“前往”就可以转跳到相应的网站。

### Gaokao_Countdown.html（我不知道这个文件名翻译对不对）
这个页面是模仿论坛上一个人的网页，是个高考倒计时（添加了黑暗模式和在线时间检查）。
原网站链接：http://226000.xyz/

### tools/pondsihotspot.ps1
一个可以开启/关闭电脑 WiFi 热点的 PowerShell 脚本
需要以管理员权限运行
__参数示例：__
_`-EnableHotspot`: 开启WiFi热点。_
_`-DisableHotspot`: 关闭WiFi热点。_
_`-EnableAdapter`: 启用无线网络适配器。_
_`-DisableAdapter`: 禁用无线网络适配器。_
_`-Force`: 忽略管理员权限检测运行脚本。_
_`-help`: 获取帮助_
_如果无输入参数则自动开/关热点_

~~（我完全没学过编程，这些页面能正常工作就很不错了）~~
