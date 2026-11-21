export default {
  path: "/system",
  redirect: "/system/realm/index",
  meta: {
    icon: "ep/setting",
    title: "境界与进阶设置",
    rank: 3
  },
  children: [
    {
      path: "/system/realm/index",
      name: "RealmConfigManage",
      component: () => import("@/views/system/realm/index.vue"),
      meta: {
        title: "境界与系统设置"
      }
    }
  ]
} satisfies RouteConfigsTable;
