#!/usr/bin/env python3
"""
Reads the Ansible YAML inventory (inventory/hosts.yml) and rewrites the
auto-generated block inside the 'target' choice input of
.github/workflows/deploy.yml, so the dropdown always matches the inventory.

Run automatically by .github/workflows/sync-inventory-dropdown.yml whenever
inventory/hosts.yml changes on the main branch. You can also run it by hand:

    python scripts/generate_inventory_choices.py
"""
import sys
from pathlib import Path

import yaml

INVENTORY_PATH = Path("inventory/hosts.yml")
WORKFLOW_PATH = Path(".github/workflows/deploy.yml")
BEGIN_MARKER = "# BEGIN AUTO-GENERATED TARGETS"
END_MARKER = "# END AUTO-GENERATED TARGETS"


def collect_names(node, hosts, groups):
    """Walk an Ansible YAML inventory tree, collecting group and host names."""
    if not isinstance(node, dict):
        return
    for key, value in node.items():
        if key == "hosts" and isinstance(value, dict):
            hosts.update(value.keys())
        elif key == "children" and isinstance(value, dict):
            for group_name, group_body in value.items():
                groups.add(group_name)
                collect_names(group_body, hosts, groups)
        elif isinstance(value, dict):
            # covers wrapper keys like the top-level "all:"
            collect_names(value, hosts, groups)


def main():
    if not INVENTORY_PATH.exists():
        print(f"Inventory file not found at {INVENTORY_PATH}", file=sys.stderr)
        sys.exit(1)

    data = yaml.safe_load(INVENTORY_PATH.read_text()) or {}

    hosts, groups = set(), set()
    collect_names(data, hosts, groups)

    # "all" lets you target the whole inventory in one run.
    options = ["all"] + sorted(groups) + sorted(hosts)

    if not WORKFLOW_PATH.exists():
        print(f"Workflow file not found at {WORKFLOW_PATH}", file=sys.stderr)
        sys.exit(1)

    lines = WORKFLOW_PATH.read_text().splitlines(keepends=True)
    begin_idx = next((i for i, l in enumerate(lines) if BEGIN_MARKER in l), None)
    end_idx = next((i for i, l in enumerate(lines) if END_MARKER in l), None)

    if begin_idx is None or end_idx is None or end_idx < begin_idx:
        print(
            f"Could not find {BEGIN_MARKER} / {END_MARKER} markers in {WORKFLOW_PATH}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Re-use whatever indentation the BEGIN marker already has, so this
    # stays correct even if the workflow file is reformatted later.
    indent = lines[begin_idx][: len(lines[begin_idx]) - len(lines[begin_idx].lstrip())]

    new_block = (
        [f"{indent}{BEGIN_MARKER}\n"]
        + [f"{indent}- {name}\n" for name in options]
        + [f"{indent}{END_MARKER}\n"]
    )

    updated_lines = lines[:begin_idx] + new_block + lines[end_idx + 1 :]
    updated_text = "".join(updated_lines)
    original_text = "".join(lines)

    if updated_text != original_text:
        WORKFLOW_PATH.write_text(updated_text)
        print(f"Updated {WORKFLOW_PATH} with {len(options)} target option(s): {', '.join(options)}")
    else:
        print("Dropdown already up to date - no changes needed.")


if __name__ == "__main__":
    main()
