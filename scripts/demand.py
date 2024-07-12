
import xlwings

import re

main = re.compile(r"\d{7}[A-Z]-[FTB]?G\d+[A-Z]-[A-Z]\d")

from os import getenv
from lib.db import SndbConnection

db_kwargs = dict(
    server="HIISQLSERV6",
    db="SNDBaseISap",
    user=getenv('SNDB_USER'),
    pwd=getenv('SNDB_PWD'),
)

data = []
wb = xlwings.books['export.xlsx']
for row in wb.sheets.active.range("A2:E5").expand('down').value:
    job = row[1].split('-')[0]
    shipment = int(row[4])
    data.append([
        row[0],  # event id
        "{}-{}-{}".format(job, shipment, 'main' if main.match(row[1]) else 'sec'),
        row[1].replace('-', '_', 1),  # part name
        int(row[2]),  # qty
        job,
        shipment
    ])


with SndbConnection(**db_kwargs) as db:
    db.executemany("""
        INSERT INTO TransAct (TransType, District, TransID, OrderNo, ItemName, Material, Qty, ItemData1, ItemData2)
        VALUES ('SN81B', 1, ?, ?, ?, 'MS', ?, ?, ?)
    """, data)
    db.commit()
