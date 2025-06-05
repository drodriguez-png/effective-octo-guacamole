set windows-shell := ["powershell.exe", "-NoProfile", "-Command"]

[private]
default:
    @just --list

demo target *args:
    python scripts/demo.py {{target}} {{args}}

[working-directory: 'heatswap']
heatswap:
    cargo build --release
    cp target/build/cleanup.exe \\hssieng\sndatadev\_simtrans
    cp target/build/cleanup.exe \\hssieng\sndataqas\_simtrans

gensql: clean
    python gen_proc.py

slab:
    uv run schema/gen_slab.py

convert *args: clean
    uv run convert_bom.py {{args}}

clean:
    rm dist/*_SapInter_*.sql
    rm conversion/output/*.ready
