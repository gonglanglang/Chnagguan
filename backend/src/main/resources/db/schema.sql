-- ============================================================================
-- 过关啦 · 数学基础自测神器 —— 数据库表结构 (MySQL 8.0+ / utf8mb4)
-- 特点：支持未来题型扩展（单选/多选/填空/判断/动态模板）、题目版本与作答快照隔离
-- ============================================================================

-- 1. 后台管理员表
CREATE TABLE IF NOT EXISTS sys_admin (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '管理员ID',
  username VARCHAR(64) NOT NULL COMMENT '登录账号',
  password_hash VARCHAR(128) NOT NULL COMMENT 'BCrypt加密密码',
  real_name VARCHAR(64) NOT NULL COMMENT '姓名/昵称',
  avatar_url VARCHAR(255) NOT NULL DEFAULT '' COMMENT '头像',
  role_code VARCHAR(32) NOT NULL DEFAULT 'TEACHER' COMMENT '角色：SUPER_ADMIN / TEACHER',
  status TINYINT NOT NULL DEFAULT 1 COMMENT '状态：1启用 0禁用',
  last_login_at DATETIME DEFAULT NULL COMMENT '最后登录时间',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删 1已删',
  PRIMARY KEY (id),
  UNIQUE KEY uk_admin_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台管理员表';

-- 2. 学生用户表
CREATE TABLE IF NOT EXISTS app_user (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  username VARCHAR(64) DEFAULT NULL COMMENT '登录账号',
  password_hash VARCHAR(128) DEFAULT NULL COMMENT '密码哈希（微信登录可空）',
  phone VARCHAR(20) DEFAULT NULL COMMENT '手机号',
  wx_openid VARCHAR(64) DEFAULT NULL COMMENT '微信小程序OpenID',
  wx_unionid VARCHAR(64) DEFAULT NULL COMMENT '微信UnionID',
  nickname VARCHAR(64) NOT NULL DEFAULT '数学小学徒' COMMENT '学生昵称',
  avatar_url VARCHAR(255) NOT NULL DEFAULT '' COMMENT '头像地址',
  grade_code VARCHAR(16) NOT NULL DEFAULT 'g7' COMMENT '对应年级编码 g7/g8/g9/h1/h2/h3',
  realm_code VARCHAR(24) NOT NULL DEFAULT 'lianqi' COMMENT '当前修仙境界 lianqi/zhuji/jiedan/jiaying/yuanying/huashen',
  passed_gate_count INT NOT NULL DEFAULT 0 COMMENT '累计已过关数',
  current_level_id BIGINT UNSIGNED DEFAULT 1 COMMENT '当前段位ID',
  ext_json JSON DEFAULT NULL COMMENT '扩展属性（如班级/学号/积分/个性标签，便于后期扩展）',
  remark VARCHAR(255) NOT NULL DEFAULT '' COMMENT '后台备注',
  status TINYINT NOT NULL DEFAULT 1 COMMENT '状态：1正常 0禁用',
  last_active_at DATETIME DEFAULT NULL COMMENT '最后活跃时间',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删 1已删',
  PRIMARY KEY (id),
  UNIQUE KEY uk_app_username (username),
  UNIQUE KEY uk_app_phone (phone),
  UNIQUE KEY uk_app_wx_openid (wx_openid),
  KEY idx_app_grade_status (grade_code, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='前台学生用户表';

-- 3. 年级表
CREATE TABLE IF NOT EXISTS edu_grade (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  grade_code VARCHAR(16) NOT NULL COMMENT 'g7/g8/g9/h1/h2/h3',
  grade_name VARCHAR(32) NOT NULL COMMENT '年级显示名称',
  icon VARCHAR(32) NOT NULL DEFAULT '🌱' COMMENT '图标',
  sort_order INT NOT NULL DEFAULT 0 COMMENT '排序',
  enabled TINYINT NOT NULL DEFAULT 1 COMMENT '1启用 0隐藏',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_grade_code (grade_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='年级配置表';

-- 4. 章节表
CREATE TABLE IF NOT EXISTS edu_chapter (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  chapter_code VARCHAR(32) NOT NULL COMMENT '章节编码（如 c1..c51 或后台自定义编码）',
  grade_code VARCHAR(16) NOT NULL COMMENT '所属年级编码',
  name VARCHAR(100) NOT NULL COMMENT '章节名称',
  description VARCHAR(255) NOT NULL DEFAULT '' COMMENT '知识点简介',
  is_custom TINYINT NOT NULL DEFAULT 0 COMMENT '0内置章节 1教研新增章节',
  ext_json JSON DEFAULT NULL COMMENT '扩展元数据',
  sort_order INT NOT NULL DEFAULT 0 COMMENT '排序',
  enabled TINYINT NOT NULL DEFAULT 1 COMMENT '1上架展示 0下架隐藏',
  created_by BIGINT UNSIGNED DEFAULT NULL COMMENT '创建管理员ID',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_chapter_code (chapter_code),
  KEY idx_grade_sort (grade_code, sort_order, enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='数学章节表';

-- 5. 关卡配置表
CREATE TABLE IF NOT EXISTS edu_gate (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  chapter_id BIGINT UNSIGNED NOT NULL COMMENT '关联章节ID',
  gate_index TINYINT NOT NULL COMMENT '关卡顺序 0基础 1中档 2拓展 3压轴',
  gate_name VARCHAR(32) NOT NULL COMMENT '关卡名称',
  star TINYINT NOT NULL DEFAULT 1 COMMENT '星级 1~5',
  question_count INT NOT NULL DEFAULT 3 COMMENT '每次闯关抽取题数',
  pass_count INT NOT NULL DEFAULT 2 COMMENT '过关至少答对题数',
  enabled TINYINT NOT NULL DEFAULT 1 COMMENT '1启用 0禁用',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_chap_gate (chapter_id, gate_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='章节关卡配置表';

-- 6. 题目主表（弹性结构：支持单选/多选/填空/判断 + 静态/动态模板 + 版本化 + 扩展字段）
CREATE TABLE IF NOT EXISTS edu_question (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '题目ID',
  grade_code VARCHAR(16) NOT NULL COMMENT '所属年级编码',
  chapter_id BIGINT UNSIGNED NOT NULL COMMENT '所属章节ID',
  gate_id BIGINT UNSIGNED NOT NULL COMMENT '所属关卡ID',
  question_mode VARCHAR(24) NOT NULL DEFAULT 'STATIC' COMMENT '出题模式：STATIC静态 / DYNAMIC_TEMPLATE动态随机',
  question_format VARCHAR(24) NOT NULL DEFAULT 'SINGLE_CHOICE' COMMENT '题型：SINGLE_CHOICE单选 / MULTI_CHOICE多选 / FILL_BLANK填空 / JUDGE判断',
  stem TEXT NOT NULL COMMENT '题干内容',
  options_json JSON DEFAULT NULL COMMENT '选项JSON数组（如 ["3","-3","1/3","-1/3"]，动态题为示例选项）',
  answer_json JSON NOT NULL COMMENT '标准答案JSON（单选:{"index":0}，多选:{"indexes":[0,2]}，填空:{"values":["3"]}）',
  analysis TEXT DEFAULT NULL COMMENT '题目解析',
  generator_code VARCHAR(64) DEFAULT NULL COMMENT '内置动态生成器标识',
  template_rule_json JSON DEFAULT NULL COMMENT '动态模板规则JSON（支持 PARAM_TEMPLATE 或 PROTOTYPE_JS_EXPR）',
  difficulty TINYINT NOT NULL DEFAULT 1 COMMENT '难度星级 1~5',
  tags_json JSON DEFAULT NULL COMMENT '知识点标签JSON数组',
  ext_json JSON DEFAULT NULL COMMENT '扩展配置JSON（图片/LaTeX开关/分值/自定义属性，免改表扩展）',
  source VARCHAR(24) NOT NULL DEFAULT 'ADMIN' COMMENT '来源：PROTOTYPE原型 / ADMIN后台录入 / IMPORT批量导入',
  version INT NOT NULL DEFAULT 1 COMMENT '内容版本号（每次更新+1）',
  sort_order INT NOT NULL DEFAULT 0 COMMENT '排序权重',
  enabled TINYINT NOT NULL DEFAULT 1 COMMENT '1上架 0下架',
  created_by BIGINT UNSIGNED DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_q_gate_enabled (gate_id, enabled, deleted),
  KEY idx_q_grade_chap (grade_code, chapter_id, question_mode, question_format)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='弹性题库主表';

-- 7. 修仙境界与进阶配置表
CREATE TABLE IF NOT EXISTS edu_realm (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  realm_code VARCHAR(24) NOT NULL COMMENT '境界编码 lianqi/zhuji/jiedan/jiaying/yuanying/huashen',
  realm_name VARCHAR(32) NOT NULL COMMENT '境界名称',
  realm_order INT NOT NULL COMMENT '境界顺序 1~6',
  grade_code VARCHAR(16) NOT NULL COMMENT '对应题库年级难度 g7/g8/g9/h1/h2/h3',
  difficulty_label VARCHAR(32) NOT NULL COMMENT '通俗难度描述',
  description VARCHAR(255) NOT NULL DEFAULT '' COMMENT '境界说明',
  unlock_gates INT NOT NULL DEFAULT 0 COMMENT '解锁进阶考需通关数（0=本境界全部关卡）',
  exam_question_count INT NOT NULL DEFAULT 5 COMMENT '进阶考随机抽取题数',
  exam_pass_score INT NOT NULL DEFAULT 60 COMMENT '进阶及格分数线（0~100）',
  enabled TINYINT NOT NULL DEFAULT 1 COMMENT '1启用 0隐藏',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_realm_code (realm_code),
  UNIQUE KEY uk_realm_grade (grade_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='修仙境界与进阶规则表';

-- 8. 段位规则表（历史兼容保留）
CREATE TABLE IF NOT EXISTS edu_level_rule (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  min_gates INT NOT NULL COMMENT '累计过关门槛',
  icon VARCHAR(32) NOT NULL COMMENT '段位图标',
  level_name VARCHAR(64) NOT NULL COMMENT '段位名称',
  quote VARCHAR(255) NOT NULL COMMENT '激励台词',
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_min_gates (min_gates)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='段位晋升规则表';

-- 8. 用户关卡通关进度表
CREATE TABLE IF NOT EXISTS user_gate_progress (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  chapter_id BIGINT UNSIGNED NOT NULL,
  gate_id BIGINT UNSIGNED NOT NULL,
  gate_index TINYINT NOT NULL,
  is_passed TINYINT NOT NULL DEFAULT 0 COMMENT '1已过关 0未过关',
  best_correct INT NOT NULL DEFAULT 0 COMMENT '历史最高答对数',
  attempt_count INT NOT NULL DEFAULT 0 COMMENT '挑战次数',
  first_passed_at DATETIME DEFAULT NULL,
  last_played_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_user_gate (user_id, gate_id),
  KEY idx_user_chap (user_id, chapter_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户关卡通关进度表';

-- 9. 用户答题会话记录表
CREATE TABLE IF NOT EXISTS user_quiz_record (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  session_no VARCHAR(64) NOT NULL COMMENT '会话流水号',
  user_id BIGINT UNSIGNED NOT NULL,
  mode VARCHAR(24) NOT NULL DEFAULT 'GATE' COMMENT 'GATE闯关 / REDO_WRONG错题重做 / ADVANCE_EXAM进阶考核',
  realm_code VARCHAR(24) DEFAULT NULL COMMENT '挑战所属修仙境界',
  score INT DEFAULT NULL COMMENT '百分制得分（进阶考核用）',
  chapter_id BIGINT UNSIGNED DEFAULT NULL,
  gate_id BIGINT UNSIGNED DEFAULT NULL,
  question_snapshot_json JSON NOT NULL COMMENT '题目快照（含版本号/题干/选项/标准答案/作答，隔离题库后续修改）',
  total_count INT NOT NULL,
  correct_count INT NOT NULL DEFAULT 0,
  is_passed TINYINT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0进行中 1已交卷',
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  submitted_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_session_no (session_no),
  KEY idx_quiz_user_time (user_id, started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户答题记录与快照表';

-- 10. 用户错题本表
CREATE TABLE IF NOT EXISTS user_wrong_question (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED DEFAULT NULL,
  grade_code VARCHAR(16) NOT NULL,
  chapter_id BIGINT UNSIGNED NOT NULL,
  chapter_name VARCHAR(100) NOT NULL,
  gate_name VARCHAR(32) NOT NULL,
  stem_hash CHAR(64) NOT NULL COMMENT '去重哈希',
  stem TEXT NOT NULL COMMENT '错题发生时题干快照',
  question_format VARCHAR(24) NOT NULL DEFAULT 'SINGLE_CHOICE' COMMENT '题型：SINGLE_CHOICE / ESSAY',
  options_json JSON NOT NULL COMMENT '选项数组',
  answer_json JSON NOT NULL COMMENT '正确答案快照',
  last_answer_image_key VARCHAR(512) DEFAULT NULL COMMENT '解答题最近一次作答图OSS对象键',
  analysis TEXT DEFAULT NULL,
  wrong_count INT NOT NULL DEFAULT 1 COMMENT '错题次数',
  is_mastered TINYINT NOT NULL DEFAULT 0 COMMENT '0待攻克 1已掌握',
  last_wrong_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  mastered_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_user_hash (user_id, stem_hash),
  KEY idx_wrong_user_mastered (user_id, is_mastered, grade_code, last_wrong_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户错题本表';

-- 10.1 学生解答题画板与手写作答记录表
CREATE TABLE IF NOT EXISTS user_essay_answer (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  session_no VARCHAR(64) NOT NULL COMMENT '所属答题会话流水号',
  item_index INT NOT NULL DEFAULT 0 COMMENT '会话内题号',
  user_id BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '学生ID（0表示游客）',
  question_id BIGINT UNSIGNED DEFAULT NULL,
  grade_code VARCHAR(16) NOT NULL DEFAULT '',
  realm_code VARCHAR(24) NOT NULL DEFAULT '' COMMENT '所属修仙境界编码',
  chapter_id BIGINT UNSIGNED DEFAULT NULL,
  chapter_name VARCHAR(100) NOT NULL DEFAULT '',
  gate_id BIGINT UNSIGNED DEFAULT NULL COMMENT '所属关卡ID',
  gate_name VARCHAR(32) NOT NULL DEFAULT '',
  stem TEXT NOT NULL COMMENT '作答时具体题干快照',
  reference_answer TEXT DEFAULT NULL COMMENT '参考答案/评分要点',
  answer_text TEXT DEFAULT NULL COMMENT '学生文字补充作答',
  answer_image_key VARCHAR(512) DEFAULT NULL COMMENT '阿里云OSS私有对象键或相对存储路径',
  self_correct TINYINT DEFAULT NULL COMMENT '学生自评：1正确 0有误 NULL待核',
  teacher_status TINYINT NOT NULL DEFAULT 0 COMMENT '老师批改：0待批改 1通过 2待订正',
  teacher_comment VARCHAR(512) NOT NULL DEFAULT '',
  teacher_image_key VARCHAR(512) DEFAULT NULL COMMENT '老师PC端画板批注图OSS对象键',
  reviewed_by BIGINT UNSIGNED DEFAULT NULL,
  reviewed_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_session_item (session_no, item_index),
  KEY idx_essay_user_time (user_id, created_at),
  KEY idx_essay_gate_unique (user_id, realm_code, chapter_id, gate_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='学生解答题手写作答记录表';

-- 10.2 修炼教学视频系列表
CREATE TABLE IF NOT EXISTS edu_video_series (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  title VARCHAR(128) NOT NULL COMMENT '系列标题',
  cover_image_key VARCHAR(512) NOT NULL DEFAULT '' COMMENT '封面图OSS对象键或相对路径',
  intro TEXT DEFAULT NULL COMMENT '系列介绍',
  realm_code VARCHAR(24) NOT NULL DEFAULT '' COMMENT '关联修仙境界编码（空为全境界通用）',
  sort_order INT NOT NULL DEFAULT 0 COMMENT '排序权重',
  enabled TINYINT NOT NULL DEFAULT 1 COMMENT '1上架 0下架',
  created_by BIGINT UNSIGNED DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_video_series_realm (realm_code, enabled, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='修炼教学视频系列表';

-- 10.3 修炼教学视频课时表
CREATE TABLE IF NOT EXISTS edu_video_lesson (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  series_id BIGINT UNSIGNED NOT NULL COMMENT '所属系列ID',
  title VARCHAR(128) NOT NULL COMMENT '节标题',
  cover_image_key VARCHAR(512) NOT NULL DEFAULT '' COMMENT '小节封面图OSS对象键或相对路径',
  video_key VARCHAR(512) NOT NULL DEFAULT '' COMMENT '视频OSS对象键或相对路径',
  duration_sec INT NOT NULL DEFAULT 0 COMMENT '时长秒数',
  class_notes MEDIUMTEXT DEFAULT NULL COMMENT '课堂笔记备注',
  notes_attachments TEXT DEFAULT NULL COMMENT '课堂笔记附件JSON数组',
  sort_order INT NOT NULL DEFAULT 0 COMMENT '排序权重',
  enabled TINYINT NOT NULL DEFAULT 1 COMMENT '1上架 0下架',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_video_lesson_series (series_id, enabled, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='修炼教学视频课时表';

-- 11. 系统全局配置表
CREATE TABLE IF NOT EXISTS sys_config (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  config_key VARCHAR(64) NOT NULL,
  config_value VARCHAR(512) NOT NULL DEFAULT '',
  description VARCHAR(255) NOT NULL DEFAULT '',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_config_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统全局参数表';

-- 12. 后台操作审计日志表
CREATE TABLE IF NOT EXISTS sys_oper_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_id BIGINT UNSIGNED NOT NULL,
  admin_name VARCHAR(64) NOT NULL,
  module VARCHAR(32) NOT NULL COMMENT 'USER / CHAPTER / GATE / QUESTION / LEVEL / SYSTEM',
  action VARCHAR(64) NOT NULL,
  target_id VARCHAR(64) DEFAULT NULL,
  detail_json JSON DEFAULT NULL,
  ip VARCHAR(64) DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_oper_admin_time (admin_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台操作审计日志表';
