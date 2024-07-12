
from os import getenv, path, mkdir
from lib.db import SndbConnection

from datetime import datetime
import json

st_tables = ["STPrgArc", "STPIPArc", "STPIPRejectedArchive", "STPrtArc", "STRemArc", "STShtArc", "STWOArc"]
other_tables = ["Program", "Stock", "Part", "Remnant"]

db_kwargs = dict(
    server="HIISQLSERV6",
    db="SNDBaseISap",
    user=getenv('SNDB_USER'),
    pwd=getenv('SNDB_PWD'),
)

tables = { key: [] for key in [*st_tables, *other_tables] }
with SndbConnection(**db_kwargs) as db:
    for table in tables:
        db.execute(f"select * from {table}")
        for row in db.cursor.fetchall():
            try:
                tables[table].append({ t[0]: row[i] for i, t in enumerate(row.cursor_description) })
            except UnboundLocalError:
                pass

snaps = path.join(path.dirname(path.realpath(__file__)), "snapshots")
if not path.exists(snaps):
    mkdir(snaps)
with open(path.join(snaps, datetime.now().strftime("%Y%m%d_%H%M%S.json")), 'w') as f:
    json.dump(tables, f, indent='  ', default=lambda x: str(x))
