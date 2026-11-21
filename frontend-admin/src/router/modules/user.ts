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
    },
    {
      path: "/user/detail/:id",
      name: "StudentUserDetail",
      component: () => import("@/views/user/detail/index.vue"),
      meta: {
        title: "学生详情与作业批改",
        showLink: false,
        activePath: "/user/index"
      }
    }
  ]
} satisfies RouteConfigsTable;
