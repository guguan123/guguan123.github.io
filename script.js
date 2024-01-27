// 检查是否存在cookie或localStorage中的语言选择
function checkLanguage() {
    var cname=getLangCookie("lang");
    if (cname!="") {  // 通过检测变量 cname 是否为 "" 来检测cookie是否存在
        // cookie存在，设置变量 language 为变量 cname
        var language = cname;
    } else {
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

    // 将language变量转为小写
    var language = language.toLowerCase();
    // 返回变量language
    return language;
}

function RedirectPage() {
    // 获取之前存储的语言设置
    language = checkLanguage();

    // 规定语言列表
    let languageList = ["en", "zh-cn"];
    if (languageList.includes(language)) { // 当获取的语言在语言列表里时
        // 延期cookie
        setLangCookie(language);
        // 根据语言选择重定向到相应的html文件
        var targetUrl = language === "zh-cn" ? "index_zh.html" : "index.html";

        // 获取当前页面html元素的lang属性并将其转换为小写
        var lang = document.documentElement.lang.toLowerCase();
        // 只有当当前的语言不是目标语言时，才进行重定向
        if (lang !== language) {
            window.location.href = targetUrl;
        }
    } else { // 如果获取的语言不在语言列表里
        console.error("Unsupported languages");
    }
}

// 返回指定 cookie 值的函数
function getLangCookie(lang) {
    var name = lang + "=";
    var ca = document.cookie.split(';');
    for(var i=0; i<ca.length; i++) {
        var c = ca[i].trim();
        if (c.indexOf(name)==0) return c.substring(name.length,c.length);
    }
    return ""; // 如果没找到相应cookie返回 ""
}

// 设置cookie
function setLangCookie(language) {
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
    setLangCookie(language);

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
    var lang = document.documentElement.lang.toLowerCase();
    if (lang === 'zh-cn') {
        console.log('开始获取URL，当前URL为：' + url);
    } else {
        console.log('Current URL:' + url);
    }
    return url;
}
function CompareURL() {
    function checkUrl(PossibleURL) {
        var urls = ["server2412", "192.168.0.2", "192.168.194.2", "guguan.freehk.svipss.top", "guguan.000.pe", "guguan123.github.io"]; // URL数组
        var URLnum = urls.indexOf(PossibleURL);
        if (URLnum != -1) { // 如果变量PossibleURL在URL数组中
            var lang = document.documentElement.lang.toLowerCase();
            if (URLnum == 0 || URLnum == 1 || URLnum == 2) { //用户通过局域网或者ZeroTier访问
                if (lang === 'zh-cn') {
                    console.log('检测到通过局域网或者ZeroTier访问');
                } else {
                    console.log('Detected access via LAN or ZeroTier');
                }
                return 1;
            } else if (URLnum == 3) {   //用户通过内网穿透访问
                if (lang === 'zh-cn') {
                    console.log('检测到通过内网穿透访问');
                } else {
                    console.log('Detected access via frp');
                }
                return 2;
            } else if (URLnum == 4) {   //用户访问的是云服务器
                if (lang === 'zh-cn') {
                    console.log('检测到访问的是云服务器');
                } else {
                    console.log('Detected access to cloud server');
                }
                return 3;
            } else if (URLnum == 5) {   //用户访问的是GitHub Pages
                if (lang === 'zh-cn') {
                    console.log('检测到访问的是GitHub Pages');
                } else {
                    console.log('Detected access to GitHub Pages');
                }
                return 4;
            }
        } else { // 如果变量PossibleURL不在URL数组中
            // 将认为用户访问的是GitHub Pages
            return 4;
            // 通过http测试是否可以连接服务器其它端口
        }
    }
    var PossibleURL = url; // 变量PossibleURL
    var lang = document.documentElement.lang.toLowerCase();
    if (lang === 'zh-cn') {
        console.log('准备开始检测网络连接方式');
    } else {
        console.log('Ready to start detecting network connectivity');
    }
    var regex = /https?:\/\//; // 定义一个正则表达式，匹配http://或者https://
    PossibleURL = PossibleURL.replace(regex, ""); // 把匹配到的子字符串替换为空字符串
    var PossibleURL = PossibleURL.replace(/\/[^\/]*$/, ""); //去掉“/”后面的内容
    var result = checkUrl(PossibleURL); // 调用函数，得到返回值
    return result;
}

function SwitchPageType(URLType) {
    // 获取id为0和1的元素
    //var elem0 = document.getElementById("null");
    var elem1 = document.getElementById("a");
    var elem2 = document.getElementById("b");
    var elem3 = document.getElementById("c");
    var elem4 = document.getElementById("d");

    // 根据a的值设置元素的显示或隐藏
    if (URLType == 0){
        elem1.style.display = "block";
        elem2.style.display = "none";
        elem3.style.display = "none";
        elem4.style.display = "none";
    } else if (URLType == 1) {
        elem1.style.display = "block"; // 显示id为a的元素
        elem2.style.display = "none"; // 隐藏id为b的元素
        elem3.style.display = "none";
        elem4.style.display = "none";
        ChangeURL() // 自动适配链接地址
    } else if (URLType == 2) {
        elem1.style.display = "none"; // 隐藏id为a的元素
        elem2.style.display = "block"; // 显示id为b的元素
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

function ChangeURL() {
    // 将所有具有 custom-link 类的链接的域名更改为当前域名
    var links = document.querySelectorAll('.custom-link');
    var currentHost = window.location.host;

    links.forEach(function(link) {
        var updatedHref = link.href.replace('host', currentHost);
        link.href = updatedHref;
    });
}

// 当文档加载完成时，执行回调函数
document.addEventListener("DOMContentLoaded", () => {
    // 为按钮添加点击事件，调用设置语言选择的函数
    var LanguageButton = document.querySelector(".SwitchLanguage");
    LanguageButton.addEventListener("click", () => {

        // 获取 <html> 元素的 lang 属性来识别页面语言 【作废】
        //var htmlElement = document.querySelector("html");

        // 如果语言切换按钮的 lang 属性为“en”就切换为英文页面
        if (LanguageButton.getAttribute("lang") === "en") {
            setLanguage("en");
        } else if (LanguageButton.getAttribute("lang") === "zh-cn") {
            // 如果语言切换按钮的 lang 属性为“zh-cn”就切换为中文页面
            setLanguage("zh-cn");
        } else {
            console.error("Error in lang attribute of <button> markup");
        }
    });


    // 如果处于黑暗模式，就把Ubuntu Logo换成对应的图片
    var logo = document.getElementById("logo");
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        logo.src = "./images/ubuntu-logo_dark.png";
    }

    var URLType = CompareURL();
    var lang = document.documentElement.lang.toLowerCase();
    if (lang === 'zh-cn') {
        console.log("访问方式检测返回值为：" + URLType);
    } else {
        console.log("The return value of the access method detection is: " + URLType);
    }
    SwitchPageType(URLType); // 隐藏不需要的元素


    // 获取当前页面的协议
    var currentProtocol = window.location.protocol;

    // 如果当前页面是 HTTPS 协议
    if (currentProtocol === 'https:') {

        // 获取页面中的所有链接元素
        var links = document.getElementsByTagName('a');

        // 循环遍历每个链接元素
        for (var i = 0; i < links.length; i++) {
            var link = links[i];

            // 检查链接是否有特定的 class 属性,如果 class 属性为“change-protocol”就更改链接
            if (link.classList.contains('change-protocol')) {
                // 获取链接的 href 属性值
                var href = link.getAttribute('href');

                // 如果当前页面是 HTTPS 协议，将链接的 http:// 替换为 https://
                if (currentProtocol === 'https:' && href.startsWith('http://')) {
                    href = href.replace('http://', 'https://');
                    link.setAttribute('href', href);
                }
            }
        }
    }

});

var url = getAddress(url);

// 在页面加载时调用检查语言选择的函数
window.addEventListener("load", RedirectPage);

// 引用了https://www.runoob.com/js/js-cookies.html ， https://www.runoob.com/html/html5-webstorage.html 的一些代码