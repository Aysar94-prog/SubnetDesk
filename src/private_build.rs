//! This fork is manually maintained. Stored preferences or build features cannot enable updates.
pub const UPDATE_DISABLED_MESSAGE: &str = "Software updates are disabled in this private build";
pub const UPDATE_DISABLED_STATE: &str = r#"{"state":"disabled","auto_check":false,"auto_download":false,"message":"Software updates are disabled in this private build"}"#;
pub fn software_updates_enabled() -> bool { false }

#[cfg(test)]
mod tests {
    #[test]
    fn private_build_never_enables_software_updates() {
        assert!(!super::software_updates_enabled());
    }

    #[cfg(feature = "flutter")]
    #[test]
    fn native_update_api_is_disabled_even_when_preferences_are_enabled() {
        use crate::flutter_ffi::*;
        main_set_software_update_preferences(true, true);
        assert_eq!(main_get_software_update_state(), super::UPDATE_DISABLED_STATE);
        assert_eq!(main_check_software_update(), super::UPDATE_DISABLED_MESSAGE);
        assert_eq!(main_download_software_update(), super::UPDATE_DISABLED_MESSAGE);
        assert_eq!(main_install_software_update(), super::UPDATE_DISABLED_MESSAGE);
    }

    #[cfg(windows)]
    #[test]
    fn legacy_installers_are_blocked_before_examining_paths_or_launching_uac() {
        use crate::platform::windows::{update_me, update_me_msi, update_to};
        assert_eq!(update_me(false).unwrap_err().to_string(), super::UPDATE_DISABLED_MESSAGE);
        assert_eq!(update_me_msi("nonexistent.msi", false).unwrap_err().to_string(), super::UPDATE_DISABLED_MESSAGE);
        assert_eq!(update_to("nonexistent.exe").unwrap_err().to_string(), super::UPDATE_DISABLED_MESSAGE);
    }

    #[cfg(feature = "software-update")]
    #[test]
    fn compiled_scheduler_and_operations_cannot_override_private_policy() {
        use crate::software_update::*;
        start_scheduler();
        set_preferences(true, true);
        assert_eq!(state_json(), super::UPDATE_DISABLED_STATE);
        assert_eq!(check(true).unwrap_err().to_string(), super::UPDATE_DISABLED_MESSAGE);
        assert_eq!(download().unwrap_err().to_string(), super::UPDATE_DISABLED_MESSAGE);
        assert_eq!(install().unwrap_err().to_string(), super::UPDATE_DISABLED_MESSAGE);
    }
}
