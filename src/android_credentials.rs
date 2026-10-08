//! Bounded credential payload for Android's Keystore-backed store.
//! No endpoint/IP lookup or plaintext config persistence.
use hbb_common::{anyhow::{anyhow, bail}, lan, ResultType};
use zeroize::Zeroizing;

fn fingerprint_key(value: &str) -> ResultType<String> {
    if value.len() != 64 || !value.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        bail!("Invalid LAN device fingerprint");
    }
    Ok(value.to_ascii_lowercase())
}

fn encode(username: &str, password: &[u8]) -> ResultType<Zeroizing<Vec<u8>>> {
    let username = lan::validate_username(username)?;
    lan::validate_password(password)?;
    let mut payload = Zeroizing::new(Vec::with_capacity(2 + username.len() + password.len()));
    payload.extend_from_slice(&(username.len() as u16).to_be_bytes());
    payload.extend_from_slice(username.as_bytes());
    payload.extend_from_slice(password);
    Ok(payload)
}

fn decode(payload: &[u8]) -> ResultType<(String, Vec<u8>)> {
    if payload.len() < 4 || payload.len() > 2 + lan::MAX_USERNAME_LEN + lan::MAX_PASSWORD_LEN {
        bail!("Invalid saved LAN credential");
    }
    let username_len = u16::from_be_bytes([payload[0], payload[1]]) as usize;
    if username_len == 0 || username_len > lan::MAX_USERNAME_LEN || 2 + username_len >= payload.len() {
        bail!("Invalid saved LAN credential");
    }
    let username = std::str::from_utf8(&payload[2..2 + username_len])
        .map_err(|_| anyhow!("Invalid saved LAN credential"))?;
    let username = lan::validate_username(username)?;
    let password = &payload[2 + username_len..];
    lan::validate_password(password)?;
    Ok((username, password.to_vec()))
}

#[cfg(target_os = "android")]
pub(crate) fn load(fingerprint: &str) -> ResultType<Option<(String, Vec<u8>)>> {
    let fingerprint = fingerprint_key(fingerprint)?;
    let payload = scrap::android::ffi::load_lan_credential(&fingerprint)
        .map_err(|_| anyhow!("Unable to read Android's encrypted credential store"))?;
    payload.map(|payload| decode(&Zeroizing::new(payload))).transpose()
}

#[cfg(target_os = "android")]
pub(crate) fn save(fingerprint: &str, username: &str, password: &[u8]) -> ResultType<()> {
    let fingerprint = fingerprint_key(fingerprint)?;
    let payload = encode(username, password)?;
    scrap::android::ffi::save_lan_credential(&fingerprint, &payload)
        .map_err(|_| anyhow!("Unable to save to Android's encrypted credential store"))
}

#[cfg(target_os = "android")]
pub(crate) fn forget(fingerprint: &str) -> ResultType<()> {
    let fingerprint = fingerprint_key(fingerprint)?;
    scrap::android::ffi::forget_lan_credential(&fingerprint)
        .map_err(|_| anyhow!("Unable to remove the saved Android credential"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_and_trim_username() {
        let payload = encode("  operator  ", b"test-only-password").unwrap();
        assert_eq!(decode(&payload).unwrap(), ("operator".to_owned(), b"test-only-password".to_vec()));
    }

    #[test]
    fn fingerprint_not_address_or_path() {
        for value in ["192.168.1.61", "../peer", "", &"g".repeat(64)] {
            assert!(fingerprint_key(value).is_err());
        }
        assert_eq!(fingerprint_key(&"AB".repeat(32)).unwrap(), "ab".repeat(32));
    }

    #[test]
    fn reject_invalid_fields_and_boundaries() {
        assert!(encode("", b"test").is_err());
        assert!(encode("user\nname", b"test").is_err());
        assert!(encode("user", b"").is_err());
        assert!(encode("user", b"bad\npassword").is_err());
        assert!(encode("user", &[255]).is_err());
        assert!(encode(&"x".repeat(lan::MAX_USERNAME_LEN + 1), b"test").is_err());
        assert!(encode("user", &vec![b'x'; lan::MAX_PASSWORD_LEN + 1]).is_err());
        let payload = encode(&"u".repeat(lan::MAX_USERNAME_LEN), &vec![b'p'; lan::MAX_PASSWORD_LEN]).unwrap();
        assert!(decode(&payload).is_ok());
    }

    #[test]
    fn reject_truncation_bad_length_and_invalid_text() {
        for payload in [&[][..], &[0, 0, 1, 2], &[0, 65, 1, 2], &[0, 1, 255, 1], &[0, 1, b'u', 255]] {
            assert!(decode(payload).is_err());
        }
        assert!(decode(&vec![0; 1024]).is_err());
        let payload = encode("user", b"test").unwrap();
        for length in 0..6 {
            assert!(decode(&payload[..length]).is_err());
        }
    }
}
