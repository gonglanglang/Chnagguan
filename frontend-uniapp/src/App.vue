<script setup lang="ts">
import { onLaunch } from "@dcloudio/uni-app";
import { useThemeStore } from "@/store";
import { checkAppUpdate } from "@/utils/app-update";
import { lockPortraitOrientation } from "@/utils/orientation";

onLaunch(() => {
  lockPortraitOrientation();
  const themeStore = useThemeStore();
  themeStore.initTheme();
  setTimeout(() => {
    void checkAppUpdate({ silent: true });
  }, 1500);
});
</script>

<style lang="scss">
@use "@wot-ui/ui/styles/theme/index.scss" as *;
</style>
