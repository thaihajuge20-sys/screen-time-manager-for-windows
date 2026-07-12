use std::ffi::OsString;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RunMode {
    UserInterface,
    Service,
}

pub fn parse_run_mode<I>(args: I) -> RunMode
where
    I: IntoIterator<Item = OsString>,
{
    match args.into_iter().nth(1).as_deref() {
        Some(flag) if flag == "--service" => RunMode::Service,
        _ => RunMode::UserInterface,
    }
}

#[cfg(test)]
mod tests {
    use super::{parse_run_mode, RunMode};
    use std::ffi::OsString;

    #[test]
    fn no_flag_runs_the_user_interface() {
        let args = vec![OsString::from("screen-time-manager.exe")];

        assert_eq!(parse_run_mode(args), RunMode::UserInterface);
    }

    #[test]
    fn exact_service_flag_runs_the_service() {
        let args = vec![
            OsString::from("screen-time-manager.exe"),
            OsString::from("--service"),
        ];

        assert_eq!(parse_run_mode(args), RunMode::Service);
    }

    #[test]
    fn unknown_flags_do_not_enter_the_privileged_service_path() {
        let args = vec![
            OsString::from("screen-time-manager.exe"),
            OsString::from("--Service"),
        ];

        assert_eq!(parse_run_mode(args), RunMode::UserInterface);
    }
}
