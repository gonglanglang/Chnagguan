export default {
  path: "/video",
  redirect: "/video/index",
  meta: {
    icon: "ep/video-camera",
    title: "教学视频",
    rank: 3
  },
  children: [
    {
      path: "/video/index",
      name: "VideoSeriesManage",
      component: () => import("@/views/video/index.vue"),
      meta: {
        title: "教学视频系列"
      }
    },
    {
      path: "/video/lessons/:seriesId",
      name: "VideoLessonManage",
      component: () => import("@/views/video/lessons/index.vue"),
      meta: {
        title: "管理系列课时",
        showLink: false,
        activePath: "/video/index"
      }
    }
  ]
} satisfies RouteConfigsTable;
