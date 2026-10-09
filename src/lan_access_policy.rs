//! In-memory lifetimes/limits for optional LAN access; no persistence or UI authority.
//! The backend must supply cryptographic randomness and constant-time verification.
use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

pub(crate) const CODE_TTL: Duration = Duration::from_secs(2 * 60 * 60);
pub(crate) const MANUAL_TTL: Duration = Duration::from_secs(60);
const FAILURE_WINDOW: Duration = Duration::from_secs(120);
const CODE_COOLDOWN: Duration = Duration::from_secs(120);
const CODE_ATTEMPTS: u8 = 5;
const MAX_PENDING: usize = 8;
const MAX_PENDING_PER_SOURCE: usize = 2;

#[derive(Debug, PartialEq, Eq)]
pub(crate) enum Rejection {
    Disabled,
    Missing,
    Expired,
    Wrong,
    Duplicate,
    QueueFull,
    Invalid,
    Throttled,
}

struct Code {
    value: [u8; 6],
    expires: Instant,
    attempts: u8,
}
impl Drop for Code {
    fn drop(&mut self) {
        self.value.fill(0);
    }
}
struct Pending {
    nonce: [u8; 32],
    source: String,
    expires: Instant,
}
impl Drop for Pending {
    fn drop(&mut self) {
        self.nonce.fill(0);
    }
}

#[derive(Default)]
pub(crate) struct AccessPolicy {
    code_enabled: bool,
    manual_enabled: bool,
    code: Option<Code>,
    pending: HashMap<i32, Pending>,
    last_code: Option<[u8; 6]>,
    failed_codes: u8,
    failure_window: Option<Instant>,
    blocked_until: Option<Instant>,
}

impl Drop for AccessPolicy {
    fn drop(&mut self) {
        if let Some(code) = self.last_code.as_mut() { code.fill(0); }
    }
}

impl AccessPolicy {
    pub(crate) fn automatic_codes() -> Self {
        let mut policy = Self::default();
        policy.code_enabled = true;
        policy
    }
    pub(crate) fn receiver_defaults(manual: bool) -> Self {
        let mut policy = Self::automatic_codes();
        policy.manual_enabled = manual;
        policy
    }

    /// Serialize saving and policy changes under the receiver mutex. Saving OFF
    /// failures still cancel pending grants, but must report that OFF is unsaved.
    pub(crate) fn configure_saved(
        &mut self,
        code: bool,
        manual: bool,
        available: bool,
        persist: impl FnOnce(bool) -> Result<(), &'static str>,
    ) -> Result<(), &'static str> {
        if !available && ((code && !self.code_enabled) || (manual && !self.manual_enabled)) {
            return Err("Optional access requires this unlocked Windows app to own the LAN listener");
        }
        if let Err(error) = persist(manual) {
            if !manual { self.configure(self.code_enabled, false); }
            return Err(error);
        }
        self.configure(code, manual);
        Ok(())
    }
    pub(crate) fn suspend(&mut self) {
        // Availability gates hide/deny access, but do not rotate an unexpired code.
        self.pending.clear();
    }
    pub(crate) fn retry_seconds(&self, now: Instant) -> u64 {
        self.blocked_until.filter(|until| now < *until)
            .map(|until| until.saturating_duration_since(now).as_secs().saturating_add(1)).unwrap_or(0)
    }
    pub(crate) fn needs_code(&self, now: Instant) -> bool {
        self.code_enabled && self.retry_seconds(now) == 0 && self.visible_code(now).is_none()
    }
    pub(crate) fn is_previous_code(&self, digits: &[u8; 6]) -> bool {
        self.last_code.as_ref() == Some(digits)
    }
    pub(crate) fn capabilities(&self) -> (bool, bool) {
        (self.code_enabled, self.manual_enabled)
    }
    pub(crate) fn visible_code(&self, now: Instant) -> Option<(&[u8; 6], u64)> {
        self.code
            .as_ref()
            .filter(|code| now < code.expires)
            .map(|code| {
                (
                    &code.value,
                    code.expires.saturating_duration_since(now).as_secs(),
                )
            })
    }
    pub(crate) fn manual_pending(&self, id: i32, now: Instant) -> bool {
        self.manual_enabled
            && self
                .pending
                .get(&id)
                .map(|p| now < p.expires)
                .unwrap_or(false)
    }
    pub(crate) fn configure(&mut self, code: bool, manual: bool) -> Vec<i32> {
        self.code_enabled = code;
        self.manual_enabled = manual;
        if !code {
            self.code = None;
        }
        if manual {
            return vec![];
        }
        let cancelled = self.pending.keys().copied().collect();
        self.pending.clear();
        cancelled
    }

    pub(crate) fn issue_code(
        &mut self,
        random_digits: [u8; 6],
        now: Instant,
    ) -> Result<(), Rejection> {
        if !self.code_enabled {
            return Err(Rejection::Disabled);
        }
        if self.retry_seconds(now) > 0 { return Err(Rejection::Throttled); }
        if !random_digits.iter().all(u8::is_ascii_digit) {
            return Err(Rejection::Invalid);
        }
        self.last_code = Some(random_digits);
        self.code = Some(Code {
            value: random_digits,
            expires: now + CODE_TTL,
            attempts: CODE_ATTEMPTS,
        });
        Ok(())
    }

    /// The caller holds the backend mutex for this whole operation. No async/await.
    /// `verify` must use a vetted constant-time primitive, e.g. sodiumoxide::utils::memcmp.
    pub(crate) fn consume_code(
        &mut self,
        now: Instant,
        verify: impl FnOnce(&[u8; 6]) -> bool,
    ) -> Result<(), Rejection> {
        if !self.code_enabled {
            return Err(Rejection::Disabled);
        }
        if self.retry_seconds(now) > 0 { return Err(Rejection::Throttled); }
        let code = self.code.as_mut().ok_or(Rejection::Missing)?;
        if now >= code.expires {
            self.code = None;
            return Err(Rejection::Expired);
        }
        if verify(&code.value) {
            // Reusable until the original deadline; success never resets attempts.
            return Ok(());
        }
        code.attempts -= 1;
        if self.failure_window.map(|until| now >= until).unwrap_or(true) {
            self.failed_codes = 0;
            self.failure_window = Some(now + FAILURE_WINDOW);
        }
        self.failed_codes = self.failed_codes.saturating_add(1);
        if self.failed_codes >= CODE_ATTEMPTS || code.attempts == 0 {
            self.blocked_until = Some(now + CODE_COOLDOWN);
            self.failed_codes = 0;
            self.failure_window = Some(now + FAILURE_WINDOW);
            self.code = None;
            return Err(Rejection::Wrong);
        }
        Err(Rejection::Wrong)
    }

    pub(crate) fn request_manual(
        &mut self,
        id: i32,
        nonce: [u8; 32],
        source: &str,
        now: Instant,
    ) -> Result<(), Rejection> {
        if !self.manual_enabled {
            return Err(Rejection::Disabled);
        }
        if id <= 0 || nonce == [0; 32] || source.is_empty() || source.len() > 128 {
            return Err(Rejection::Invalid);
        }
        self.expire(now);
        if self.pending.contains_key(&id) {
            return Err(Rejection::Duplicate);
        }
        if self.pending.len() >= MAX_PENDING
            || self
                .pending
                .values()
                .filter(|item| item.source == source)
                .count()
                >= MAX_PENDING_PER_SOURCE
        {
            return Err(Rejection::QueueFull);
        }
        self.pending.insert(
            id,
            Pending {
                nonce,
                source: source.to_owned(),
                expires: now + MANUAL_TTL,
            },
        );
        Ok(())
    }

    pub(crate) fn decide_manual(
        &mut self,
        id: i32,
        nonce: &[u8; 32],
        accept: bool,
        now: Instant,
    ) -> Result<bool, Rejection> {
        if !self.manual_enabled {
            return Err(Rejection::Disabled);
        }
        let request = self.pending.get(&id).ok_or(Rejection::Missing)?;
        if now >= request.expires {
            self.pending.remove(&id);
            return Err(Rejection::Expired);
        }
        if &request.nonce != nonce {
            return Err(Rejection::Wrong);
        }
        self.pending.remove(&id);
        Ok(accept)
    }

    pub(crate) fn cancel(&mut self, id: i32) {
        self.pending.remove(&id);
    }
    pub(crate) fn expire(&mut self, now: Instant) -> Vec<i32> {
        let ids: Vec<_> = self
            .pending
            .iter()
            .filter(|(_, request)| now >= request.expires)
            .map(|(id, _)| *id)
            .collect();
        for id in &ids {
            self.pending.remove(id);
        }
        ids
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn enabled() -> AccessPolicy {
        let mut policy = AccessPolicy::default();
        policy.configure(true, true);
        policy
    }
    #[test]
    fn receiver_saved_defaults_allow_requests_but_never_replay_acceptance() {
        let now = Instant::now();
        let mut policy = AccessPolicy::receiver_defaults(true);
        assert_eq!(policy.capabilities(), (true, true));
        policy.request_manual(1, [1; 32], "ip", now).unwrap();
        assert!(policy.manual_pending(1, now));
        let mut restarted = AccessPolicy::receiver_defaults(true);
        assert_eq!(restarted.decide_manual(1, &[1; 32], true, now), Err(Rejection::Missing));
        assert!(restarted.visible_code(now).is_none());
        let mut disabled = AccessPolicy::receiver_defaults(false);
        assert_eq!(disabled.request_manual(1, [1; 32], "ip", now), Err(Rejection::Disabled));
    }
    #[test]
    fn saved_toggle_cancels_pending_without_rotating_code_or_resetting_guesses() {
        let now = Instant::now();
        let mut policy = AccessPolicy::receiver_defaults(true);
        policy.issue_code(*b"123456", now).unwrap();
        assert_eq!(policy.consume_code(now, |_| false), Err(Rejection::Wrong));
        policy.request_manual(1, [1; 32], "ip", now).unwrap();
        let mut saved = true;
        policy.configure_saved(true, false, true, |value| { saved = value; Ok(()) }).unwrap();
        assert!(!saved);
        assert!(!policy.manual_pending(1, now));
        assert_eq!(policy.decide_manual(1, &[1; 32], true, now), Err(Rejection::Disabled));
        assert_eq!(policy.visible_code(now).unwrap().1, 7200);
        assert_eq!(policy.code.as_ref().unwrap().attempts, 4);
        assert_eq!(AccessPolicy::receiver_defaults(saved).capabilities(), (true, false));
    }
    #[test]
    fn unavailable_receiver_can_disable_but_not_enable_methods() {
        let mut policy = AccessPolicy::receiver_defaults(true);
        policy.configure_saved(true, false, false, |_| Ok(())).unwrap();
        let mut writes = 0;
        assert!(policy.configure_saved(true, true, false, |_| { writes += 1; Ok(()) }).is_err());
        assert_eq!(writes, 0);
        assert_eq!(policy.capabilities(), (true, false));
        policy.configure_saved(false, false, false, |_| Ok(())).unwrap();
        assert!(policy.configure_saved(true, false, false, |_| Ok(())).is_err());
    }
    #[test]
    fn save_failure_never_enables_and_failed_disable_is_fail_closed_for_this_run() {
        let now = Instant::now();
        let mut policy = AccessPolicy::receiver_defaults(false);
        assert!(policy.configure_saved(true, true, true, |_| Err("Unsaved")).is_err());
        assert_eq!(policy.capabilities(), (true, false));
        policy.configure_saved(true, true, true, |_| Ok(())).unwrap();
        policy.request_manual(1, [1; 32], "ip", now).unwrap();
        assert!(policy.configure_saved(true, false, true, |_| Err("Unsaved OFF")).is_err());
        assert_eq!(policy.capabilities(), (true, false));
        assert!(!policy.manual_pending(1, now));
    }
    #[test]
    fn automatic_rotation_never_resets_guess_budget() {
        let mut policy = AccessPolicy::automatic_codes();
        let now = Instant::now();
        assert!(policy.needs_code(now));
        for attempt in 0..5 {
            policy.issue_code(*b"123456", now).unwrap();
            assert_eq!(policy.consume_code(now, |_| false), Err(Rejection::Wrong));
            if attempt < 4 { assert_eq!(policy.retry_seconds(now), 0); }
        }
        assert!(!policy.needs_code(now));
        assert_eq!(policy.issue_code(*b"654321", now), Err(Rejection::Throttled));
        policy.suspend();
        policy.configure(false, false);
        policy.configure(true, false);
        assert_eq!(policy.consume_code(now, |_| true), Err(Rejection::Throttled));
        assert!(policy.needs_code(now + CODE_COOLDOWN));
        policy.issue_code(*b"654321", now + CODE_COOLDOWN).unwrap();
        assert_eq!(policy.consume_code(now + CODE_COOLDOWN, |_| true), Ok(()));
        assert!(!policy.needs_code(now + CODE_COOLDOWN));
        assert!(policy.is_previous_code(b"654321"));
    }
    #[test]
    fn suspend_preserves_code_deadline_but_cancels_pending_manual_requests() {
        let mut policy = enabled();
        let now = Instant::now();
        policy.issue_code(*b"123456", now).unwrap();
        policy.request_manual(1, [1; 32], "ip", now).unwrap();
        policy.suspend();
        assert_eq!(policy.capabilities(), (true, true));
        assert_eq!(policy.visible_code(now).unwrap().0, b"123456");
        assert_eq!(policy.visible_code(now).unwrap().1, 7200);
        assert!(policy.visible_code(now + CODE_TTL).is_none());
        assert!(!policy.manual_pending(1, now));
    }
    #[test]
    fn optional_methods_are_off_by_default() {
        let mut policy = AccessPolicy::default();
        let now = Instant::now();
        assert_eq!(policy.issue_code(*b"123456", now), Err(Rejection::Disabled));
        assert_eq!(policy.consume_code(now, |_| true), Err(Rejection::Disabled));
        assert_eq!(
            policy.request_manual(1, [1; 32], "ip", now),
            Err(Rejection::Disabled)
        );
    }
    #[test]
    fn code_is_reusable_and_manual_regeneration_revokes_previous() {
        let mut policy = enabled();
        let now = Instant::now();
        policy.issue_code(*b"123456", now).unwrap();
        policy.issue_code(*b"654321", now).unwrap();
        assert_eq!(
            policy.consume_code(now, |code| code == b"123456"),
            Err(Rejection::Wrong)
        );
        assert_eq!(policy.consume_code(now, |code| code == b"654321"), Ok(()));
        assert_eq!(policy.consume_code(now, |code| code == b"654321"), Ok(()));
    }
    #[test]
    fn exact_expiry_and_five_failed_attempts_invalidate_code() {
        let mut policy = enabled();
        let now = Instant::now();
        policy.issue_code(*b"123456", now).unwrap();
        assert_eq!(
            policy.consume_code(now + CODE_TTL, |_| true),
            Err(Rejection::Expired)
        );
        policy.issue_code(*b"123456", now).unwrap();
        for _ in 0..5 {
            assert_eq!(policy.consume_code(now, |_| false), Err(Rejection::Wrong));
        }
        assert_eq!(policy.consume_code(now, |_| true), Err(Rejection::Throttled));
    }
    #[test]
    fn manual_decision_binds_connection_nonce_and_is_not_replayed() {
        let mut policy = enabled();
        let now = Instant::now();
        policy.request_manual(1, [1; 32], "ip", now).unwrap();
        assert_eq!(
            policy.decide_manual(2, &[1; 32], true, now),
            Err(Rejection::Missing)
        );
        assert_eq!(
            policy.decide_manual(1, &[2; 32], true, now),
            Err(Rejection::Wrong)
        );
        assert_eq!(policy.decide_manual(1, &[1; 32], true, now), Ok(true));
        assert_eq!(
            policy.decide_manual(1, &[1; 32], true, now),
            Err(Rejection::Missing)
        );
    }
    #[test]
    fn denied_cancelled_expired_and_disabled_requests_never_grant() {
        let mut policy = enabled();
        let now = Instant::now();
        policy.request_manual(1, [1; 32], "ip", now).unwrap();
        assert_eq!(policy.decide_manual(1, &[1; 32], false, now), Ok(false));
        policy.request_manual(1, [2; 32], "ip", now).unwrap();
        policy.cancel(1);
        assert_eq!(
            policy.decide_manual(1, &[2; 32], true, now),
            Err(Rejection::Missing)
        );
        policy.request_manual(1, [3; 32], "ip", now).unwrap();
        assert_eq!(
            policy.decide_manual(1, &[3; 32], true, now + MANUAL_TTL),
            Err(Rejection::Expired)
        );
        policy.request_manual(1, [4; 32], "ip", now).unwrap();
        assert_eq!(policy.configure(false, false), vec![1]);
        assert_eq!(
            policy.decide_manual(1, &[4; 32], true, now),
            Err(Rejection::Disabled)
        );
        policy.configure(true, true);
        assert_eq!(
            policy.decide_manual(1, &[4; 32], true, now),
            Err(Rejection::Missing)
        );
    }
    #[test]
    fn pending_queue_per_source_bound_duplicate_and_expiry() {
        let mut policy = enabled();
        let now = Instant::now();
        policy.request_manual(1, [1; 32], "ip", now).unwrap();
        policy.request_manual(2, [2; 32], "ip", now).unwrap();
        assert_eq!(
            policy.request_manual(1, [3; 32], "ip", now),
            Err(Rejection::Duplicate)
        );
        assert_eq!(
            policy.request_manual(3, [3; 32], "ip", now),
            Err(Rejection::QueueFull)
        );
        for id in 3..=8 {
            policy
                .request_manual(id, [id as u8; 32], &id.to_string(), now)
                .unwrap();
        }
        assert_eq!(
            policy.request_manual(9, [9; 32], "other", now),
            Err(Rejection::QueueFull)
        );
        assert_eq!(policy.expire(now + MANUAL_TTL).len(), 8);
        assert!(policy
            .request_manual(9, [9; 32], "other", now + MANUAL_TTL)
            .is_ok());
    }
    #[test]
    fn concurrent_valid_connections_reuse_code_without_extending_deadline() {
        let now = Instant::now();
        let mut policy = enabled();
        policy.issue_code(*b"123456", now).unwrap();
        let policy = std::sync::Arc::new(std::sync::Mutex::new(policy));
        let jobs: Vec<_> = (0..8)
            .map(|_| {
                let policy = policy.clone();
                std::thread::spawn(move || {
                    policy
                        .lock()
                        .unwrap()
                        .consume_code(now, |code| code == b"123456")
                        .is_ok()
                })
            })
            .collect();
        assert_eq!(
            jobs.into_iter()
                .map(|job| job.join().unwrap() as usize)
                .sum::<usize>(),
            8
        );
        assert_eq!(policy.lock().unwrap().visible_code(now).unwrap().1, 7200);
    }

    #[test]
    fn successful_reuse_keeps_two_hour_deadline_and_remaining_attempts() {
        let now = Instant::now();
        let mut policy = enabled();
        policy.issue_code(*b"123456", now).unwrap();
        assert_eq!(policy.consume_code(now, |_| false), Err(Rejection::Wrong));
        assert_eq!(policy.consume_code(now + Duration::from_secs(300), |_| true), Ok(()));
        assert_eq!(policy.visible_code(now + Duration::from_secs(300)).unwrap().1, 6900);
        assert_eq!(policy.code.as_ref().unwrap().attempts, 4);
        for _ in 0..4 {
            assert_eq!(policy.consume_code(now + Duration::from_secs(301), |_| false), Err(Rejection::Wrong));
        }
        assert!(policy.visible_code(now).is_none());
        assert!(!policy.needs_code(now + Duration::from_secs(301)));
        assert!(policy.needs_code(now + Duration::from_secs(301) + CODE_COOLDOWN));
        // Five per-code guesses also impose the short cooldown across windows.
    }

    #[test]
    fn restart_has_no_old_code_and_manual_timeout_stays_one_minute() {
        assert_eq!(CODE_TTL.as_secs(), 7200);
        assert_eq!(MANUAL_TTL.as_secs(), 60);
        assert_eq!(CODE_COOLDOWN.as_secs(), 120);
        let now = Instant::now();
        let mut restarted = AccessPolicy::automatic_codes();
        assert!(restarted.visible_code(now).is_none());
        assert_eq!(restarted.consume_code(now, |_| true), Err(Rejection::Missing));
        assert!(restarted.needs_code(now));
    }
}
