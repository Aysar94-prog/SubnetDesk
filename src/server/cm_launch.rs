/// start_ipc waits for the logged-in desktop and launches CM as that user.
/// Windows Flutter sessions expose their Chat/Voice/Disconnect dock.
pub(crate) fn connection_manager_launch_args() -> Vec<&'static str> {
    #[cfg(all(target_os = "windows", feature = "flutter"))]
    return vec!["--cm"];
    #[cfg(not(all(target_os = "windows", feature = "flutter")))]
    vec!["--cm-no-ui"]
}

#[cfg(test)]
mod tests {
    use super::connection_manager_launch_args;

    #[cfg(all(target_os = "windows", feature = "flutter"))]
    #[test]
    fn windows_flutter_sessions_launch_a_visible_manager() {
        assert_eq!(connection_manager_launch_args(), vec!["--cm"]);
    }

    #[cfg(not(all(target_os = "windows", feature = "flutter")))]
    #[test]
    fn other_launch_modes_remain_headless() {
        assert_eq!(connection_manager_launch_args(), vec!["--cm-no-ui"]);
    }
}
