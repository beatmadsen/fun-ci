use fun_ci_renderer::supports;

#[test]
fn speaks_protocol_version_one() {
    assert!(supports(1));
}

#[test]
fn refuses_any_other_protocol_version() {
    assert!(!supports(2));
}
