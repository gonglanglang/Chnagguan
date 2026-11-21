package com.guoguanla.module.system.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

@Data
@TableName("edu_level_rule")
public class EduLevelRule {

    @TableId(type = IdType.AUTO)
    private Long id;
    private Integer minGates;
    private String icon;
    private String levelName;
    private String quote;
    private Integer sortOrder;
}
