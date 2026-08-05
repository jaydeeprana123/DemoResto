package com.innies.smartkitchenpos

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object KitchenAlertNotifications {
    private const val CHANNEL_NEW = "kitchen_new_order"
    private const val CHANNEL_UPDATE = "kitchen_update_order"
    private const val CHANNEL_DELETE = "kitchen_delete_order"

    private var nextNotificationId = 2000

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(buildChannel(context, CHANNEL_NEW, "New kitchen orders"))
        manager.createNotificationChannel(
            buildChannel(context, CHANNEL_UPDATE, "Kitchen order updates"),
        )
        manager.createNotificationChannel(
            buildChannel(context, CHANNEL_DELETE, "Kitchen order removed"),
        )
    }

    fun showAlert(context: Context, soundKey: String, title: String, body: String) {
        ensureChannels(context)

        val channelId = when (soundKey) {
            "update_bell" -> CHANNEL_UPDATE
            "delete_bell" -> CHANNEL_DELETE
            else -> CHANNEL_NEW
        }
        val rawSound = when (soundKey) {
            "update_bell" -> R.raw.update_bell
            "delete_bell" -> R.raw.delete_bell
            else -> R.raw.phone_bell
        }

        nextNotificationId++
        if (nextNotificationId > 2999) {
            nextNotificationId = 2000
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setOnlyAlertOnce(false)
            .setSound(
                android.net.Uri.parse("android.resource://${context.packageName}/$rawSound"),
            )
            .build()

        NotificationManagerCompat.from(context).notify(nextNotificationId, notification)
    }

    private fun buildChannel(
        context: Context,
        channelId: String,
        name: String,
    ): NotificationChannel {
        val rawSound = when (channelId) {
            CHANNEL_UPDATE -> R.raw.update_bell
            CHANNEL_DELETE -> R.raw.delete_bell
            else -> R.raw.phone_bell
        }

        return NotificationChannel(
            channelId,
            name,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = name
            setSound(
                android.net.Uri.parse("android.resource://${context.packageName}/$rawSound"),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            enableVibration(true)
        }
    }
}
