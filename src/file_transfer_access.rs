//! Pre-authentication file-channel retries only; never promotes a control grant.
pub fn validate_optional_retry(
    file_channel: bool,
    authenticated: bool,
    method: u32,
    code: &str,
) -> Result<(), &'static str> {
    if !file_channel {
        return Err("This login method is only available for file transfer");
    }
    if authenticated {
        return Err("File transfer is already authenticated");
    }
    hbb_common::lan::validate_optional_access(method, code)
        .map_err(|_| "Invalid file transfer access method or temporary code")
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn valid_code() {
        assert!(validate_optional_retry(true, false, 1, "012345").is_ok());
    }
    #[test]
    fn valid_manual_request_without_code() {
        assert!(validate_optional_retry(true, false, 2, "").is_ok());
    }
    #[test]
    fn auto_file_retry_accepts_password_code_and_manual() {
        for input in ["abc", "long-password-!42", " كلمة سر ", "012345", ""] {
            assert!(validate_optional_retry(true, false, 4, input).is_ok());
            assert!(validate_optional_retry(false, false, 4, input).is_err());
            assert!(validate_optional_retry(true, true, 4, input).is_err());
        }
        assert!(validate_optional_retry(true, false, 4, "bad\npassword").is_err());
    }
    #[test]
    fn reject_bad_codes() {
        for code in [
            "",
            "12345",
            "1234567",
            "abcdef",
            "\u{0661}\u{0662}\u{0663}\u{0664}\u{0665}\u{0666}",
            "12345\n",
        ] {
            assert!(validate_optional_retry(true, false, 1, code).is_err());
        }
    }
    #[test]
    fn reject_manual_code_and_unknown_methods() {
        assert!(validate_optional_retry(true, false, 2, "123456").is_err());
        for method in [0, 3, u32::MAX] {
            assert!(validate_optional_retry(true, false, method, "").is_err());
        }
    }
    #[test]
    fn never_promote_control_or_other_channels() {
        assert!(validate_optional_retry(false, false, 1, "123456").is_err());
        assert!(validate_optional_retry(false, false, 2, "").is_err());
    }
    #[test]
    fn do_not_reauthenticate_active_file_channels() {
        assert!(validate_optional_retry(true, true, 1, "123456").is_err());
        assert!(validate_optional_retry(true, true, 2, "").is_err());
    }
}
