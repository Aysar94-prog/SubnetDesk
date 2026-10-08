//! Bounded attention notifications; no message content or persistent history.
use std::{collections::VecDeque, time::{Duration, Instant}};

pub const VERSION: u32 = 1;
pub const CAPABILITY: &str = "chat_attention_version";
const COOLDOWN: Duration = Duration::from_secs(5);
const WINDOW: Duration = Duration::from_secs(10);
const MAX_ALERTS: usize = 3;

#[derive(Default)]
pub struct Cooldown(Option<Instant>);

impl Cooldown {
    pub fn ready(&self, now: Instant) -> bool {
        self.0.map_or(true, |last| now.checked_duration_since(last)
            .is_some_and(|elapsed| elapsed >= COOLDOWN))
    }

    pub fn record(&mut self, now: Instant) { self.0 = Some(now); }
}

#[derive(Default)]
pub struct AlertWindow(VecDeque<Instant>);

impl AlertWindow {
    pub fn accept(&mut self, now: Instant) -> bool {
        while self.0.front().is_some_and(|first| now.checked_duration_since(*first)
            .is_some_and(|elapsed| elapsed >= WINDOW)) {
            self.0.pop_front();
        }
        if self.0.len() >= MAX_ALERTS { return false; }
        self.0.push_back(now);
        true
    }
}

pub fn valid_request(version: u32, encoded_size: u64) -> bool {
    // The canonical v1 event has exactly one uint32 field with value 1 (two bytes).
    version == VERSION && encoded_size == 2
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn exact_cooldown_boundary() {
        let now = Instant::now();
        let mut cooldown = Cooldown::default();
        assert!(cooldown.ready(now));
        cooldown.record(now);
        assert!(!cooldown.ready(now));
        assert!(!cooldown.ready(now + Duration::from_millis(4999)));
        assert!(cooldown.ready(now + COOLDOWN));
    }
    #[test]
    fn clock_regression_does_not_bypass_limit() {
        let now = Instant::now();
        let mut cooldown = Cooldown::default();
        cooldown.record(now + COOLDOWN);
        assert!(!cooldown.ready(now));
    }
    #[test]
    fn global_window_is_bounded_and_expires_at_boundary() {
        let now = Instant::now();
        let mut window = AlertWindow::default();
        for _ in 0..MAX_ALERTS { assert!(window.accept(now)); }
        for _ in 0..1000 { assert!(!window.accept(now)); }
        assert_eq!(window.0.len(), MAX_ALERTS);
        assert!(!window.accept(now + Duration::from_millis(9999)));
        assert!(window.accept(now + WINDOW));
        assert_eq!(window.0.len(), 1);
    }
    #[test]
    fn new_connection_has_no_previous_session_cooldown() {
        let now = Instant::now();
        let mut old = Cooldown::default();
        old.record(now);
        assert!(!old.ready(now));
        assert!(Cooldown::default().ready(now));
    }
    #[test]
    fn request_is_versioned_and_has_no_extra_payload() {
        assert!(valid_request(1, 2));
        assert!(!valid_request(0, 0));
        assert!(!valid_request(2, 2));
        assert!(!valid_request(1, 4));
        assert!(!valid_request(1, u64::MAX));
    }
}
