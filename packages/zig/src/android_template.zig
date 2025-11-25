const std = @import("std");

/// Android Kotlin Template Generator
/// Generates complete Android app templates with Craft integration

pub const AndroidTemplate = struct {
    allocator: std.mem.Allocator,
    app_name: []const u8,
    package_name: []const u8,
    output_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, app_name: []const u8, package_name: []const u8, output_dir: []const u8) AndroidTemplate {
        return .{
            .allocator = allocator,
            .app_name = app_name,
            .package_name = package_name,
            .output_dir = output_dir,
        };
    }

    pub fn generate(self: *AndroidTemplate) !void {
        // Create directory structure
        try self.createDirectoryStructure();

        // Generate Kotlin files
        try self.generateMainActivity();
        try self.generateCraftBridge();
        try self.generateCameraXBridge();
        try self.generateBiometricsBridge();

        // Generate configuration files
        try self.generateAndroidManifest();
        try self.generateBuildGradle();
        try self.generateAppBuildGradle();
        try self.generateStringsXml();

        std.debug.print("Android template generated successfully at: {s}\n", .{self.output_dir});
    }

    fn createDirectoryStructure(self: *AndroidTemplate) !void {
        const cwd = std.fs.cwd();

        const package_path = try std.mem.replaceOwned(u8, self.allocator, self.package_name, ".", "/");
        defer self.allocator.free(package_path);

        const dirs = [_][]const u8{
            self.output_dir,
            try std.fmt.allocPrint(self.allocator, "{s}/app", .{self.output_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/app/src", .{self.output_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/app/src/main", .{self.output_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/app/src/main/java/{s}", .{ self.output_dir, package_path }),
            try std.fmt.allocPrint(self.allocator, "{s}/app/src/main/java/{s}/bridge", .{ self.output_dir, package_path }),
            try std.fmt.allocPrint(self.allocator, "{s}/app/src/main/java/{s}/features", .{ self.output_dir, package_path }),
            try std.fmt.allocPrint(self.allocator, "{s}/app/src/main/res", .{self.output_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/app/src/main/res/values", .{self.output_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/app/src/main/res/layout", .{self.output_dir}),
        };

        for (dirs) |dir| {
            cwd.makeDir(dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }
    }

    fn generateMainActivity(self: *AndroidTemplate) !void {
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\package {s}
            \\
            \\import android.os.Bundle
            \\import android.webkit.WebView
            \\import android.webkit.WebSettings
            \\import androidx.appcompat.app.AppCompatActivity
            \\import {s}.bridge.CraftBridge
            \\
            \\class MainActivity : AppCompatActivity() {{
            \\    private lateinit var webView: WebView
            \\    private lateinit var craftBridge: CraftBridge
            \\
            \\    override fun onCreate(savedInstanceState: Bundle?) {{
            \\        super.onCreate(savedInstanceState)
            \\        setContentView(R.layout.activity_main)
            \\
            \\        // Initialize WebView
            \\        webView = findViewById(R.id.webview)
            \\        configureWebView()
            \\
            \\        // Initialize Craft Bridge
            \\        craftBridge = CraftBridge(this, webView)
            \\        craftBridge.inject()
            \\
            \\        // Load initial URL
            \\        webView.loadUrl("http://10.0.2.2:3000") // Android emulator localhost
            \\    }}
            \\
            \\    private fun configureWebView() {{
            \\        webView.settings.apply {{
            \\            javaScriptEnabled = true
            \\            domStorageEnabled = true
            \\            databaseEnabled = true
            \\            mediaPlaybackRequiresUserGesture = false
            \\            allowFileAccess = false
            \\            allowContentAccess = false
            \\            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            \\        }}
            \\
            \\        webView.webViewClient = android.webkit.WebViewClient()
            \\        webView.webChromeClient = android.webkit.WebChromeClient()
            \\    }}
            \\
            \\    override fun onBackPressed() {{
            \\        if (webView.canGoBack()) {{
            \\            webView.goBack()
            \\        }} else {{
            \\            super.onBackPressed()
            \\        }}
            \\    }}
            \\}}
            \\
        ,
            .{ self.package_name, self.package_name },
        );
        defer self.allocator.free(content);

        const package_path = try std.mem.replaceOwned(u8, self.allocator, self.package_name, ".", "/");
        defer self.allocator.free(package_path);

        const path = try std.fmt.allocPrint(self.allocator, "app/src/main/java/{s}/MainActivity.kt", .{package_path});
        defer self.allocator.free(path);

        try self.writeFile(path, content);
    }

    fn generateCraftBridge(self: *AndroidTemplate) !void {
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\package {s}.bridge
            \\
            \\import android.content.Context
            \\import android.os.Vibrator
            \\import android.webkit.JavascriptInterface
            \\import android.webkit.WebView
            \\import android.widget.Toast
            \\import org.json.JSONObject
            \\
            \\class CraftBridge(private val context: Context, private val webView: WebView) {{
            \\    private val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            \\
            \\    fun inject() {{
            \\        webView.addJavascriptInterface(this, "Android")
            \\
            \\        // Inject bridge script
            \\        val bridgeScript = """
            \\            window.craft = window.craft || {{}};
            \\            window.craft.invoke = function(method, params) {{
            \\                return new Promise((resolve, reject) => {{
            \\                    const messageId = Date.now() + '_' + Math.random();
            \\                    window.Android.postMessage(JSON.stringify({{
            \\                        id: messageId,
            \\                        method: method,
            \\                        params: params
            \\                    }}));
            \\                }});
            \\            }};
            \\        """.trimIndent()
            \\
            \\        webView.evaluateJavascript(bridgeScript, null)
            \\    }}
            \\
            \\    @JavascriptInterface
            \\    fun postMessage(message: String) {{
            \\        try {{
            \\            val json = JSONObject(message)
            \\            val method = json.getString("method")
            \\            val messageId = json.getString("id")
            \\            val params = if (json.has("params")) json.getJSONObject("params") else JSONObject()
            \\
            \\            handleMessage(method, params) {{ result ->
            \\                sendResponse(messageId, result)
            \\            }}
            \\        }} catch (e: Exception) {{
            \\            e.printStackTrace()
            \\        }}
            \\    }}
            \\
            \\    private fun handleMessage(method: String, params: JSONObject, callback: (JSONObject) -> Unit) {{
            \\        val result = JSONObject()
            \\
            \\        when (method) {{
            \\            "getPlatform" -> {{
            \\                result.put("platform", "android")
            \\                result.put("version", android.os.Build.VERSION.RELEASE)
            \\                callback(result)
            \\            }}
            \\
            \\            "showToast" -> {{
            \\                val message = params.getString("message")
            \\                val duration = if (params.optString("duration") == "long") Toast.LENGTH_LONG else Toast.LENGTH_SHORT
            \\                Toast.makeText(context, message, duration).show()
            \\                result.put("success", true)
            \\                callback(result)
            \\            }}
            \\
            \\            "vibrate" -> {{
            \\                val duration = params.optLong("duration", 50)
            \\                vibrator.vibrate(duration)
            \\                result.put("success", true)
            \\                callback(result)
            \\            }}
            \\
            \\            "requestPermission" -> {{
            \\                val permission = params.getString("permission")
            \\                // Permission handling will be implemented
            \\                result.put("granted", false)
            \\                result.put("message", "Not implemented")
            \\                callback(result)
            \\            }}
            \\
            \\            else -> {{
            \\                result.put("error", "Unknown method: $method")
            \\                callback(result)
            \\            }}
            \\        }}
            \\    }}
            \\
            \\    private fun sendResponse(messageId: String, result: JSONObject) {{
            \\        val response = JSONObject()
            \\        response.put("id", messageId)
            \\        response.put("success", !result.has("error"))
            \\        response.put("result", result)
            \\
            \\        val script = "window.craftHandleResponse('${{response.toString()}}')"
            \\        webView.post {{
            \\            webView.evaluateJavascript(script, null)
            \\        }}
            \\    }}
            \\}}
            \\
        ,
            .{self.package_name},
        );
        defer self.allocator.free(content);

        const package_path = try std.mem.replaceOwned(u8, self.allocator, self.package_name, ".", "/");
        defer self.allocator.free(package_path);

        const path = try std.fmt.allocPrint(self.allocator, "app/src/main/java/{s}/bridge/CraftBridge.kt", .{package_path});
        defer self.allocator.free(path);

        try self.writeFile(path, content);
    }

    fn generateCameraXBridge(self: *AndroidTemplate) !void {
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\package {s}.features
            \\
            \\import android.content.Context
            \\import androidx.camera.core.CameraSelector
            \\import androidx.camera.core.Preview
            \\import androidx.camera.lifecycle.ProcessCameraProvider
            \\import androidx.camera.view.PreviewView
            \\import androidx.core.content.ContextCompat
            \\import androidx.lifecycle.LifecycleOwner
            \\import com.google.common.util.concurrent.ListenableFuture
            \\
            \\class CameraXBridge(private val context: Context) {{
            \\    private lateinit var cameraProviderFuture: ListenableFuture<ProcessCameraProvider>
            \\
            \\    fun startCamera(lifecycleOwner: LifecycleOwner, previewView: PreviewView) {{
            \\        cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            \\
            \\        cameraProviderFuture.addListener({{
            \\            val cameraProvider = cameraProviderFuture.get()
            \\            bindPreview(cameraProvider, lifecycleOwner, previewView)
            \\        }}, ContextCompat.getMainExecutor(context))
            \\    }}
            \\
            \\    private fun bindPreview(
            \\        cameraProvider: ProcessCameraProvider,
            \\        lifecycleOwner: LifecycleOwner,
            \\        previewView: PreviewView
            \\    ) {{
            \\        val preview = Preview.Builder().build()
            \\        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            \\
            \\        preview.setSurfaceProvider(previewView.surfaceProvider)
            \\
            \\        try {{
            \\            cameraProvider.unbindAll()
            \\            cameraProvider.bindToLifecycle(lifecycleOwner, cameraSelector, preview)
            \\        }} catch (e: Exception) {{
            \\            e.printStackTrace()
            \\        }}
            \\    }}
            \\}}
            \\
        ,
            .{self.package_name},
        );
        defer self.allocator.free(content);

        const package_path = try std.mem.replaceOwned(u8, self.allocator, self.package_name, ".", "/");
        defer self.allocator.free(package_path);

        const path = try std.fmt.allocPrint(self.allocator, "app/src/main/java/{s}/features/CameraXBridge.kt", .{package_path});
        defer self.allocator.free(path);

        try self.writeFile(path, content);
    }

    fn generateBiometricsBridge(self: *AndroidTemplate) !void {
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\package {s}.features
            \\
            \\import android.content.Context
            \\import androidx.biometric.BiometricManager
            \\import androidx.biometric.BiometricPrompt
            \\import androidx.core.content.ContextCompat
            \\import androidx.fragment.app.FragmentActivity
            \\
            \\class BiometricsBridge(private val context: Context) {{
            \\    fun canAuthenticate(): Boolean {{
            \\        val biometricManager = BiometricManager.from(context)
            \\        return biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
            \\    }}
            \\
            \\    fun authenticate(activity: FragmentActivity, callback: (Boolean, String?) -> Unit) {{
            \\        val executor = ContextCompat.getMainExecutor(context)
            \\
            \\        val biometricPrompt = BiometricPrompt(activity, executor,
            \\            object : BiometricPrompt.AuthenticationCallback() {{
            \\                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {{
            \\                    super.onAuthenticationSucceeded(result)
            \\                    callback(true, null)
            \\                }}
            \\
            \\                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {{
            \\                    super.onAuthenticationError(errorCode, errString)
            \\                    callback(false, errString.toString())
            \\                }}
            \\
            \\                override fun onAuthenticationFailed() {{
            \\                    super.onAuthenticationFailed()
            \\                    callback(false, "Authentication failed")
            \\                }}
            \\            }})
            \\
            \\        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            \\            .setTitle("Biometric Authentication")
            \\            .setSubtitle("Log in using your biometric credential")
            \\            .setNegativeButtonText("Cancel")
            \\            .build()
            \\
            \\        biometricPrompt.authenticate(promptInfo)
            \\    }}
            \\}}
            \\
        ,
            .{self.package_name},
        );
        defer self.allocator.free(content);

        const package_path = try std.mem.replaceOwned(u8, self.allocator, self.package_name, ".", "/");
        defer self.allocator.free(package_path);

        const path = try std.fmt.allocPrint(self.allocator, "app/src/main/java/{s}/features/BiometricsBridge.kt", .{package_path});
        defer self.allocator.free(path);

        try self.writeFile(path, content);
    }

    fn generateAndroidManifest(self: *AndroidTemplate) !void {
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\<?xml version="1.0" encoding="utf-8"?>
            \\<manifest xmlns:android="http://schemas.android.com/apk/res/android"
            \\    package="{s}">
            \\
            \\    <uses-permission android:name="android.permission.INTERNET" />
            \\    <uses-permission android:name="android.permission.CAMERA" />
            \\    <uses-permission android:name="android.permission.VIBRATE" />
            \\    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
            \\    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
            \\
            \\    <application
            \\        android:allowBackup="true"
            \\        android:icon="@mipmap/ic_launcher"
            \\        android:label="@string/app_name"
            \\        android:roundIcon="@mipmap/ic_launcher_round"
            \\        android:supportsRtl="true"
            \\        android:theme="@style/Theme.AppCompat.Light.DarkActionBar"
            \\        android:usesCleartextTraffic="true">
            \\        <activity
            \\            android:name=".MainActivity"
            \\            android:exported="true">
            \\            <intent-filter>
            \\                <action android:name="android.intent.action.MAIN" />
            \\                <category android:name="android.intent.category.LAUNCHER" />
            \\            </intent-filter>
            \\        </activity>
            \\    </application>
            \\</manifest>
            \\
        ,
            .{self.package_name},
        );
        defer self.allocator.free(content);

        try self.writeFile("app/src/main/AndroidManifest.xml", content);
    }

    fn generateBuildGradle(self: *AndroidTemplate) !void {
        const content =
            \\// Top-level build file
            \\buildscript {
            \\    ext.kotlin_version = "1.9.0"
            \\    repositories {
            \\        google()
            \\        mavenCentral()
            \\    }
            \\    dependencies {
            \\        classpath "com.android.tools.build:gradle:8.1.0"
            \\        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
            \\    }
            \\}
            \\
            \\allprojects {
            \\    repositories {
            \\        google()
            \\        mavenCentral()
            \\    }
            \\}
            \\
            \\task clean(type: Delete) {
            \\    delete rootProject.buildDir
            \\}
            \\
        ;

        try self.writeFile("build.gradle", content);
    }

    fn generateAppBuildGradle(self: *AndroidTemplate) !void {
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\plugins {{
            \\    id 'com.android.application'
            \\    id 'kotlin-android'
            \\}}
            \\
            \\android {{
            \\    compileSdk 34
            \\
            \\    defaultConfig {{
            \\        applicationId "{s}"
            \\        minSdk 21
            \\        targetSdk 34
            \\        versionCode 1
            \\        versionName "1.0"
            \\    }}
            \\
            \\    buildTypes {{
            \\        release {{
            \\            minifyEnabled false
            \\            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            \\        }}
            \\    }}
            \\
            \\    compileOptions {{
            \\        sourceCompatibility JavaVersion.VERSION_1_8
            \\        targetCompatibility JavaVersion.VERSION_1_8
            \\    }}
            \\
            \\    kotlinOptions {{
            \\        jvmTarget = '1.8'
            \\    }}
            \\}}
            \\
            \\dependencies {{
            \\    implementation "org.jetbrains.kotlin:kotlin-stdlib:$kotlin_version"
            \\    implementation 'androidx.core:core-ktx:1.12.0'
            \\    implementation 'androidx.appcompat:appcompat:1.6.1'
            \\    implementation 'com.google.android.material:material:1.10.0'
            \\
            \\    // CameraX
            \\    implementation "androidx.camera:camera-core:1.3.0"
            \\    implementation "androidx.camera:camera-camera2:1.3.0"
            \\    implementation "androidx.camera:camera-lifecycle:1.3.0"
            \\    implementation "androidx.camera:camera-view:1.3.0"
            \\
            \\    // Biometrics
            \\    implementation "androidx.biometric:biometric:1.1.0"
            \\}}
            \\
        ,
            .{self.package_name},
        );
        defer self.allocator.free(content);

        try self.writeFile("app/build.gradle", content);
    }

    fn generateStringsXml(self: *AndroidTemplate) !void {
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\<resources>
            \\    <string name="app_name">{s}</string>
            \\</resources>
            \\
        ,
            .{self.app_name},
        );
        defer self.allocator.free(content);

        try self.writeFile("app/src/main/res/values/strings.xml", content);
    }

    fn writeFile(self: *AndroidTemplate, relative_path: []const u8, content: []const u8) !void {
        const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.output_dir, relative_path });
        defer self.allocator.free(full_path);

        const cwd = std.fs.cwd();
        const file = try cwd.createFile(full_path, .{});
        defer file.close();

        try file.writeAll(content);
    }
};

// Test
test "Android template generation" {
    const allocator = std.testing.allocator;
    var template = AndroidTemplate.init(allocator, "TestApp", "com.test.app", "test_android_output");

    // Would generate files - skipping in test
    _ = template;
}
