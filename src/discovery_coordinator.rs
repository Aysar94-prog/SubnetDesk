use hbb_common::tokio::{self, sync::broadcast};
use std::{future::Future, sync::Mutex};

struct SlotGuard<T: Clone + 'static> {
    slot: &'static Mutex<Option<broadcast::Sender<T>>>,
    armed: bool,
}
impl<T: Clone + 'static> Drop for SlotGuard<T> {
    fn drop(&mut self) {
        if self.armed { self.slot.lock().unwrap().take(); }
    }
}

/// The worker owns the slot, so cancelling any waiter cannot strand it.
pub async fn run<T, F, Fut>(slot: &'static Mutex<Option<broadcast::Sender<T>>>, worker: F) -> Option<T>
where T: Clone + Send + 'static, F: FnOnce() -> Fut + Send + 'static,
      Fut: Future<Output = T> + Send + 'static {
    let (mut receiver, start) = {
        let mut current = slot.lock().unwrap();
        match current.as_ref() {
            Some(sender) => (sender.subscribe(), false),
            None => {
                let (sender, receiver) = broadcast::channel(1);
                *current = Some(sender);
                (receiver, true)
            }
        }
    };
    if start {
        tokio::spawn(async move {
            let mut guard = SlotGuard { slot, armed: true };
            let result = worker().await;
            let sender = {
                let mut current = slot.lock().unwrap();
                guard.armed = false;
                current.take()
            };
            if let Some(sender) = sender { let _ = sender.send(result); }
        });
    }
    receiver.recv().await.ok()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;
    #[tokio::test]
    async fn cancelled_first_waiter_does_not_cancel_worker_or_block_next_scan() {
        let slot = Box::leak(Box::new(Mutex::new(None)));
        let slot: &'static Mutex<Option<broadcast::Sender<u8>>> = slot;
        let ready = Arc::new(tokio::sync::Notify::new());
        let release = Arc::new(tokio::sync::Notify::new());
        let (r, go) = (ready.clone(), release.clone());
        let first = tokio::spawn(run(slot, move || async move {
            r.notify_one(); go.notified().await; 7
        }));
        ready.notified().await;
        first.abort();
        let second = run(slot, || async { panic!("joined scan started another worker") });
        tokio::pin!(second);
        assert!(tokio::time::timeout(std::time::Duration::from_millis(20), &mut second).await.is_err());
        release.notify_one();
        assert_eq!(second.await, Some(7));
        assert!(slot.lock().unwrap().is_none());
        assert_eq!(run(slot, || async { 9 }).await, Some(9));
    }
}
