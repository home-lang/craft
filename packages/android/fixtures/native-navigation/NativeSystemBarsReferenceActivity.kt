package dev.craft.navigationtest

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.WindowInsetsController
import android.widget.TextView

/** Test-only stock Android comparison, without Craft views or services. */
class NativeSystemBarsReferenceActivity : Activity() {
    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        if (intent.getBooleanExtra("stockTheme", false)) {
            setTheme(android.R.style.Theme_Material_Light_NoActionBar)
        }
        super.onCreate(savedInstanceState)
        val background = intent.getIntExtra("background", Color.BLACK)
        val light = Color.luminance(background) >= 0.5f
        window.setBackgroundDrawable(ColorDrawable(background))
        setContentView(TextView(this).apply {
            text = "Native Android system bars"
            gravity = Gravity.CENTER
            setTextColor(if (light) Color.BLACK else Color.WHITE)
            setBackgroundColor(background)
        })
        if (android.os.Build.VERSION.SDK_INT >= 35) {
            window.setDecorFitsSystemWindows(false)
            window.navigationBarColor = Color.TRANSPARENT
            window.isNavigationBarContrastEnforced = false
            val mask = WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS or
                WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
            window.insetsController?.setSystemBarsAppearance(if (light) mask else 0, mask)
        }
    }
}
