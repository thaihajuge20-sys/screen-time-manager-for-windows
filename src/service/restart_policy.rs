use std::time::Duration;

const STABLE_RUNTIME: Duration = Duration::from_secs(30);
const FIRST_DELAY_SECONDS: u64 = 2;
const MAX_DELAY_SECONDS: u64 = 30;

pub struct RestartPolicy {
    quick_failure_count: u32,
}

impl RestartPolicy {
    pub fn new() -> Self {
        Self {
            quick_failure_count: 0,
        }
    }

    pub fn next_delay(&mut self, child_runtime: Duration, stopping: bool) -> Option<Duration> {
        if stopping {
            return None;
        }

        if child_runtime >= STABLE_RUNTIME {
            self.quick_failure_count = 0;
        }

        let shift = self.quick_failure_count.min(4);
        let seconds = (FIRST_DELAY_SECONDS << shift).min(MAX_DELAY_SECONDS);

        if child_runtime < STABLE_RUNTIME {
            self.quick_failure_count = self.quick_failure_count.saturating_add(1);
        }

        Some(Duration::from_secs(seconds))
    }
}

impl Default for RestartPolicy {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::RestartPolicy;
    use std::time::Duration;

    #[test]
    fn a_stable_child_restarts_after_the_short_delay() {
        let mut policy = RestartPolicy::new();

        assert_eq!(
            policy.next_delay(Duration::from_secs(60), false),
            Some(Duration::from_secs(2))
        );
    }

    #[test]
    fn repeated_quick_failures_back_off_to_the_maximum() {
        let mut policy = RestartPolicy::new();

        let delays: Vec<_> = (0..6)
            .map(|_| policy.next_delay(Duration::from_secs(1), false).unwrap())
            .collect();

        assert_eq!(
            delays,
            vec![
                Duration::from_secs(2),
                Duration::from_secs(4),
                Duration::from_secs(8),
                Duration::from_secs(16),
                Duration::from_secs(30),
                Duration::from_secs(30),
            ]
        );
    }

    #[test]
    fn an_explicit_service_stop_never_restarts_the_child() {
        let mut policy = RestartPolicy::new();

        assert_eq!(policy.next_delay(Duration::from_secs(1), true), None);
    }
}
