package com.carriez.flutter_hbb;

import android.app.Instrumentation;
import android.os.Bundle;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.security.SecureRandom;
import java.util.Arrays;

/** Framework-only driver: release shrinking must not remove a test-only Kotlin dependency. */
public final class CredentialStoreInstrumentation extends Instrumentation {
    private static String fingerprint(SecureRandom random) {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        char[] hex = "0123456789abcdef".toCharArray();
        StringBuilder value = new StringBuilder(64);
        for (byte item : bytes) {
            value.append(hex[(item & 255) >>> 4]);
            value.append(hex[item & 15]);
        }
        return value.toString();
    }

    private static void require(boolean condition) {
        if (!condition) throw new AssertionError();
    }

    private static byte[] read(File file) throws Exception {
        require(file.length() > 0 && file.length() <= 512);
        byte[] bytes = new byte[(int) file.length()];
        try (FileInputStream input = new FileInputStream(file)) {
            int count = 0;
            while (count < bytes.length) {
                int next = input.read(bytes, count, bytes.length - count);
                require(next > 0);
                count += next;
            }
            require(input.read() == -1);
        }
        return bytes;
    }

    private static void write(File file, byte[] bytes) throws Exception {
        try (FileOutputStream output = new FileOutputStream(file)) {
            output.write(bytes);
        }
    }

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        start();
    }

    @Override public void onStart() {
        Bundle result = new Bundle();
        SecureRandom random = new SecureRandom();
        String first = fingerprint(random);
        String second = fingerprint(random);
        String stage = "absent";
        boolean passed = false;
        // Password-only minimum payload: zero username length and one password byte.
        byte[] payload = new byte[] {0, 0, 112};
        try {
            require(LanCredentialStore.load(getTargetContext(), first) == null);
            stage = "save_load";
            LanCredentialStore.save(getTargetContext(), first, payload.clone());
            require(LanCredentialStore.has(getTargetContext(), first));
            require(Arrays.equals(LanCredentialStore.load(getTargetContext(), first), payload));
            require(LanCredentialStore.load(getTargetContext(), second) == null);
            File directory = new File(getTargetContext().getNoBackupFilesDir(), "lan_credentials_v1");
            File entry = new File(directory, first);
            byte[] original = read(entry);
            stage = "random_nonce";
            LanCredentialStore.save(getTargetContext(), first, payload.clone());
            byte[] ciphertext = read(entry);
            require(!Arrays.equals(ciphertext, original) && ciphertext.length > payload.length);
            stage = "fingerprint_binding";
            // Only two cryptographically random synthetic entries, never real peer files.
            write(new File(directory, second), ciphertext);
            boolean rejected = false;
            try { LanCredentialStore.load(getTargetContext(), second); }
            catch (Exception ignored) { rejected = true; }
            require(rejected);
            stage = "tamper";
            ciphertext[ciphertext.length - 1] ^= 1;
            write(entry, ciphertext);
            rejected = false;
            try { LanCredentialStore.load(getTargetContext(), first); }
            catch (Exception ignored) { rejected = true; }
            require(rejected);
            stage = "forget";
            LanCredentialStore.forget(getTargetContext(), first);
            LanCredentialStore.forget(getTargetContext(), second);
            require(LanCredentialStore.load(getTargetContext(), first) == null && !entry.exists());
            stage = "invalid_fingerprint";
            rejected = false;
            try { LanCredentialStore.load(getTargetContext(), "../peer"); }
            catch (Exception ignored) { rejected = true; }
            require(rejected);
            passed = true;
        } catch (Throwable ignored) {
            // Never report exception text, credentials, or file contents.
        } finally {
            Arrays.fill(payload, (byte) 0);
            try { LanCredentialStore.forget(getTargetContext(), first); }
            catch (Exception ignored) { passed = false; }
            try { LanCredentialStore.forget(getTargetContext(), second); }
            catch (Exception ignored) { passed = false; }
        }
        result.putString("credential_store", passed ? "PASS" : "FAIL:" + stage);
        finish(passed ? 0 : 1, result);
    }
}
