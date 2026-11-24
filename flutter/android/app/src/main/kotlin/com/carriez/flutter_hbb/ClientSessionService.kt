package com.carriez.flutter_hbb

// OAMap add-on 0003 (new file).
//
// Foreground service held only while an outgoing remote session (this phone
// controlling a PC) is open. It does no work; it just tells Android the app is
// in use so the process is not frozen / network-restricted when the user
// switches to another app. Started/stopped from remote_page.dart through the
// "client_session_fgs" method channel call (see MainActivity).

import ffi.FFI

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ClientSessionService : Service() {

    companion object {
        private const val CHANNEL_ID = "client_session"
        private const val NOTIFY_ID = 0x5E55

        fun setActive(context: Context, active: Boolean) {
            val intent = Intent(context, ClientSessionService::class.java)
            if (active) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                } catch (e: Exception) {
                    // e.g. ForegroundServiceStartNotAllowedException if somehow
                    // called from background: session still works, only less sticky.
                }
            } else {
                context.stopService(intent)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // Called from onCreate too: if the page closes right after opening, stopService
    // may come before onStartCommand, and Android 8-11 then crash with
    // "startForegroundService() did not then call startForeground()".
    override fun onCreate() {
        super.onCreate()
        goForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground()
        return START_NOT_STICKY
    }

    private fun goForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Remote session", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_stat_logo)
            .setContentTitle("원격 지원 연결 중")
            .setContentText("눌러서 원격 화면으로 돌아가기")
            .setContentIntent(open)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFY_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFY_ID, n)
        }
    }

    // Swiping the app away from recents: this service keeps the process alive,
    // so close outgoing sessions here like MainService.onTaskRemoved does,
    // otherwise a session survives with no UI left to close it.
    override fun onTaskRemoved(rootIntent: Intent?) {
        FFI.closeAllSessions()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }
}
