document.addEventListener('DOMContentLoaded', function () {
	'use strict';

	// 获取带有 secure-link 类的 <a> 标签
	let secureLinks = document.querySelectorAll('a.url-obfuscation');

	// 解密函数
	let rot13 = (s => s.replace(/[a-zA-Z]/g, c => String.fromCharCode((c <= 'Z' ? 90 : 122) >= (c = c.charCodeAt(0) + 13) ? c : c - 26)));

	// 绑定监听器
	secureLinks.forEach(function (link) {
		link.addEventListener('click', function (event) {
			// 阻止默认行为
			event.preventDefault();

			let url = atob(rot13(this.getAttribute('data-url')));
			if (url && confirm('是否要跳转到外部链接 ' + url + ' ？')) window.open(url, '_blank', 'noopener');
		});
	});

	window.addEventListener("hashchange", function() {
		if (window.location.hash === "#url-obfuscation") {
			let url = prompt('请输入URL：');
			if (url) console.log(rot13(btoa(url)));
		}
	});
});
