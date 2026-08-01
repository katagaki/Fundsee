# Fundsee

A visual budget management app for iOS 26.0+. Users define budget templates for the kinds of days they have (working from office, working from home, not working), assign a template to each weekday, and record spending per category each day. Daily, weekly, monthly, and yearly views show budget health with charts instead of forms and tables.

## Things you cannot tell from the code

- The `.xcodeproj` was written by hand with synchronized folder groups. Adding a file to a target's folder adds it to that target; there are no per-file build entries to maintain.
- **BudgetKit/** is intentionally a shared source folder, not a framework. Its files compile into all three targets.
- **FundseeHarness** is developer-only tooling and must never ship. It exists because widget UIs cannot be verified headlessly here. Debug-only affordances go in the harness, never in the app.
- The models look over-constrained (every property defaulted, relationships optional, no unique attributes) because CloudKit requires it. Keep that shape.
- Carryover math is deliberately bounded: next-day carry resets at week boundaries, next-week carry reaches back exactly one week. These are product decisions, not bugs.
- Two past bugs to not reintroduce: `DateInterval.contains` includes its end instant, so day-in-week checks must be half-open; and two BarMarks at the same x silently stack in Swift Charts, which is why charts use `yStart`/`yEnd`.
- Notification report content is computed at schedule time and refreshed on foreground, so it is only as current as the last app launch. Accepted limitation to avoid an extension.
- There is no `AppIcon.appiconset`; the Icon Composer document `Fundsee/AppIcon.icon` is the only icon source.
- `DEVELOPMENT_TEAM` is intentionally empty. Simulator-only for now; devices and real CloudKit sync need a team plus the App Group and iCloud container registered.

## User preferences (established in review, keep them)

- No em-dashes in user-facing copy.
- No status pills; convey state with progress bars and color.
- Toolbar Cancel/Done are label-less `Button(role: .cancel)` / `Button(role: .confirm)`.
- Card/tile shadows appear in light mode only.

## Working on this machine

Simulator tap injection is broken (SimulatorKit is missing under the Xcode-beta path), so verify UI headlessly: `xcodebuild` to the simulator by device ID, `simctl install/launch`, `simctl io screenshot`, then read the screenshot. The app reads launch arguments to make this possible:

- `-hasCompletedOnboarding YES`, `-onboardingStep N`, `-initialTab today|week|month|year|more`
- `-seedSampleData YES` fills the past 4 months with plausible entries; it skips today and any day that already has data, so it is safe on real data.
