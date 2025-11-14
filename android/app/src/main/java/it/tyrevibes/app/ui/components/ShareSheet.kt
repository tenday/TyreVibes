package it.tyrevibes.app.ui.components

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

/**
 * Share Sheet - Sistema di condivisione Android
 * Equivalente iOS UIActivityViewController
 */
object ShareSheet {

    /**
     * Condividi testo
     */
    fun shareText(context: Context, text: String, title: String = "Condividi") {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }

        val chooser = Intent.createChooser(intent, title)
        context.startActivity(chooser)
    }

    /**
     * Condividi URL
     */
    fun shareUrl(context: Context, url: String, title: String = "Condividi Link") {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, url)
        }

        val chooser = Intent.createChooser(intent, title)
        context.startActivity(chooser)
    }

    /**
     * Condividi file
     */
    fun shareFile(
        context: Context,
        fileUri: android.net.Uri,
        mimeType: String = "*/*",
        title: String = "Condividi File"
    ) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, fileUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(intent, title)
        context.startActivity(chooser)
    }

    /**
     * Condividi multipli file
     */
    fun shareMultipleFiles(
        context: Context,
        fileUris: ArrayList<android.net.Uri>,
        mimeType: String = "*/*",
        title: String = "Condividi File"
    ) {
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = mimeType
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, fileUris)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(intent, title)
        context.startActivity(chooser)
    }
}

/**
 * Composable helper per condivisione rapida
 */
@Composable
fun rememberShareSheet(): ShareSheetHelper {
    val context = LocalContext.current
    return ShareSheetHelper(context)
}

class ShareSheetHelper(private val context: Context) {
    fun shareText(text: String, title: String = "Condividi") {
        ShareSheet.shareText(context, text, title)
    }

    fun shareUrl(url: String, title: String = "Condividi Link") {
        ShareSheet.shareUrl(context, url, title)
    }

    fun shareFile(fileUri: android.net.Uri, mimeType: String = "*/*", title: String = "Condividi File") {
        ShareSheet.shareFile(context, fileUri, mimeType, title)
    }
}
