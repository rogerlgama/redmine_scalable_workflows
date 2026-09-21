# Redmine Scalable Workflows

Redmine plugin that replaces the full workflow-transition matrix with a progressive, sparse editor designed for installations with many issue statuses.

Portuguese documentation: [README.pt-BR.md](README.pt-BR.md)

## Features

- Searchable, multi-select role and tracker controls.
- A searchable **All** option for roles and trackers.
- Automatic loading of existing transitions when editing one tracker and one or more roles.
- On-demand issue-status search instead of loading the full status list.
- A compact matrix containing only statuses selected by the administrator.
- Tri-state transition checkboxes, preserving Redmine's **No change** behavior during multi-scope editing.
- Bulk toggle by source row or destination column.
- Support for Redmine's standard, author-only, and assignee-only transition rules.
- Partial workflow updates without overwriting untouched transitions.
- Targeted database reads and writes for selected source/destination statuses.
- An optimized `WorkflowTransition.replace_transitions` path intended for forward compatibility with Redmine 7.
- No database migrations and no Redmine core-file changes.

Removing the plugin restores Redmine's native workflow editor without deleting saved transitions.

## Requirements

- Redmine 6.0 or newer
- Ruby and Rails versions supported by the installed Redmine version

The current release was structurally validated against the Redmine 6.0.6 source code.

## Installation

1. Copy the plugin to `REDMINE_ROOT/plugins/redmine_scalable_workflows`.
2. Restart Redmine.
3. Open **Administration → Workflow**.

No database migration is required.

## Usage

1. Select one or more roles.
2. Select a tracker.
3. Choose **Edit** to load existing transitions.
4. Search for and add only the statuses needed for the current change.
5. Edit transitions in the compact matrix and save.

The indeterminate checkbox state means that existing values differ across the selected scopes and will remain unchanged unless the administrator explicitly checks or clears the box.

## Performance model

The native workflow editor renders the complete status-to-status matrix. This plugin searches statuses on demand and builds only the selected subset. During updates, it sends and queries only the affected source and destination statuses, reducing browser rendering and server work in installations with large status catalogs.

## Upgrade

Replace the plugin files while keeping the directory name `redmine_scalable_workflows`, then restart Redmine. There are no migrations.

## Uninstall

Remove `plugins/redmine_scalable_workflows` and restart Redmine. The native editor returns and all previously stored workflow transitions remain available.

## Testing status

The package has been structurally validated against Redmine 6.0.6. Automated tests are not yet included; validate role/tracker selection, mixed transition states, save behavior, and rollback in a staging Redmine before production deployment.

## License

Copyright holders license this project under the GNU General Public License version 2 or, at your option, any later version (`GPL-2.0-or-later`). See [LICENSE](LICENSE).

## Author

Roger Gama
