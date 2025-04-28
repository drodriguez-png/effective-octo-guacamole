# Main page
- Work order
  - drop down with search
  - option to run what is in workspace
  - option to filter out parts(by type, etc.)
- Machine
  - black list machines (in config)
  - option to select machine by part's machine
- remove AutoNC button

# Operation
- Works with multi-sheet
- Works with multiple parts per layout
- Task name is Material Master (as is today)
- Creates tasks even if no sheets exist
- Task machine as mentioned in [Main page](#main-page)
- *Part placement*
  - not in center; use machine settings (Machine Reference)
- Priority nesting (task default)
- Minimum rectangle rotate parts (no rotation > 10degrees || flip around if part rotated 180)
- AutoNC(optional, depending on level of work)
  - do not AutoNC if layout has NC
  - resume (i.e. WO Load & Processed, but web automation closed)
  - Webs: AutoNC default
  - Flanges: Bottom burn line (MG)
  - Flanges: Bottom burn line + layout (Farley)
  - Flanges: Bottom burn line + layout (Kinetic)

# fixes
- fix save to location
  - in Qas: `WS saved to: \\hssieng\SNDataQas\WS\WebAutomation_Plugin\20-1\D-123716\FAB\WS\D-1237169-01_2025-04-17_11-35-10.ws`
