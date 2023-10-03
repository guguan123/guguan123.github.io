// 配置
window.Config = {

  // 站点名
  SiteName: '服务器状态监控',

  // 站点链接
  SiteUrl: './index.html',

  // UptimeRobot Api Keys
  // 支持 Monitor-Specific 和 Read-Only 两只 Api Key
  ApiKeys: [
    'm794595568-24e01d0a152155ac1a0617fa',
    'm794596843-295afe311ab194a23c70aa61',
    'm794595585-1d0d7aaf0abc05ff145f3603',
    'm794600524-8c03625a22d10d5efe703cb7',
    'm794595596-620ae52f8f9eb6a95efb2c6d',
    'm794607516-59103f34297a15e69ae6dece',
    'm794612021-d7a7a64d5dacc03e83a5abef',
    'm794936575-0887d0befea43ff8ec1d7f61',
    'm795402718-6e347f045cd3c9090609b502',
  ],

  // 是否显示监测站点的链接
  ShowLink: true,

  // 日志天数
  // 虽然免费版说仅保存60天日志，但测试好像API可以获取90天的
  // 不过时间不要设置太长，容易卡，接口请求也容易失败
  CountDays: 60,

  // 导航栏菜单
  Navi: [
    {
      text: '首页',
      url: 'https://www.i-i.me/507.html'
    },
    {
      text: '关于此页面',
      url: 'https://github.com/KJZH001/uptimeStatusRevise'
    }
  ]
};
