import { test } from 'bun:test'
import { runKotlinFixture } from './testing'

test('snapshot replacement preserves the previous checkpoint when staging or atomic replacement fails', async () => {
  const source = await Bun.file(new URL('../templates/CraftSnapshotFile.kt.template', import.meta.url)).text()
  await runKotlinFixture(source.replace('package {{PACKAGE_NAME}}\n', '') + `
fun main() {
    val directory = Files.createTempDirectory("craft-snapshot-test-").toFile()
    val destination = File(directory, "campaign.json")
    try {
        destination.writeText("{\\"tick\\":24}")
        val refused = CraftSnapshotFile(
            write = { file, bytes ->
                if (file == destination) {
                    file.writeText("{broken")
                    throw java.io.IOException("disk full during direct overwrite")
                }
                file.writeBytes(bytes)
            },
            replace = { _, _ -> throw java.io.IOException("atomic move refused") },
        )
        check(runCatching { refused.set(destination, "{\\"tick\\":25}") }.isFailure)
        check(destination.readText() == "{\\"tick\\":24}") { "A rejected replacement destroyed the prior checkpoint" }
        check(directory.listFiles()!!.map { it.name } == listOf("campaign.json")) { "Rejected staging files leaked" }

        val full = CraftSnapshotFile(write = { file, _ ->
            file.writeText("partial")
            throw java.io.IOException("disk full while staging")
        })
        check(runCatching { full.set(destination, "{\\"tick\\":25}") }.isFailure)
        check(destination.readText() == "{\\"tick\\":24}")
        check(directory.listFiles()!!.size == 1)

        CraftSnapshotFile().set(destination, "{\\"tick\\":25}")
        check(destination.readText() == "{\\"tick\\":25}")
        check(directory.listFiles()!!.size == 1)
        println("Snapshot atomic replacement, staging failure and replacement failure passed")
    } finally { directory.deleteRecursively() }
}
`)
}, 240_000)
