<script setup lang="ts">
import { onLaunch, onShow } from "@dcloudio/uni-app";
import { useThemeStore } from "@/store";
import { checkAppUpdate } from "@/utils/app-update";
import { enforceOrientationRepeatedly } from "@/utils/orientation";

onLaunch(() => {
  enforceOrientationRepeatedly();
  const themeStore = useThemeStore();
  themeStore.initTheme();
  setTimeout(() => {
    void checkAppUpdate({ silent: true });
  }, 1500);
});

onShow(() => {
  enforceOrientationRepeatedly();
});
</script>

<style lang="scss">
@use "@wot-ui/ui/styles/theme/index.scss" as *;
</style>
