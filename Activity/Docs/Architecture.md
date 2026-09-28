## DashboardController

DashboardController coordinates the Today screen.

It imports HealthKit data through HealthKitService, loads local
records through ActivityRepository, and evaluates the result through
ActivityRules.

Changing the Today context reloads local summaries without performing
another HealthKit import.


## Trends

TrendsView reads rebuildable DailyActivityRecord values directly
through SwiftData.

Available periods are 7, 30, and 90 activity days. Trends include the
current partial activity day. Personal baseline comparisons continue
to exclude the current day.

Aerobic charts use reconciled moderate-equivalent minutes. Energy and
distance remain informational and do not affect Activity Health.
