// 检查是否存在cookie或localStorage中的语言选择
function checkLanguage() {

    var cname=getCookie("lang");
    if (cname!="") {  // 通过检测变量 cname 是否为 "" 来检测cookie是否存在
        // cookie存在，设置变量 language 为变量 cname
        var language = cname;
    }
    else 
    {
        // 检查浏览器是否支持 localStorage
        if (typeof(Storage)!=="undefined") {
            // 支持 localStorage  sessionStorage 对象，读取localStorage
            var lname = localStorage.getItem("lang");
            if (lname!="null") {
                var language = lname;
            } else {
                var language = navigator.language || navigator.userLanguage;
            }
        } else {
            // 不支持 web 存储，直接读取浏览器语言
            var language = navigator.language || navigator.userLanguage;
        }
    }

    //将language变量转为小写
    var language = language.toLowerCase();
    //返回变量language
    return language;
}

function RedirectPage() {
    language = checkLanguage()
    // 延期cookie
    setCookie(language)
    // 根据语言选择重定向到相应的html文件
    var targetUrl = language === "zh-cn" ? "index_zh.html" : "index.html";

    // 获取当前的url中的文件名部分
    //var currentUrl = window.location.pathname.split("/").pop();

    // 只有当当前的url不是目标url时，才进行重定向
    //if (currentUrl !== targetUrl) {
    //    window.location.href = targetUrl;
    //}

    // 获取当前页面html元素的lang属性并将其转换为小写
    var lang = document.documentElement.lang.toLowerCase();
    if (language === "english") {
        language = "en";
    }

    // 只有当当前的语言不是目标语言时，才进行重定向
    if (lang !== language) {
        window.location.href = targetUrl;
    }
}

// 返回指定 cookie 值的函数
function getCookie(lang)
{
    var name = lang + "=";
    var ca = document.cookie.split(';');
    for(var i=0; i<ca.length; i++) {
        var c = ca[i].trim();
        if (c.indexOf(name)==0) return c.substring(name.length,c.length);
    }
    return ""; // 如果没找到相应cookie返回 ""
}

// 设置cookie
function setCookie(language) {
    // 获取当前时间
    var now = new Date();
    // 设置过期时间为30天后
    now.setTime(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    // 将过期时间转换为GMT格式的字符串
    var expires = now.toGMTString();

    // 设置cookie的名称和过期时间
    document.cookie = `lang=${language}; expires=${expires}; path=/`;
}

// 设置cookie或localStorage中的语言选择
function setLanguage(language) {
    // 设置Cookie中的语言选择
    setCookie(language)

    // 设置localStorage中的语言选择
    localStorage.setItem("lang", language);

    // 重新加载页面
    location.reload();
}

function getAddress(url) {
    var url = window.location.href;
    //定义一个正则表达式，匹配网页地址的最后一部分
    var regex = /\/[^\/]*$/;
    //用空字符串替换掉最后一部分
    url = url.replace(regex, "");
    console.log("读取当前URL：" + url);
    return url;
}
function CompareURL() {
    function checkUrl(PossibleURL) { // 定义一个函数，参数为变量PossibleURL
        var urls = ["server", "192.168.0.2", "192.168.194.2", "guguan.freehk.svipss.top", "guguan.000.pe", "guguan123.github.io"]; // URL数组
        var URLnum = urls.indexOf(PossibleURL)
        if (URLnum != -1) { // 如果变量PossibleURL在URL数组中
            if (URLnum == 0 || URLnum == 1 || URLnum == 2) { //用户通过局域网或者ZeroTier访问
                console.log("检测到通过局域网或者ZeroTier访问");
                return 1;
            } else {
            if (URLnum == 3) {   //用户通过内网穿透访问
                console.log("检测到通过内网穿透访问");
                return 2;
            } else {
                if (URLnum == 4) {   //用户访问的是云服务器
                    console.log("检测到访问的是云服务器");
                    return 3;
                } else {
                    if (URLnum == 5) {   //用户访问的是GitHub Pages
                        console.log("检测到访问的是GitHub Pages");
                        return 4;
                    }
                }
            }
            }
        } else { // 如果变量PossibleURL不在URL数组中
            console.log("开始端口测试");
            var TestResults = testPorts([80, 8080, 8000, 23333, 24444, 5244]); // 调用外部函数，传入端口数组
            return TestResults;
            // 通过http测试是否可以连接服务器其它端口
        }
        
    }
    var url
    var PossibleURL = getAddress(url); // 变量PossibleURL
    console.log("准备开始检测网络连接，当前URL：" + PossibleURL);
    var regex = /https?:\/\//; // 定义一个正则表达式，匹配http://或者https://
    PossibleURL = PossibleURL.replace(regex, ""); // 把匹配到的子字符串替换为空字符串
    var PossibleURL = PossibleURL.replace(/\/[^\/]*$/, "");
    console.log(PossibleURL); // 打印变量PossibleURL的值
    console.log("变量PossibleURL的类型为：" + typeof PossibleURL); // 打印变量PossibleURL的类型
    var result = checkUrl(PossibleURL); // 调用函数，得到返回值
    return result;
}

function testPorts(ports) { // 定义函数，参数为端口数组
    var success = 0; // 成功次数
    var i = 0; // 循环索引
    function testPort() {
        if (i < ports.length && success < 2) { // 如果还有端口未测试且成功次数小于2
            console.log("第" + i + "次检测，已检测成功" + success + "次，开始检测端口" + ports[i]);
            $.ajax({
                type: "HEAD",
                url: getAddress(url) + ":" + ports[i], // 拼接URL和端口并插入冒号
                success: function() {
                    success++; // 成功次数加一
                    i++; // 索引加一
                    testPort(); // 递归调用
                },
                error: function() {
                    i++; // 索引加一
                    testPort(); // 递归调用
                }
            });
        } else { // 如果已经测试完所有端口或者成功次数达到2
            if (success >= 2) { // 如果成功次数大于等于2
                console.log("端口测试通过，将认为通过局域网或者ZeroTier访问");
                return 1;
            } else { // 如果成功次数小于2
                console.log("连接检测失败"); // 显示不通过
                return 0;
            }
        }
    }
    var testPortNum = testPort(); // 调用内部函数
    return testPortNum;
}

function SwitchPageType(URLType) {
    // 获取id为0和1的元素
    var elem0 = document.getElementById("0");
    var elem1 = document.getElementById("1");
    var elem2 = document.getElementById("2");
    var elem3 = document.getElementById("3");
    var elem4 = document.getElementById("4");

    // 根据a的值设置元素的显示或隐藏
    if (URLType == 0){
        elem1.style.display = "block"; // 显示id为0的元素
        elem2.style.display = "none"; // 隐藏id为1的元素
        elem3.style.display = "none";
        elem4.style.display = "none";
    } else if (URLType == 1) {
        elem1.style.display = "block"; // 显示id为1的元素
        elem2.style.display = "none"; // 隐藏id为0的元素
        elem3.style.display = "none";
        elem4.style.display = "none";
    } else if (URLType == 2) {
        elem1.style.display = "none";
        elem2.style.display = "block";
        elem3.style.display = "none";
        elem4.style.display = "none";
    } else if (URLType == 3) {
        elem1.style.display = "none";
        elem2.style.display = "none";
        elem3.style.display = "block";
        elem4.style.display = "none";
    } else if (URLType == 4) {
        elem1.style.display = "none";
        elem2.style.display = "none";
        elem3.style.display = "none";
        elem4.style.display = "block";
    }
}

// 在页面加载时调用检查语言选择的函数
window.addEventListener("load", RedirectPage);

// 当文档加载完成时，执行回调函数
document.addEventListener("DOMContentLoaded", () => {
    // 为按钮添加点击事件，调用设置语言选择的函数
    var button = document.querySelector("button");
    button.addEventListener("click", () => {
        setLanguage(button.textContent);
    });

    //获取当前网页的地址
    var url = window.location.href;
    //定义一个正则表达式，匹配网页地址的最后一部分
    var regex = /\/[^\/]*$/;
    //用空字符串替换掉最后一部分
    url = url.replace(regex, "");
    //定义一个数组，包含所有需要修改的链接的id
    var ids = ["MCSM","qBT", "Netdisk", "router", "ASUSDM"];
    //定义一个数组，包含每个链接的端口号
    var ports = ["23333","8080", "5244", "8084", "8085"];
    //遍历数组，对每个链接执行相同的操作
    for (var i = 0; i < ids.length; i++) {
        //获取当前链接的元素
        var link = document.getElementById(ids[i]);
        //修改href属性，拼接端口号
        link.href = url + ":" + ports[i];
    }

    var logo = document.getElementById("logo");
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        logo.src = "./ubuntu-logo_dark.png";
    }

    var URLType = CompareURL();
    console.log("检测结果为：" + URLType);
    SwitchPageType(URLType)
});

// 引用了https://www.runoob.com/js/js-cookies.html ， https://www.runoob.com/html/html5-webstorage.html 的相关代码