use crate::{
    client::Data,
    flutter::FlutterHandler,
    ui_session_interface::{LanSessionCredential, Session},
};
use hbb_common::{message_proto::PeerInfo, rendezvous_proto::ConnType, tokio::sync::mpsc};

fn pending() -> (Session<FlutterHandler>, mpsc::UnboundedReceiver<Data>) {
    let session = Session::<FlutterHandler>::default();
    session.lc.write().unwrap().conn_type = ConnType::FILE_TRANSFER;
    let (sender, receiver) = mpsc::unbounded_channel();
    *session.sender.write().unwrap() = Some(sender);
    (session, receiver)
}

#[test]
fn manual_retry_queues_only_request_and_removes_in_memory_credentials() {
    let (session, mut receiver) = pending();
    *session.lan_credential.lock().unwrap() = Some(LanSessionCredential {
        access_method: 0,
        temporary_code: String::new(),
        username: "old-user".into(),
        password: b"test-only-password".to_vec(),
        remember: true,
        identity_id: "old-profile".into(),
        bind_identity_on_success: true,
    });
    session
        .submit_optional_file_access(2, String::new())
        .unwrap();
    assert!(matches!(
        receiver.try_recv().unwrap(),
        Data::SubmitLanCredentials
    ));
    let credential = session.lan_credential().unwrap();
    assert_eq!(credential.access_method, hbb_common::lan::ACCESS_MANUAL);
    assert!(
        credential.temporary_code.is_empty()
            && credential.username.is_empty()
            && credential.password.is_empty()
    );
    assert!(
        !credential.remember
            && !credential.bind_identity_on_success
            && credential.identity_id.is_empty()
    );
    assert!(session.lan_identity_request.lock().unwrap().is_none());
}

#[test]
fn code_retry_keeps_leading_zero_and_no_saved_identity() {
    let (session, mut receiver) = pending();
    session
        .submit_optional_file_access(1, "012345".into())
        .unwrap();
    assert!(matches!(
        receiver.try_recv().unwrap(),
        Data::SubmitLanCredentials
    ));
    let credential = session.lan_credential().unwrap();
    assert_eq!(credential.access_method, hbb_common::lan::ACCESS_CODE);
    assert_eq!(credential.temporary_code, "012345");
    assert!(
        !credential.remember && credential.password.is_empty() && credential.username.is_empty()
    );
}

#[test]
fn bad_request_does_not_mutate_or_queue() {
    let (session, mut receiver) = pending();
    for (method, code) in [(0, ""), (1, "12345"), (2, "123456"), (3, "")] {
        assert!(session
            .submit_optional_file_access(method, code.into())
            .is_err());
        assert!(session.lan_credential().is_none());
        assert!(receiver.try_recv().is_err());
    }
}

#[test]
fn active_file_jobs_are_not_reauthenticated() {
    let (session, mut receiver) = pending();
    session.lc.write().unwrap().peer_info = Some(PeerInfo::new());
    assert!(session
        .submit_optional_file_access(2, String::new())
        .is_err());
    assert!(session.lan_credential().is_none() && receiver.try_recv().is_err());
}

#[test]
fn never_sends_optional_file_request_on_control_channel() {
    let (session, mut receiver) = pending();
    session.lc.write().unwrap().conn_type = ConnType::DEFAULT_CONN;
    assert!(session
        .submit_optional_file_access(2, String::new())
        .is_err());
    assert!(session.lan_credential().is_none() && receiver.try_recv().is_err());
}

#[test]
fn missing_sender_fails_before_mutation() {
    let (session, _) = pending();
    *session.sender.write().unwrap() = None;
    assert!(session
        .submit_optional_file_access(2, String::new())
        .is_err());
    assert!(session.lan_credential().is_none());
}

#[test]
fn closed_sender_clears_ephemeral_code_and_reports_failure() {
    let (session, receiver) = pending();
    drop(receiver);
    assert!(session
        .submit_optional_file_access(1, "123456".into())
        .is_err());
    assert!(session.lan_credential().is_none());
}
