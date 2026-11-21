import { reactive } from "vue";
import type { FormRules } from "element-plus";

export const REGEXP_PWD = /^.{6,32}$/;

/** 登录校验 */
const loginRules = reactive<FormRules>({
  password: [
    {
      validator: (_rule, value, callback) => {
        if (!value) {
          callback(new Error("请输入密码"));
        } else if (!REGEXP_PWD.test(value)) {
          callback(new Error("密码长度需为 6~32 位"));
        } else {
          callback();
        }
      },
      trigger: "blur"
    }
  ]
});

export { loginRules };
