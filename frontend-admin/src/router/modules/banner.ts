export default {
  path: "/banner",
  redirect: "/banner/index",
  meta: {
    icon: "ep/picture",
    title: "师资轮播管理",
    rank: 4
  },
  children: [
    {
      path: "/banner/index",
      name: "HomeBannerManage",
      component: () => import("@/views/banner/index.vue"),
      meta: {
        title: "师资力量轮播"
      }
    }
  ]
} satisfies RouteConfigsTable;
