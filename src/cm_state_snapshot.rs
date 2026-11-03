#[derive(Default)]
pub struct StateSnapshot(Option<String>);
impl StateSnapshot {
    pub fn observe(&mut self, state: &str) { self.0 = Some(state.to_owned()); }
    pub fn changed(&mut self, state: &str) -> bool {
        if self.0.as_deref() == Some(state) { return false; }
        self.observe(state);
        true
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn missed_approval_update_recovers_even_with_same_client_count() {
        let mut snapshot = StateSnapshot::default();
        snapshot.observe(r#"[{"id":1,"authorized":false,"nonce":""}]"#);
        let pending = r#"[{"id":1,"authorized":false,"nonce":"request"}]"#;
        assert!(snapshot.changed(pending));
        assert!(!snapshot.changed(pending));
        assert!(snapshot.changed(r#"[{"id":1,"authorized":true,"nonce":""}]"#));
    }
}
