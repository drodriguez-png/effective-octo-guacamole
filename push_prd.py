
from fractions import Fraction
import re
import xlwings
import pyodbc

# `PL {thk} x {width} x {length} x {grade}`
DESC_PATTERN = re.compile(r"PL ([\d/\s]+) x (\d+) x (\d+) ((?:A709|M270)-)?(50W?(?:[TF][123])?)")
THK_PATTERN = re.compile(r"(\d*) ?(\d+)/()")
PROJ_MM = re.compile(r"(\d{7}[A-Z]\d{2})-0(\d{4})(\w*)")

def parse_desc(desc):
    match = DESC_PATTERN.match(desc)
    if match:
        thk, width, length, spec, grade =  match.groups()

        inches = 0
        if ' ' in thk:
            a,b = thk.split(' ', 1)
            inches, thk = float(a), b

        return {
            'Thickness': float(inches + Fraction(thk)),
            'Width': float(width),
            'Length': float(length),
            'Grade': "{}{}".format(spec or "A709-", grade)
        }
    return None

def read_me2j(sheet):
    table = sheet.range('A1').expand().value
    data = iter(table)

    header = next(data)
    matl = header.index('Material')
    desc = header.index('Short Text')
    qty = header.index('Order Quantity')

    for row in data:
        match = PROJ_MM.match(row[matl])
        if match:
            job, item, suffix = match.groups()
            row[matl] = f"{job}-9{item}{suffix}"

        matl_data = parse_desc(row[desc])
        if matl_data:
            yield {
                'Material': row[matl],
                'Quantity': row[qty],
                **matl_data
            }

def main():
    wb = xlwings.books.active

    db = pyodbc.connect('DRIVER={SQL Server};SERVER=HSSSNData;DATABASE=SNInterPrd;Trusted_Connection=yes;')
    cursor = db.cursor()
    for item in read_me2j(wb.sheets[0]):
        # print(item)
        cursor.execute(
            # sap_event_id, sheet_name, sheet_type, qty, grade, thk, wid, len, mm
            "EXEC sap.PushSapInventory 'preload2', ?, 'New Sheet', ?, ?, ?, ?, ?, ?;",
            item['Material'],
            item['Quantity'],
            item['Grade'],
            item['Thickness'],
            item['Width'],
            item['Length'],
            item['Material']
        )
    cursor.execute("EXEC sap.InventoryPreExec;")

    db.commit()
    cursor.close()
    db.close()

if __name__ == "__main__":
    main()
