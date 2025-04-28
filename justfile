set windows-shell := ["powershell.exe", "-NoProfile", "-Command"]
demo := "scripts/demo"

[private]
default:
    @just --list

demo target *args:
    python scripts/demo.py {{target}} {{args}}

gensql: clean
    python gen_proc.py

slab:
    uv run schema/gen_slab.py

convert *args: clean
    uv run convert_bom.py {{args}}

clean:
    rm dist/*_SapInter_*.sql
    rm conversion/output/*.ready
