# Changelog

All notable changes to this project are documented in this file.

## [0.5.0] - 2026-03-09

### Added
- `turbo_crud:install` generator to wire layout frames and CSS requires.
- `turbo_crud:doctor --fix` for automatic setup remediation.
- Optional `--stimulus` install path for TurboCrud behavior controller wiring.
- Rails 7.2 CI matrix coverage via `gemfiles/rails_7_2.gemfile`.
- Regression test for flash message transitions across create -> update.

### Changed
- Shared generator install logic via `InstallSupport`.
- Drawer edit links generated correctly for `--container=drawer`.
- Flash stream updates now preserve frame targetability across requests.
- README expanded with comparison table, compatibility notes, and setup guidance.

### Fixed
- Stale flash message persistence between requests when Turbo streams are used.
- `--full` scaffold now auto-wires install requirements for layout/CSS.

## [0.4.9] - 2026-03-09

### Added
- `turbo_crud:install` generator to wire layout frames and CSS requires.
- `turbo_crud:doctor --fix` for automatic setup remediation.
- Optional `--stimulus` install path for TurboCrud behavior controller wiring.
- Rails 7.2 CI matrix coverage via `gemfiles/rails_7_2.gemfile`.
- Regression test for flash message transitions across create -> update.

### Changed
- Shared generator install logic via `InstallSupport`.
- Drawer edit links generated correctly for `--container=drawer`.
- Flash stream updates now preserve frame targetability across requests.
- README expanded with comparison table, compatibility notes, and setup guidance.

### Fixed
- Stale flash message persistence between requests when Turbo streams are used.
- `--full` scaffold now auto-wires install requirements for layout/CSS.
