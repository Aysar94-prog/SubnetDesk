package com.carriez.flutter_hbb

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.security.KeyStore
import java.util.Locale
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Only ciphertext is written; both username and password are inside the payload. */
object LanCredentialStore {
    private const val ALIAS = "SubnetDesk.LANCredentials.v1"
    private const val MAX_PAYLOAD = 322 // u16 length + username64 + password256
    private const val HEADER_SIZE = 17 // magic4 + version1 + nonce12
    private val magic = byteArrayOf(83, 68, 76, 67, 1)

    private fun fingerprint(value: String): String {
        require(value.length == 64 && value.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' })
        return value.lowercase(Locale.ROOT)
    }

    private fun file(context: Context, fingerprint: String): AtomicFile {
        val directory = File(context.applicationContext.noBackupFilesDir, "lan_credentials_v1")
        if (!directory.isDirectory && !directory.mkdirs()) throw IOException("Credential store unavailable")
        return AtomicFile(File(directory, fingerprint))
    }

    private fun key(create: Boolean): SecretKey {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) { "Encrypted credential storage unavailable" }
        val store = KeyStore.getInstance("AndroidKeyStore")
        store.load(null)
        val existing = store.getKey(ALIAS, null)
        if (existing != null) return existing as SecretKey
        check(create) { "Credential encryption key unavailable" }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(256)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build())
        return generator.generateKey()
    }

    private fun aad(fingerprint: String) = "$ALIAS:$fingerprint".toByteArray(Charsets.UTF_8)

    @JvmStatic @Synchronized
    fun save(context: Context, deviceFingerprint: String, payload: ByteArray) {
        try {
            val fingerprint = fingerprint(deviceFingerprint)
            require(payload.size in 4..MAX_PAYLOAD)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            // Keystore generates the random IV; caller-supplied encryption IVs are forbidden.
            cipher.init(Cipher.ENCRYPT_MODE, key(true))
            cipher.updateAAD(aad(fingerprint))
            val nonce = cipher.iv
            check(nonce.size == 12)
            val ciphertext = cipher.doFinal(payload)
            val atomic = file(context, fingerprint)
            val stream = atomic.startWrite()
            try {
                stream.write(magic)
                stream.write(nonce)
                stream.write(ciphertext)
                atomic.finishWrite(stream)
            } catch (error: Exception) {
                atomic.failWrite(stream)
                throw error
            }
        } finally {
            payload.fill(0)
        }
    }

    @JvmStatic @Synchronized
    fun load(context: Context, deviceFingerprint: String): ByteArray? {
        val fingerprint = fingerprint(deviceFingerprint)
        val atomic = file(context, fingerprint)
        val envelope = try {
            atomic.openRead().use { stream ->
                // A corrupted file cannot allocate unbounded application memory.
                val maximum = HEADER_SIZE + MAX_PAYLOAD + 16
                val bytes = ByteArray(maximum + 1)
                var count = 0
                while (count < bytes.size) {
                    val read = stream.read(bytes, count, bytes.size - count)
                    if (read < 0) break
                    count += read
                }
                require(count in (HEADER_SIZE + 20)..maximum)
                bytes.copyOf(count)
            }
        } catch (_: FileNotFoundException) {
            // Treat an unreadable existing entry as an error, not an absent password.
            if (atomic.baseFile.exists() || File(atomic.baseFile.path + ".bak").exists()) {
                throw IOException("Credential store unavailable")
            }
            return null
        }
        require(envelope.copyOfRange(0, 5).contentEquals(magic))
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, envelope.copyOfRange(5, HEADER_SIZE)))
        cipher.updateAAD(aad(fingerprint))
        return cipher.doFinal(envelope, HEADER_SIZE, envelope.size - HEADER_SIZE)
    }

    @JvmStatic @Synchronized
    fun has(context: Context, deviceFingerprint: String): Boolean {
        val payload = load(context, deviceFingerprint) ?: return false
        payload.fill(0)
        return true
    }

    @JvmStatic @Synchronized
    fun forget(context: Context, deviceFingerprint: String) {
        val atomic = file(context, fingerprint(deviceFingerprint))
        atomic.delete()
        for (suffix in arrayOf("", ".bak", ".new")) {
            if (File(atomic.baseFile.path + suffix).exists()) throw IOException("Cannot remove saved credential")
        }
        // Keep the master key: other peers' credentials still need it.
    }
}
