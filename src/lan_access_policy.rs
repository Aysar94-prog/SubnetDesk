//! In-memory lifetimes/limits for optional LAN access; no persistence or UI authority.
//! The backend must supply cryptographic randomness and constant-time verification.
use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

pub(crate) const CODE_TTL: Duration = Duration::from_secs(120);
pub(crate) const MANUAL_TTL: Duration = Duration::from_secs(60);
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
}

impl AccessPolicy {
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
        if !random_digits.iter().all(u8::is_ascii_digit) {
            return Err(Rejection::Invalid);
        }
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
        let code = self.code.as_mut().ok_or(Rejection::Missing)?;
        if now >= code.expires {
            self.code = None;
            return Err(Rejection::Expired);
        }
        if verify(&code.value) {
            self.code = None;
            return Ok(());
        }
        code.attempts -= 1;
        if code.attempts == 0 {
            self.code = None;
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
    fn code_is_single_use_and_regeneration_revokes_previous() {
        let mut policy = enabled();
        let now = Instant::now();
        policy.issue_code(*b"123456", now).unwrap();
        policy.issue_code(*b"654321", now).unwrap();
        assert_eq!(
            policy.consume_code(now, |code| code == b"123456"),
            Err(Rejection::Wrong)
        );
        assert_eq!(policy.consume_code(now, |code| code == b"654321"), Ok(()));
        assert_eq!(policy.consume_code(now, |_| true), Err(Rejection::Missing));
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
        assert_eq!(policy.consume_code(now, |_| true), Err(Rejection::Missing));
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
    fn mutex_serializes_code_consumption_under_concurrent_attempts() {
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
            1
        );
    }
}
