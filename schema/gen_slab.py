# /// script
# dependencies = [
#   "pyodbc",
#   "tabulate"
# ]
# ///

import json
import pyodbc
import re
from tabulate import tabulate

cs = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=HSSSNData;DATABASE=SNDBase91;UID=SNUser;PWD=BestNest1445"

q_prog = """
SELECT TOP 1
    ArchivePacketID,
    ProgramName,
    'Created' AS Status,
    MachineName,
    CuttingTime
FROM ProgArchive
WHERE ProgramName = ?
AND TransType = 'SN100'
ORDER BY ArchivePacketID DESC
"""
q_sheet = """
SELECT
    SheetName,
    PrimeCode AS MaterialMaster
FROM StockArchive
WHERE
    ArchivePacketID = ?
"""
q_parts = """
SELECT
    REPLACE(PartName, '_', '-') AS PartName,
    QtyProgram,
    Data1 AS Job,
    Data2 AS Shipment,
    TrueArea,
    NestedArea
FROM PartArchive
WHERE ArchivePacketID = ?
ORDER BY PartName;
"""
q_rem = """
SELECT
    RemnantName,
    Area,
    IIF(ABS(Area - Length * Width) > 1, 'N', 'Y') AS IsRectangular
FROM RemArchive
WHERE ArchivePacketID = ?
ORDER BY RemnantName;
"""


def query(db, sql, *args):
    cursor = db.cursor()
    cursor.execute(sql, *args)

    for row in cursor.fetchall():
        cols = [c[0] for c in row.cursor_description]
        yield zip(cols, row)


class Program(dict):
    def __init__(self, db, id):
        for col, val in next(query(db, q_prog, id)):
            self[col] = val


class Sheet(dict):
    def __init__(self, db, id, index):
        self["SheetIndex"] = index
        for col, val in next(query(db, q_sheet, id)):
            self[col] = val

        self.update(dict(Parts=[], Remnants=[]))
        for part in query(db, q_parts, id):
            self["Parts"].append(Part(**dict(part)))

        for rem in query(db, q_rem, id):
            self["Remnants"].append(Remnant(**dict(rem)))


class Part(dict):
    def __init__(self, **kwargs):
        self.update(kwargs)


class Remnant(dict):
    def __init__(self, **kwargs):
        self.update(kwargs)


class SlabCollection(dict):
    def __init__(self, *child_nests, parent=None):
        db = pyodbc.connect(cs)

        self.update(dict(Header=None, Sheets=[]))

        if child_nests:
            self.programs = []
            for i, prog in enumerate(child_nests, start=1):
                program = Program(db, str(prog))
                self.programs.append(program)

                sheet = Sheet(db, program["ArchivePacketID"], i)
                self["Sheets"].append(sheet)
        else:
            # TODO: get children from slab part names
            pass

        if parent:
            self["Header"] = Program(db, str(parent))
        else:
            self["Header"] = self.programs[0]
            self["Header"]["CuttingTime"] = sum(
                prog["CuttingTime"] for prog in self.programs
            )

    def json(self):
        return json.dumps(self, indent=4)

    def tables(self):
        id = self["Header"]["ArchivePacketID"]

        sheets, parts, rems = [], [], []
        for sheet in self["Sheets"]:
            s = dict(ArchivePacketID=id, **sheet)
            index = s["SheetIndex"]

            base = dict(ArchivePacketID=id, SheetIndex=index)
            for p in s.pop("Parts"):
                parts.append(dict(ArchivePacketID=id, SheetIndex=index, **p))
            for r in s.pop("Remnants"):
                rems.append(dict(ArchivePacketID=id, SheetIndex=index, **r))

            sheets.append(s)

        def print_table(data, title):
            table = tabulate(data, headers="keys", tablefmt="rounded_outline")

            if len(table) == 0:
                table = "{:^30}".format("< No data >")

            width = len(table.split("\n")[0])
            print("{:~^{width}}".format(f" {title} ", width=width))
            print(table, '\n')


        print_table([self["Header"]], "Header")
        print_table(sheets, "Sheets")
        print_table(parts, "Parts")
        print_table(rems, "Remnants")

def main():
    slab = SlabCollection(39213, 39212, parent=39220)

    # print(slab.json())
    with open(f"{slab["Header"]["ProgramName"]}.json", "w") as f:
        f.write(slab.json())

    slab.tables()


if __name__ == "__main__":
    main()
