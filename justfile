set windows-shell := ["powershell.exe", "-NoProfile", "-Command"]
demo := "scripts/demo"

[private]
default:
    @just --list

frontend:
    cd client
    pnpm run dev

backend:
    cd server
    watchexec --watch --exts rs,toml --restart -- cargo run -q

demo target *args:
    python scripts/demo.py {{target}} {{args}}
