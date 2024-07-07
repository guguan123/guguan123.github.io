// 暂时将 JSON 数据存储在变量 `visibilityConfig` 中
var visibilityConfig = {
    "hostName":[
        {"host":"server2412", "type":0},
        {"host":"192.168.0.2", "type":0},
        {"host":"192.168.194.2", "type":0},
        {"host":"guguan30.top", "type":1},
        {"host":"guguan123.github.io", "type":2}
    ],
    "other_content_section_text": {
        "0": {
            "block": [{"element": "other_content_section_text_a"}],
            "none": [
                {"element": "other_content_section_text_b"},
                {"element": "other_content_section_text_c"}
            ]
        },
        "1": {
            "block": [{"element": "other_content_section_text_b"}],
            "none": [
                {"element": "other_content_section_text_a"},
                {"element": "other_content_section_text_c"}
            ]
        },
        "2": {
            "block": [{"element": "other_content_section_text_c"}],
            "none": [
                {"element": "other_content_section_text_a"},
                {"element": "other_content_section_text_b"}
            ]
        }
    }
};

function compareURL() {
    let result = visibilityConfig.hostName.find(item => item.host === window.location.hostname);
    if (result) {
        return result.type;
    } else {
        // 处理未找到匹配的情况，比如返回一个默认值或者抛出错误
        return 2; // 或者根据实际需求返回2
    }
}

function switchPageType(urlType) {
    // 获取当前类型的配置
    let config = visibilityConfig["other_content_section_text"][urlType];

    if (config) {
        // 显示 block 状态的元素
        config.block.forEach(function(item) {
            let elem = document.getElementById(item.element);
            if (elem) {
                elem.style.display = "block";
            }
        });

        // 隐藏 none 状态的元素
        config.none.forEach(function(item) {
            let elem = document.getElementById(item.element);
            if (elem) {
                elem.style.display = "none";
            }
        });
    } else {
        console.error("Invalid URLType:", urlType);
    }
}

function ChangeURL() {
    // 将所有具有 custom-link 类的链接的域名更改为当前域名
    let links = document.querySelectorAll('.custom-link');

    links.forEach(function(link) {
        link.href = link.href.replace('host', window.location.host);
    });
}

// 当文档加载完成时，执行回调函数
document.addEventListener("DOMContentLoaded", () => {
    let URLType = compareURL();
    console.log("访问方式检测返回值为：" + URLType);
    switchPageType(URLType); // 隐藏或显示相应的元素

    if (URLType === 0) {
        ChangeURL();
    }

    // 获取当前页面的协议
    let currentProtocol = window.location.protocol;

    // 如果当前页面是 HTTPS 协议
    if (currentProtocol === 'https:') {

        // 获取页面中的所有链接元素
        let links = document.getElementsByTagName('a');

        // 循环遍历每个链接元素
        for (let i = 0; i < links.length; i++) {
            let link = links[i];

            // 检查链接是否有特定的 class 属性,如果 class 属性为“change-protocol”就更改链接
            if (link.classList.contains('change-protocol')) {
                // 获取链接的 href 属性值
                let href = link.getAttribute('href');

                // 如果当前页面是 HTTPS 协议，将链接的 http:// 替换为 https://
                if (currentProtocol === 'https:' && href.startsWith('http://')) {
                    href = href.replace('http://', 'https://');
                    link.setAttribute('href', href);
                }
            }
        }
    }

});

// 引用了https://www.runoob.com/js/js-cookies.html ， https://www.runoob.com/html/html5-webstorage.html 的一些代码