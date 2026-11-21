package com.guoguanla;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@MapperScan("com.guoguanla.module.**.mapper")
public class GuoguanlaApplication {

    public static void main(String[] args) {
        SpringApplication.run(GuoguanlaApplication.class, args);
    }
}
