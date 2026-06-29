package com.zerotech.zero_ring_app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class ZeroNotificationService : NotificationListenerService() {
  companion object {
    var instance: ZeroNotificationService? = null
    val notifications = mutableListOf<String>()
  }
  
  override fun onListenerConnected() {
    instance = this
  }
  
  override fun onNotificationPosted(sbn: StatusBarNotification) {
    val extras = sbn.notification.extras
    val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
    val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
    if (title.isNotEmpty() || text.isNotEmpty()) {
      notifications.add("$title: $text")
      if (notifications.size > 20) {
        notifications.removeAt(0)
      }
    }
  }
  
  override fun onListenerDisconnected() {
    instance = null
  }
}
