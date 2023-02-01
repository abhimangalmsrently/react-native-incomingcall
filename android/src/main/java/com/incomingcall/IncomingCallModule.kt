package com.incomingcall

import android.content.Intent
import android.os.Build
import android.view.View
import androidx.annotation.RequiresApi
import com.facebook.react.bridge.*
import com.facebook.react.bridge.UiThreadUtil.runOnUiThread
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import com.facebook.react.uimanager.IllegalViewOperationException


class IncomingCallModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return Constants.INCOMING_CALL
  }

  @RequiresApi(Build.VERSION_CODES.O)
  @ReactMethod
  fun showIncomingCall(options: ReadableMap?) {
    reactApplicationContext.stopService(
      Intent(
        reactApplicationContext,
        CallService::class.java
      )
    )
    val intent = Intent(reactApplicationContext, CallService::class.java)
    intent.putExtra("channelName", options?.getString("channelName"))
    intent.putExtra("channelId", options?.getString("channelId"))
    intent.putExtra("timeout", options?.getDouble("timeout")?.toLong())
    intent.putExtra("component", options?.getString("component"))
    intent.putExtra("callerName", options?.getString("callerName"))
    intent.putExtra("accessToken", options?.getString("accessToken"))
    reactApplicationContext.startForegroundService(intent)
  }

  @ReactMethod
  fun endCall() {
      reactApplicationContext.stopService(
          Intent(
              reactApplicationContext,
              CallService::class.java
          )
      )

    if(CallingActivity.active){
      reactApplicationContext.sendBroadcast(Intent(Constants.ACTION_END_INCOMING_CALL))
    }
    if(AnswerCallActivity.active){
      reactApplicationContext.sendBroadcast(Intent(Constants.ACTION_END_ACTIVE_CALL))
    }
  }

  @ReactMethod
  fun sendEventToJs(eventName: String, params: WritableMap?) {
    reactApplicationContext?.getJSModule(RCTDeviceEventEmitter::class.java)
      ?.emit(eventName, params)
  }

  private fun setSystemUIFlags(visibility: Int, promise: Promise) {
    try {
      runOnUiThread {
        val requiredVersion = Build.VERSION_CODES.LOLLIPOP
        if (Build.VERSION.SDK_INT < requiredVersion) {
          promise.reject("Error: ", errorMessage(requiredVersion))
          return@runOnUiThread
        }
        val currentActivity = currentActivity
        if (currentActivity == null) {
          promise.reject("Error: ", "current activity is null")
          return@runOnUiThread
        }
        val decorView = currentActivity.window.decorView
        decorView.systemUiVisibility = visibility
      }
      promise.resolve("true")
    } catch (e: IllegalViewOperationException) {
      e.printStackTrace()
      promise.reject("Error: ", e.message)
    }
  }

  private fun errorMessage(version: Int): String? {
    return "Your device version: " + Build.VERSION.SDK_INT + ". Supported API Level: " + version
  }

  /* Sticky Immersive */
  @ReactMethod
  fun stickyImmersive(promise: Promise?) {
    setSystemUIFlags(
      (View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
        View.SYSTEM_UI_FLAG_FULLSCREEN or
        View.SYSTEM_UI_FLAG_HIDE_NAVIGATION),
      (promise)!!
    )
  }
  
}
