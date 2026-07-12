#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ServiceEvent {
    Started,
    NoActiveSession,
    ChildLaunchFailed(i32),
    ChildExited,
    Stopped,
}

pub fn format_event(event: ServiceEvent) -> String {
    match event {
        ServiceEvent::Started => "Service started".to_string(),
        ServiceEvent::NoActiveSession => "No active user session; retrying".to_string(),
        ServiceEvent::ChildLaunchFailed(code) => {
            format!("User interface launch failed with Windows error {code}")
        }
        ServiceEvent::ChildExited => "User interface exited; restarting".to_string(),
        ServiceEvent::Stopped => "Service stopped".to_string(),
    }
}

#[cfg(windows)]
pub fn write_event(event: ServiceEvent) {
    use windows::{
        core::PCWSTR,
        Win32::System::EventLog::{
            DeregisterEventSource, RegisterEventSourceW, ReportEventW, EVENTLOG_INFORMATION_TYPE,
            EVENTLOG_WARNING_TYPE,
        },
    };

    let source: Vec<u16> = "ScreenTimeManagerService\0".encode_utf16().collect();
    let message: Vec<u16> = format_event(event)
        .encode_utf16()
        .chain(std::iter::once(0))
        .collect();
    let event_type = match event {
        ServiceEvent::NoActiveSession | ServiceEvent::ChildLaunchFailed(_) => EVENTLOG_WARNING_TYPE,
        _ => EVENTLOG_INFORMATION_TYPE,
    };

    unsafe {
        if let Ok(handle) = RegisterEventSourceW(PCWSTR::null(), PCWSTR(source.as_ptr())) {
            let strings = [PCWSTR(message.as_ptr())];
            let _ = ReportEventW(handle, event_type, 0, 1, None, 0, Some(&strings), None);
            let _ = DeregisterEventSource(handle);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{format_event, ServiceEvent};

    #[test]
    fn lifecycle_messages_are_short_and_do_not_include_configuration() {
        assert_eq!(format_event(ServiceEvent::Started), "Service started");
        assert_eq!(
            format_event(ServiceEvent::NoActiveSession),
            "No active user session; retrying"
        );
        assert_eq!(
            format_event(ServiceEvent::ChildLaunchFailed(5)),
            "User interface launch failed with Windows error 5"
        );
        assert_eq!(
            format_event(ServiceEvent::ChildExited),
            "User interface exited; restarting"
        );
        assert_eq!(format_event(ServiceEvent::Stopped), "Service stopped");
    }
}
