//! Private helper supports screen sharing and voice, never camera-view sessions.
pub const DISABLED_MESSAGE: &str = "Camera access is disabled in this private build";

pub fn allowed(camera_requested: bool) -> bool {
    !camera_requested
}

#[cfg(test)]
mod tests {
    #[test]
    fn camera_requests_are_always_rejected() {
        assert!(!super::allowed(true));
    }

    #[test]
    fn other_requests_are_unchanged() {
        assert!(super::allowed(false));
    }

    #[cfg(feature = "flutter")]
    #[test]
    fn camera_sessions_are_rejected_before_parsing_endpoint_or_registering_session() {
        let session_id = crate::flutter_ffi::SessionID::default();
        for file_transfer in [false, true] {
            let error = crate::flutter::session_add(
                &session_id, "", file_transfer, true, false, false, false, String::new()
            ).err().expect("camera session must not be created");
            assert_eq!(error.to_string(), super::DISABLED_MESSAGE);
        }
        assert_eq!(
            crate::flutter::session_add_existed(String::new(), session_id, vec![], true)
                .unwrap_err().to_string(),
            super::DISABLED_MESSAGE
        );
    }
}
