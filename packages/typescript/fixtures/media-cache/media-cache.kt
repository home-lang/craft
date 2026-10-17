class DownloadProbe : android.app.Instrumentation() {
    override fun onCreate(arguments: android.os.Bundle?) {
        super.onCreate(arguments)
        args = arguments ?: android.os.Bundle()
        start()
    }
    private var args = android.os.Bundle()
    private var latestErrorCode: String? = null
    private val proof = StringBuilder()
    private fun check(yes: Boolean, message: String) {
        if (!yes) throw IllegalStateException(message)
        proof.append("PASS: ").append(message).append('\n')
        android.util.Log.i("CraftMediaProbe", "PASS: $message")
    }
    private fun keep(address: String): Boolean {
        val done = java.util.concurrent.CountDownLatch(1)
        var ok = false
        CraftNativeMedia.keep(targetContext, address, JSONObject(), true) {
            latestErrorCode = it.code
            ok = (it.data as? JSONObject)?.optBoolean("ok") == true
            done.countDown()
        }
        check(done.await(25, java.util.concurrent.TimeUnit.SECONDS), "operation settled")
        return ok
    }
    override fun onStart() {
        val result = android.os.Bundle()
        try {
            val base = args.getString("base")!!
            val restart = "$base/restart.mp4"
            when (args.getString("phase")) {
                "storage" -> {
                    CraftNativeMedia.prune(targetContext, emptyList())
                    val prefs = targetContext.getSharedPreferences("workout-recovery-probe", Context.MODE_PRIVATE)
                    val progress = """{"sets":["A1"],"note":"Keep this workout","rpe":7}"""
                    check(prefs.edit().putString("progress", progress).commit(), "workout progress is durable before storage failure")
                    val prefsDisk = File(targetContext.applicationInfo.dataDir, "shared_prefs/workout-recovery-probe.xml")
                    val savedPrefs = prefsDisk.readBytes()
                    val retained = "$base/retained.mp4"
                    check(keep(retained), "existing video is kept before storage pressure")
                    val original = CraftNativeMedia.local(targetContext, retained)!!.readBytes()
                    val fresh = "$base/storage.mp4"
                    val staging = File(CraftNativeMedia.file(targetContext, fresh).absolutePath + ".part")
                    val root = staging.parentFile!!
                    check(root.totalSpace in 1..(32L * 1024 * 1024), "storage pressure is confined to a bounded disposable volume")
                    val pressure = File(root, "pressure.mp4")
                    var written = 0L
                    pressure.outputStream().use { output ->
                        for (size in listOf(65536, 1024)) {
                            val chunk = ByteArray(size) { 0x5A.toByte() }
                            while (written < 32L * 1024 * 1024) {
                                try { output.write(chunk); written += size }
                                catch (error: java.io.IOException) { break }
                            }
                        }
                    }
                    check(written > 0 && root.usableSpace < 1024, "the probe cache filesystem is actually full")
                    check(!keep(fresh), "out-of-space write refuses a new video")
                    check(latestErrorCode == "NO_SPACE", "a full disk is reported as NO_SPACE, not a network failure")
                    check(CraftNativeMedia.local(targetContext, fresh) == null, "storage failure never publishes a partial video")
                    check(!staging.exists(), "storage failure removes staging files")
                    check(CraftNativeMedia.local(targetContext, retained)!!.readBytes().contentEquals(original), "storage failure preserves an existing video")
                    check(CraftNativeMedia.prune(targetContext, listOf(retained)) == 1, "cache cleanup frees the obsolete file and preserves the retained video")
                    check(prefs.getString("progress", null) == progress && prefsDisk.readBytes().contentEquals(savedPrefs), "cache cleanup preserves workout progress and feedback on disk")
                    check(keep(fresh), "same missing video downloads after cleanup")
                    val decoder = android.media.MediaMetadataRetriever()
                    try {
                        decoder.setDataSource(CraftNativeMedia.local(targetContext, fresh)!!.absolutePath)
                        check(decoder.getFrameAtTime(1000000) != null, "downloaded replacement plays from its local file")
                    } finally { decoder.release() }
                    check(prefs.getString("progress", null) == progress && prefsDisk.readBytes().contentEquals(savedPrefs), "redownloading leaves workout progress and feedback unchanged on disk")
                    CraftNativeMedia.prune(targetContext, emptyList())
                    prefs.edit().clear().commit()
                }
                "interrupt" -> {
                    CraftNativeMedia.prune(targetContext, emptyList())
                    CraftNativeMedia.keep(targetContext, restart, JSONObject(), true) {}
                    val target = CraftNativeMedia.file(targetContext, restart)
                    fun partial() = target.parentFile!!.listFiles()?.any { it.name.startsWith(target.name + ".") && it.name.endsWith(".part") && it.length() > 0 } == true
                    val until = System.currentTimeMillis() + 25000
                    while (!partial() && System.currentTimeMillis() < until) Thread.sleep(25)
                    check(partial(), "download is in progress before process death")
                    android.os.Process.killProcess(android.os.Process.myPid())
                }
                "recover" -> {
                    check(CraftNativeMedia.local(targetContext, restart) == null, "interrupted process never published a partial video")
                    check(keep(restart), "retry after process death downloads a complete video")
                    val media = android.media.MediaMetadataRetriever()
                    try {
                        media.setDataSource(CraftNativeMedia.local(targetContext, restart)!!.absolutePath)
                        check(media.getFrameAtTime(1000000) != null, "recovered local video decodes a frame without network")
                    } finally { media.release() }
                    CraftNativeMedia.prune(targetContext, emptyList())
                }
                else -> {
                    CraftNativeMedia.prune(targetContext, emptyList())
                    val broken = "$base/broken.mp4"
                    check(!keep(broken), "truncated transfer fails")
                    check(CraftNativeMedia.local(targetContext, broken) == null, "truncated transfer is not playable cache")
                    val root = CraftNativeMedia.file(targetContext, broken).parentFile!!
                    check(root.listFiles()?.none { it.name.endsWith(".part") } != false, "failed transfer cleans staging files")
                    check(keep(broken), "same URL retries successfully")
                    check(!keep("$base/partial.mp4"), "unsolicited partial response is refused")
                    check(!keep("$base/empty.mp4"), "empty file is refused")
                    val slow = "$base/slow.mp4"
                    val done = java.util.concurrent.CountDownLatch(2)
                    val answers = java.util.Collections.synchronizedList(mutableListOf<Boolean>())
                    repeat(2) { CraftNativeMedia.keep(targetContext, slow, JSONObject(), true) { answers.add((it.data as? JSONObject)?.optBoolean("ok") == true); done.countDown() } }
                    Thread.sleep(150)
                    CraftNativeMedia.prune(targetContext, emptyList())
                    check(done.await(25, java.util.concurrent.TimeUnit.SECONDS), "coalesced downloads settled")
                    check(answers.size == 2 && answers.all { it }, "concurrent downloads coalesce and survive prune")
                    check(root.listFiles()?.none { it.name.endsWith(".part") } != false, "no abandoned staging files remain")
                    CraftNativeMedia.prune(targetContext, emptyList())
                    val privateVideo = "$base/account/slow.mp4"
                    val previous = java.util.concurrent.CountDownLatch(1)
                    var cancelled = false
                    CraftNativeMedia.keep(targetContext, privateVideo, JSONObject(), true) { cancelled = it.code == "CANCELLED"; previous.countDown() }
                    val privateTarget = CraftNativeMedia.file(targetContext, privateVideo)
                    fun downloading() = root.listFiles()?.any { it.name.startsWith(privateTarget.name + ".") && it.name.endsWith(".part") && it.length() > 0 } == true
                    val deadline = System.currentTimeMillis() + 25000
                    while (!downloading() && System.currentTimeMillis() < deadline) Thread.sleep(10)
                    check(downloading(), "the previous athlete's download is in progress before sign-out")
                    CraftNativeMedia.clear(targetContext)
                    check(previous.await(5, java.util.concurrent.TimeUnit.SECONDS) && cancelled, "sign-out cancels the previous athlete's download")
                    check(CraftNativeMedia.local(targetContext, privateVideo) == null, "signed-out video is not playable from cache")
                    check(keep(privateVideo), "the next athlete downloads the same URL in a new transfer")
                    val media = android.media.MediaMetadataRetriever()
                    try {
                        media.setDataSource(CraftNativeMedia.local(targetContext, privateVideo)!!.absolutePath)
                        check(media.getFrameAtTime(1000000) != null, "the next athlete's local video decodes after the old download settles")
                    } finally { media.release() }
                    CraftNativeMedia.clear(targetContext)
                    check(CraftNativeMedia.local(targetContext, privateVideo) == null, "sign-out removes the next athlete's cached copy too")
                }
            }
            result.putString("stream", "${proof}PASS: ${args.getString("phase")} native download probe")
            finish(-1, result)
        } catch (error: Throwable) {
            result.putString("stream", "${proof}FAIL: ${error.stackTraceToString()}")
            finish(1, result)
        }
    }
}
