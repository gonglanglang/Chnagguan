export default {
  path: "/bank",
  redirect: "/bank/question/index",
  meta: {
    icon: "ep/reading",
    title: "章节与题库",
    rank: 2
  },
  children: [
    {
      path: "/bank/question/index",
      name: "QuestionManage",
      component: () => import("@/views/bank/question/index.vue"),
      meta: {
        title: "题库管理"
      }
    },
    {
      path: "/bank/chapter/index",
      name: "ChapterManage",
      component: () => import("@/views/bank/chapter/index.vue"),
      meta: {
        title: "章节与关卡"
      }
    }
  ]
} satisfies RouteConfigsTable;
