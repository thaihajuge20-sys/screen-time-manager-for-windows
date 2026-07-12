use super::{restart_policy::RestartPolicy, SERVICE_NAME};
use std::{
    ffi::{c_void, OsString},
    mem::{size_of, zeroed},
    os::windows::ffi::OsStrExt,
    sync::mpsc::{self, Receiver, RecvTimeoutError, TryRecvError},
    time::{Duration, Instant},
};
use windows::{
    core::{PCWSTR, PWSTR},
    Win32::{
        Foundation::{CloseHandle, HANDLE, WAIT_OBJECT_0, WAIT_TIMEOUT},
        Security::{DuplicateTokenEx, SecurityImpersonation, TokenPrimary, TOKEN_ALL_ACCESS},
        System::{
            Environment::{CreateEnvironmentBlock, DestroyEnvironmentBlock},
            RemoteDesktop::{WTSGetActiveConsoleSessionId, WTSQueryUserToken},
            Threading::{
                CreateProcessAsUserW, TerminateProcess, WaitForSingleObject,
                CREATE_UNICODE_ENVIRONMENT, PROCESS_INFORMATION, STARTUPINFOW,
            },
        },
    },
};
use windows_service::{
    define_windows_service,
    service::{
        ServiceControl, ServiceControlAccept, ServiceExitCode, ServiceState, ServiceStatus,
        ServiceType,
    },
    service_control_handler::{self, ServiceControlHandlerResult},
    service_dispatcher, Result,
};

const SERVICE_TYPE: ServiceType = ServiceType::OWN_PROCESS;
const NO_ACTIVE_SESSION: u32 = u32::MAX;
const CHILD_POLL_INTERVAL_MS: u32 = 500;

pub fn run() -> Result<()> {
    service_dispatcher::start(SERVICE_NAME, ffi_service_main)
}

define_windows_service!(ffi_service_main, service_main);

fn service_main(_arguments: Vec<OsString>) {
    let _ = run_service();
}

fn run_service() -> Result<()> {
    let (stop_tx, stop_rx) = mpsc::channel();
    let event_handler = move |control_event| -> ServiceControlHandlerResult {
        match control_event {
            ServiceControl::Interrogate => ServiceControlHandlerResult::NoError,
            ServiceControl::Stop | ServiceControl::Shutdown => {
                let _ = stop_tx.send(());
                ServiceControlHandlerResult::NoError
            }
            _ => ServiceControlHandlerResult::NotImplemented,
        }
    };

    let status_handle = service_control_handler::register(SERVICE_NAME, event_handler)?;
    status_handle.set_service_status(service_status(
        ServiceState::Running,
        ServiceControlAccept::STOP | ServiceControlAccept::SHUTDOWN,
    ))?;

    supervise_user_interface(&stop_rx);

    status_handle.set_service_status(service_status(
        ServiceState::Stopped,
        ServiceControlAccept::empty(),
    ))?;
    Ok(())
}

fn service_status(
    current_state: ServiceState,
    controls_accepted: ServiceControlAccept,
) -> ServiceStatus {
    ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state,
        controls_accepted,
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    }
}

fn supervise_user_interface(stop_rx: &Receiver<()>) {
    let mut restart_policy = RestartPolicy::new();

    loop {
        if stop_requested(stop_rx) {
            return;
        }

        let started_at = Instant::now();
        let child = match launch_user_interface() {
            Ok(child) => child,
            Err(_) => {
                if wait_or_stop(stop_rx, Duration::from_secs(2)) {
                    return;
                }
                continue;
            }
        };

        let stopping = wait_for_child_or_stop(&child, stop_rx);
        let runtime = started_at.elapsed();
        if let Some(delay) = restart_policy.next_delay(runtime, stopping) {
            if wait_or_stop(stop_rx, delay) {
                return;
            }
        } else {
            return;
        }
    }
}

fn stop_requested(stop_rx: &Receiver<()>) -> bool {
    matches!(stop_rx.try_recv(), Ok(()) | Err(TryRecvError::Disconnected))
}

fn wait_or_stop(stop_rx: &Receiver<()>, duration: Duration) -> bool {
    matches!(
        stop_rx.recv_timeout(duration),
        Ok(()) | Err(RecvTimeoutError::Disconnected)
    )
}

fn wait_for_child_or_stop(child: &OwnedHandle, stop_rx: &Receiver<()>) -> bool {
    loop {
        if stop_requested(stop_rx) {
            unsafe {
                let _ = TerminateProcess(child.raw(), 0);
                let _ = WaitForSingleObject(child.raw(), 5_000);
            }
            return true;
        }

        match unsafe { WaitForSingleObject(child.raw(), CHILD_POLL_INTERVAL_MS) } {
            WAIT_OBJECT_0 => return false,
            WAIT_TIMEOUT => continue,
            _ => return false,
        }
    }
}

fn launch_user_interface() -> windows::core::Result<OwnedHandle> {
    let session_id = unsafe { WTSGetActiveConsoleSessionId() };
    if session_id == NO_ACTIVE_SESSION {
        return Err(windows::core::Error::from_win32());
    }

    let mut session_token = HANDLE::default();
    unsafe { WTSQueryUserToken(session_id, &mut session_token)? };
    let session_token = OwnedHandle::new(session_token);

    let mut primary_token = HANDLE::default();
    unsafe {
        DuplicateTokenEx(
            session_token.raw(),
            TOKEN_ALL_ACCESS,
            None,
            SecurityImpersonation,
            TokenPrimary,
            &mut primary_token,
        )?;
    }
    let primary_token = OwnedHandle::new(primary_token);

    let mut environment: *mut c_void = std::ptr::null_mut();
    unsafe { CreateEnvironmentBlock(&mut environment, primary_token.raw(), false)? };
    let environment = EnvironmentBlock(environment);

    let executable = std::env::current_exe().map_err(windows::core::Error::from)?;
    let mut executable_wide: Vec<u16> = executable.as_os_str().encode_wide().collect();
    executable_wide.push(0);
    let mut command_line: Vec<u16> = format!("\"{}\"", executable.display())
        .encode_utf16()
        .chain(std::iter::once(0))
        .collect();
    let mut desktop: Vec<u16> = "winsta0\\default\0".encode_utf16().collect();

    let mut startup_info: STARTUPINFOW = unsafe { zeroed() };
    startup_info.cb = size_of::<STARTUPINFOW>() as u32;
    startup_info.lpDesktop = PWSTR(desktop.as_mut_ptr());
    let mut process_info: PROCESS_INFORMATION = unsafe { zeroed() };

    unsafe {
        CreateProcessAsUserW(
            primary_token.raw(),
            PCWSTR(executable_wide.as_ptr()),
            PWSTR(command_line.as_mut_ptr()),
            None,
            None,
            false,
            CREATE_UNICODE_ENVIRONMENT,
            Some(environment.0.cast_const()),
            PCWSTR::null(),
            &startup_info,
            &mut process_info,
        )?;
        CloseHandle(process_info.hThread)?;
    }

    Ok(OwnedHandle::new(process_info.hProcess))
}

struct OwnedHandle(HANDLE);

impl OwnedHandle {
    fn new(handle: HANDLE) -> Self {
        Self(handle)
    }

    fn raw(&self) -> HANDLE {
        self.0
    }
}

impl Drop for OwnedHandle {
    fn drop(&mut self) {
        if !self.0.is_invalid() {
            unsafe {
                let _ = CloseHandle(self.0);
            }
        }
    }
}

struct EnvironmentBlock(*mut c_void);

impl Drop for EnvironmentBlock {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe {
                let _ = DestroyEnvironmentBlock(self.0);
            }
        }
    }
}
