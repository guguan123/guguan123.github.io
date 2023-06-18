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
  for(var i=0; i<ca.length; i++) 
  {
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

// 在页面加载时调用检查语言选择的函数
window.addEventListener("load", RedirectPage);

// 当文档加载完成时，执行回调函数
document.addEventListener("DOMContentLoaded", () => {
    // 为按钮添加点击事件，调用设置语言选择的函数
    var button = document.querySelector("button");
    button.addEventListener("click", () => {
        setLanguage(button.textContent);
    });
});

// 引用了https://www.runoob.com/js/js-cookies.html ， https://www.runoob.com/html/html5-webstorage.html 的相关代码