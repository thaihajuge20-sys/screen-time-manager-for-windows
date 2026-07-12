pub mod restart_policy;

pub const SERVICE_NAME: &str = "ScreenTimeManagerService";
#[allow(dead_code)]
pub const SERVICE_DISPLAY_NAME: &str = "Screen Time Manager Service";

#[cfg(windows)]
mod windows_service;

#[cfg(windows)]
pub use windows_service::run;

#[cfg(test)]
mod tests {
    use super::{SERVICE_DISPLAY_NAME, SERVICE_NAME};

    #[test]
    fn service_identity_stays_stable_for_install_and_upgrade() {
        assert_eq!(SERVICE_NAME, "ScreenTimeManagerService");
        assert_eq!(SERVICE_DISPLAY_NAME, "Screen Time Manager Service");
    }
}
