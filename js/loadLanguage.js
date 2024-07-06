// 检查语言设置
function checkLanguage() {
    let cname=getLangCookie("lang");
    let languageSet;
    if (cname!="") {  // 通过检测变量 cname 是否为 "" 来检测cookie是否存在
        // cookie存在，设置变量 languageSet 为变量 cname
        languageSet = cname;
    } else {
        // 检查浏览器是否支持 localStorage
        if (typeof(Storage)!=="undefined") {
            // 支持 localStorage  sessionStorage 对象，读取localStorage
            let lname = localStorage.getItem("lang");
            if (lname!="null") {
                languageSet = lname;
            } else {
                // 获取用户的首选语言
                languageSet = navigator.language || navigator.userLanguage;
            }
        }
    }

    // 转为小写返回变量languageSet
    return languageSet.toLowerCase();
}

function RedirectPage() {
    // 获取之前存储的语言设置
    language = checkLanguage();

    // 规定目标语言列表
    let targetLanguagesList = ["en", "zh-cn"];
    if (targetLanguagesList.includes(language)) { // 当获取的语言在语言列表里时
        // 延期cookie
        setLangCookie(language);
        // 根据语言选择重定向到相应的html文件
        let targetUrl = language === "zh-cn" ? "index_zh.html" : "index.html";

        // 获取当前页面html元素的lang属性并将其转换为小写
        let currentPageLang = document.documentElement.lang.toLowerCase();
        if (currentPageLang === "") {
            console.error("无法获取到当前页面的语言！");
        } else if (currentPageLang !== language) { // 只有当当前的语言不是目标语言时，才进行重定向
            window.location.href = targetUrl;
        }
    } else {
        console.error("获取的语言不在语言列表里！");
    }
}

// 返回指定 cookie 值的函数
function getLangCookie(lang) {
    let name = lang + "=";
    let ca = document.cookie.split(';');
    for(let i=0; i<ca.length; i++) {
        let c = ca[i].trim();
        if (c.indexOf(name)==0) return c.substring(name.length,c.length);
    }
    return ""; // 如果没找到相应cookie返回 ""
}

// 设置cookie
function setLangCookie(language) {
    // 获取当前时间
    var now = new Date();
    // 设置过期时间为300天后
    now.setTime(now.getTime() + 300 * 24 * 60 * 60 * 1000);
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
}

RedirectPage();

// DOM完全加载和解析后运行的代码
document.addEventListener('DOMContentLoaded', function() {
    // 为按钮添加点击事件，调用设置语言选择的函数
    var LanguageButton = document.querySelector(".SwitchLanguage");
    LanguageButton.addEventListener("click", () => {
        // 如果语言切换按钮的 lang 属性为“en”就切换为英文页面
        if (LanguageButton.getAttribute("lang") === "en") {
            setLanguage("en");
            // 重新加载页面
            location.reload();
        } else if (LanguageButton.getAttribute("lang") === "zh-cn") {
            // 如果语言切换按钮的 lang 属性为“zh-cn”就切换为中文页面
            setLanguage("zh-cn");
            // 重新加载页面
            location.reload();
        } else {
            console.error("Error in lang attribute of <button> markup");
        }
    });
});
