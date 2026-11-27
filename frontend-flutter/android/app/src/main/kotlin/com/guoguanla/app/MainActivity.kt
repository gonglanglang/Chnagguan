package com.guoguanla.app

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val SHARE_CHANNEL = "com.guoguanla.app/file_share"
        private const val WECHAT_PACKAGE = "com.tencent.mm"
        private const val DOCX_MIME =
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isWeChatInstalled" -> {
                        result.success(isWeChatInstalled())
                    }
                    "shareToWeChat" -> {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val mimeType = call.argument<String>("mimeType") ?: DOCX_MIME
                        val title = call.argument<String>("title") ?: "过关啦错题本"
                        result.success(shareFileToWeChat(filePath, mimeType, title))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isWeChatInstalled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    WECHAT_PACKAGE,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(WECHAT_PACKAGE, 0)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun shareFileToWeChat(filePath: String, mimeType: String, title: String): Boolean {
        if (filePath.isBlank() || !isWeChatInstalled()) return false
        val file = File(filePath)
        if (!file.exists()) return false
        return try {
            val authority = "${applicationContext.packageName}.ggl_fileprovider"
            val uri = FileProvider.getUriForFile(this, authority, file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, title)
                putExtra(Intent.EXTRA_TEXT, title)
                setPackage(WECHAT_PACKAGE)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            grantUriPermission(WECHAT_PACKAGE, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            val resolved = intent.resolveActivity(packageManager)
            if (resolved != null) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }
}
