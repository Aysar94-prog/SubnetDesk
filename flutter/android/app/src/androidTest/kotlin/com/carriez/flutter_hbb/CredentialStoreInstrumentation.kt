package com.carriez.flutter_hbb

import android.app.Instrumentation
import android.os.Bundle
import java.io.File
import java.security.SecureRandom

/** Platform instrumentation only, no third-party test/runtime dependency. */
class CredentialStoreInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val result = Bundle()
        val random = SecureRandom()
        fun fingerprint(): String {
            val bytes = ByteArray(32)
            random.nextBytes(bytes)
            return bytes.joinToString("") { "%02x".format(it.toInt() and 255) }
        }
        val first = fingerprint()
        val second = fingerprint()
        var stage = "absent"
        var passed = false
        try {
            check(LanCredentialStore.load(targetContext, first) == null)
            val payload = byteArrayOf(0, 4, 117, 115, 101, 114, 116, 101, 115, 116)
            stage = "save_load"
            LanCredentialStore.save(targetContext, first, payload.clone())
            check(LanCredentialStore.has(targetContext, first))
            check(LanCredentialStore.load(targetContext, first)!!.contentEquals(payload))
            check(LanCredentialStore.load(targetContext, second) == null)
            val directory = File(targetContext.noBackupFilesDir, "lan_credentials_v1")
            val entry = File(directory, first)
            val original = entry.readBytes()
            stage = "random_nonce"
            LanCredentialStore.save(targetContext, first, payload.clone())
            val ciphertext = entry.readBytes()
            check(!ciphertext.contentEquals(original))
            check(ciphertext.size > payload.size)
            stage = "fingerprint_binding"
            // Test-only synthetic entries; never read or overwrite a real peer's file.
            File(directory, second).writeBytes(ciphertext)
            var rejected = false
            try { LanCredentialStore.load(targetContext, second) } catch (_: Exception) { rejected = true }
            check(rejected)
            stage = "tamper"
            ciphertext[ciphertext.lastIndex] = (ciphertext.last().toInt() xor 1).toByte()
            entry.writeBytes(ciphertext)
            rejected = false
            try { LanCredentialStore.load(targetContext, first) } catch (_: Exception) { rejected = true }
            check(rejected)
            stage = "forget"
            LanCredentialStore.forget(targetContext, first)
            LanCredentialStore.forget(targetContext, second)
            check(LanCredentialStore.load(targetContext, first) == null)
            check(!entry.exists())
            stage = "invalid_fingerprint"
            rejected = false
            try { LanCredentialStore.load(targetContext, "../peer") } catch (_: Exception) { rejected = true }
            check(rejected)
            payload.fill(0)
            passed = true
        } catch (_: Throwable) {
            // Report only the test stage, never exception text/credentials/file contents.
        } finally {
            try { LanCredentialStore.forget(targetContext, first) } catch (_: Exception) { passed = false }
            try { LanCredentialStore.forget(targetContext, second) } catch (_: Exception) { passed = false }
        }
        result.putString("credential_store", if (passed) "PASS" else "FAIL:$stage")
        finish(if (passed) 0 else 1, result)
    }
}
