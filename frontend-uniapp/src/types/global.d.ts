// 全局类型声明文件

/// <reference types="@uni-helper/vite-plugin-uni-pages/client" />

declare global {
  /**
   * 分页查询参数
   */
  interface PageQuery {
    pageNum: number;
    pageSize: number;
  }

  /**
   * 后端分页响应对象（与 Java PageResult<T> 对齐）
   */
  interface PageResult<T> {
    records: T[];
    total: number;
    pageNum: number;
    pageSize: number;
  }

  /**
   * 统一接口响应数据（与 Java Result<T> 对齐）
   */
  interface ApiResponse<T = any> {
    code: number;
    message: string;
    data: T;
    timestamp: number;
  }
}

export {};
