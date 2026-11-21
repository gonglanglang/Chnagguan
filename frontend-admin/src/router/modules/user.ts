export default {
  path: "/user",
  redirect: "/user/index",
  meta: {
    icon: "ep/user",
    title: "学生管理",
    rank: 1
  },
  children: [
    {
      path: "/user/index",
      name: "StudentUserManage",
      component: () => import("@/views/user/index.vue"),
      meta: {
        title: "学生列表与境界"
      }
    }
  ]
} satisfies RouteConfigsTable;
