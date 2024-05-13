// 配置
window.Config = {

  // 站点名
  SiteName: '服务器状态监控',

  // 站点链接
  SiteUrl: './index.html',

  // UptimeRobot Api Keys
  // 支持 Monitor-Specific 和 Read-Only 两只 Api Key
  ApiKeys: [
    'm794607516-59103f34297a15e69ae6dece',
    'm794612021-d7a7a64d5dacc03e83a5abef',
    'm795402727-4e855e5a09af0d512f4e2697',
    'm795685589-b26be6c9082f4f68fcb582d1',
    'm796861405-6358a19f36471842c0930f59',
    'm796908583-c76f68887528c0ce685954c8'
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
      url: '/'
    }
  ]
};
