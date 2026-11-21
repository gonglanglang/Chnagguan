import { defineUniPages } from "@uni-helper/vite-plugin-uni-pages";

export default defineUniPages({
  globalStyle: {
    navigationStyle: "default",
    navigationBarTitleText: "过关啦",
    navigationBarBackgroundColor: "@navBgColor",
    navigationBarTextStyle: "@navTxtStyle",
    backgroundColor: "@bgColor",
    backgroundTextStyle: "@bgTxtStyle",
    backgroundColorTop: "@bgColorTop",
    backgroundColorBottom: "@bgColorBottom",
  },
  tabBar: {
    custom: true,
    height: "0",
    color: "@tabColor",
    selectedColor: "@tabSelectedColor",
    backgroundColor: "@tabBgColor",
    borderStyle: "@tabBorderStyle",
    list: [
      {
        pagePath: "pages/index/index",
        text: "首页",
      },
      {
        pagePath: "pages/cultivate/index",
        text: "修炼",
      },
      {
        pagePath: "pages/wrong/index",
        text: "错题本",
      },
      {
        pagePath: "pages/mine/index",
        text: "我的",
      },
    ],
  },
});
