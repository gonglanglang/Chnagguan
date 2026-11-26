export default {
  path: "/system",
  redirect: "/system/realm/index",
  meta: {
    icon: "ep/setting",
    title: "阶段与系统设置",
    rank: 4
  },
  children: [
    {
      path: "/system/realm/index",
      name: "RealmConfigManage",
      component: () => import("@/views/system/realm/index.vue"),
      meta: {
        title: "阶段与系统设置"
      }
    }
  ]
} satisfies RouteConfigsTable;
