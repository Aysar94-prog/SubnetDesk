//! Optional access authority lives only in the interactive listener process.
//! Never persist/display codes via discovery, logs, or service-backed IPC.
use crate::lan_access_policy::{AccessPolicy, Rejection};
use hbb_common::sodiumoxide;
use std::{sync::Mutex, time::Instant};

lazy_static::lazy_static! { static ref POLICY: Mutex<AccessPolicy> = Mutex::new(AccessPolicy::automatic_codes()); }

fn issue_random_code(policy: &mut AccessPolicy, now: Instant) -> Result<(), &'static str> {
    if sodiumoxide::init().is_err() { return Err("Secure randomness is unavailable"); }
    for _ in 0..8 {
        let mut value = sodiumoxide::randombytes::randombytes_uniform(1_000_000);
        let mut digits = [b'0'; 6];
        for digit in digits.iter_mut().rev() { *digit += (value % 10) as u8; value /= 10; }
        if policy.is_previous_code(&digits) { digits.fill(0); continue; }
        let result = policy.issue_code(digits, now);
        digits.fill(0);
        return result.map_err(|_| "Temporary code is unavailable; wait before trying again");
    }
    Err("Unable to generate a new temporary code")
}

/// Called by the listener lifecycle, not by a UI checkbox/polling side effect.
pub(crate) fn maintain() {
    let available = available();
    let now = Instant::now();
    let mut policy = POLICY.lock().unwrap();
    if !available { policy.suspend(); return; }
    if policy.needs_code(now) {
        if let Err(error) = issue_random_code(&mut policy, now) {
            // Never fall back to weak randomness; unrelated manual requests remain intact.
            hbb_common::log::warn!("{error}");
        }
    }
}

pub(crate) fn available() -> bool {
    #[cfg(windows)]
    {
        crate::lan_server::LanServer::is_running()
            && !hbb_common::config::option2bool("stop-service", &hbb_common::config::Config::get_option("stop-service"))
            && crate::platform::optional_lan_access_available()
    }
    #[cfg(not(windows))]
    {
        false
    }
}

pub(crate) fn capabilities() -> (bool, bool) {
    if !available() {
        return (false, false);
    }
    POLICY.lock().unwrap().capabilities()
}

pub(crate) fn state_json() -> String {
    let available = available();
    let policy = POLICY.lock().unwrap();
    let (code_enabled, manual_enabled) = policy.capabilities();
    let code = if available {
        policy.visible_code(Instant::now())
    } else {
        None
    };
    serde_json::json!({"available": available, "code_enabled": code_enabled,
        "manual_enabled": manual_enabled, "code": code.map(|(value, _)| String::from_utf8_lossy(value).into_owned()).unwrap_or_default(),
        "expires_seconds": code.map(|(_, seconds)| seconds).unwrap_or(0),
        "retry_seconds": policy.retry_seconds(Instant::now())}).to_string()
}

pub(crate) fn configure(code: bool, manual: bool) -> Result<(), &'static str> {
    if (code || manual) && !available() {
        return Err("Optional access requires this unlocked Windows app to own the LAN listener");
    }
    POLICY.lock().unwrap().configure(code, manual);
    Ok(())
}

pub(crate) fn regenerate_code() -> Result<(), &'static str> {
    if !available() {
        return Err("Optional access is unavailable while locked or service-backed");
    }
    issue_random_code(&mut POLICY.lock().unwrap(), Instant::now())
}

pub(crate) fn consume_code(code: &str) -> Result<(), Rejection> {
    if !available() {
        return Err(Rejection::Disabled);
    }
    if code.len() != 6 || !code.as_bytes().iter().all(u8::is_ascii_digit) {
        return Err(Rejection::Invalid);
    }
    POLICY
        .lock()
        .unwrap()
        .consume_code(Instant::now(), |expected| {
            sodiumoxide::utils::memcmp(expected, code.as_bytes())
        })
}

pub(crate) fn request_manual(id: i32, source: &str) -> Result<String, Rejection> {
    if !available() {
        return Err(Rejection::Disabled);
    }
    if sodiumoxide::init().is_err() {
        return Err(Rejection::Invalid);
    }
    let mut nonce = [0; 32];
    sodiumoxide::randombytes::randombytes_into(&mut nonce);
    let result = POLICY
        .lock()
        .unwrap()
        .request_manual(id, nonce, source, Instant::now());
    let encoded: String = nonce.iter().map(|byte| format!("{byte:02x}")).collect();
    nonce.fill(0);
    result.map(|_| encoded)
}

pub(crate) fn decide_manual(id: i32, encoded: &str, accept: bool) -> Result<bool, Rejection> {
    if !available() {
        cancel(id);
        return Err(Rejection::Disabled);
    }
    if encoded.len() != 64 || !encoded.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err(Rejection::Invalid);
    }
    let mut nonce = [0; 32];
    for (index, value) in nonce.iter_mut().enumerate() {
        *value = u8::from_str_radix(&encoded[index * 2..index * 2 + 2], 16)
            .map_err(|_| Rejection::Invalid)?;
    }
    let result = POLICY
        .lock()
        .unwrap()
        .decide_manual(id, &nonce, accept, Instant::now());
    nonce.fill(0);
    result
}

pub(crate) fn manual_pending(id: i32) -> bool {
    available() && POLICY.lock().unwrap().manual_pending(id, Instant::now())
}
pub(crate) fn cancel(id: i32) {
    POLICY.lock().unwrap().cancel(id);
}
