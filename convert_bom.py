
# /// script
# dependencies = [
#   "pyodbc",
#   "tabulate",
#   "tqdm"
# ]
# ///

from argparse import ArgumentParser
from fractions import Fraction
import csv
import os
import re

CONE_BOM = re.compile(r"ConeBOM_\d{7}[A-Z]\d{2}\.ready")
CONE_MAT = re.compile(r"ConeMAT_\d{7}[A-Z]\d{2}\.ready")
MM = re.compile(r"\d{7}[A-Z]-MM\.ready")
STOCK_MM = re.compile(r"(50(?:\/50)?W?)-(\d{2})(\d{2})(\w*)")
PROJ_MM = re.compile(r"(\d{7}[A-Z]\d{2})-0(\d{4})(\w*)")
GRADE = re.compile(r"([AM]\d{3})-(3\d{2}|TYPE4|(?:HPS)?[5710]{1,2}0W?)((?:[TF][123])?)")

FOLDER = "conversion"

part_grades = dict()

def tsv_wrapper(func):
    def wrapper(self, line):
        line = line.replace("\n", "").split("\t")
        line = func(self, line)
        if line:
            line = [s or '' for s in line]
            return "\t".join(line) + "\n"
        return ''

    return wrapper

def parse_grade(grade):
    match = GRADE.match(grade)
    if match:
        return match.groups()

    return None, None, None

def fmt_inches(val: str | float | int):
    """
    Format inches value as a string with fraction part.
    - '1.0' -> '1'
    - '0.500' -> '1/2'
    - '1.25' -> '1 1/4'
    """
    num = float(val)
    inches = int(num)
    frac = Fraction(num - inches).limit_denominator(32)

    return "{} {}".format(inches or "", frac or "").strip() or "0"

class ReadyFile(object):
    def __init__(self, file_name=None, test_id=None):
        self.file_name = file_name
        self.test_id = test_id

    @staticmethod
    def matches_filename(file_name) -> bool:
        return False

    def process(self, file_name=None):
        if file_name:
            self.file_name = file_name

        variants = [ConeBOM, ConeMAT, ProjMM]
        for Variant in variants:
            if Variant.matches_filename(self.file_name):
                Variant(self.file_name, self.test_id).convert()
                break
        else:
            raise ValueError("No valid variant found for filename `{}`".format(self.file_name))

    def has_header(self) -> bool:
        return False

    def convert(self):
        assert self.file_name is not None, "File name is not set"

        with open(os.path.join(FOLDER, 'input', self.file_name), "r") as file:
            lines = file.readlines()

        with open(os.path.join(FOLDER, 'output', self.file_name.replace('.ready', '_Conv.ready')), "w") as file:
            if self.has_header():
                file.write(self.convert_header(lines.pop(0)))

            for line in lines:
                file.write(self.convert_line(line))

    @tsv_wrapper
    def convert_header(self, line):
        return line

    @tsv_wrapper
    def convert_line(self, line):
        return line

    def fix_raw_mm(self, mm):
        match = PROJ_MM.match(mm)
        if match:
            return "{}-9{}{}".format(*match.groups())

        match = STOCK_MM.match(mm)
        if match:
            grade, inches, frac = match.groups()

            inches = int(inches) + float(frac) / 16
            return "{}-{:.3f}".format(grade, inches).rstrip("0").rstrip(".")

        if self.test_id:
            mm[3] = str(self.test_id)

        return mm

class ConeBOM(ReadyFile):
    """
    modifications:
        - RawMM to new MM
            - Project: Prepend 9 to item
            - Stock: new-new stock
        - convert IN2 to FT2
        - ignore(remove) linear unit rows
    """

    @staticmethod
    def matches_filename(file_name):
        return bool(CONE_BOM.match(file_name))

    @tsv_wrapper
    def convert_line(self, line):
        if line[3] not in ["IN2", "FT2"]:
            return None

        line[1] = self.fix_raw_mm(line[1])
        if line[3] == "IN2":
            line[2] = str(round(float(line[2]) / 144.0, 3))
            line[3] = "FT2"

        if self.test_id:
            for i in (0, 1):
                line[i] = line[i].replace('0', str(self.test_id), 1)

        return line

class ConeMAT(ReadyFile):
    """
    modifications:
        - add 3 columns for spec, grade, and test (split from grade earlier)
        - RawMM to new MM
            - Project: Prepend 9 to item
            - Stock: new-new stock
        - convert IN2 to FT2
        - generate new description
    """

    @staticmethod
    def matches_filename(file_name):
        return bool(CONE_MAT.match(file_name))

    @tsv_wrapper
    def convert_line(self, line):
        # only RawWeb, RawFlange or RawDetail
        if line[2] not in ["RawWeb", "RawFlange", "RawDetail"]:
            return None

        while len(line) < 15:
            line.append(None)

        line[12:] = parse_grade(line[8])
        line[0] = self.fix_raw_mm(line[0])

        if self.test_id:
            line[0] = line[0].replace('0', str(self.test_id), 1)

        if line[7] == "IN2":
            # convert to FT2
            line[6] = str(round(float(line[5]) * 40.8333, 3))
            line[7] = 'FT2'

        # generate description to match new format
        length, wid, thk = [fmt_inches(x) for x in line[3:6]]
        grade, test = line[-2:]
        line[1] = f"PL {thk} x {wid} x {length} {grade}{test}"

        return line

class ProjMM(ReadyFile):
    """
    this file has a header
    modifications:
        - only rows of type WEB, FLANGE, or Part
        - add 5 columns (Spec, Grade, Test, Assembly Method, DocNo)
        - move Document to DocNo
        - Put PartName in Document
        - Parse Spec,Grade,Test from Nothing
    """

    POSSIBLE_ADDITIONS = ["SPEC", "GRADE", "TEST", "ASSYMETHOD", "DOCNO"]
    ORIGINAL_HEADER_LEN = 17
    HEADER_LEN = ORIGINAL_HEADER_LEN + len(POSSIBLE_ADDITIONS)

    @staticmethod
    def matches_filename(file_name):
        return bool(MM.match(file_name))

    def has_header(self):
        return True

    @tsv_wrapper
    def convert_header(self, line):
        return line + self.POSSIBLE_ADDITIONS[len(line)-self.ORIGINAL_HEADER_LEN:]

    @tsv_wrapper
    def convert_line(self, line):
        if line[0] not in ["WEB", "FLANGE", "PART"]:
            return None

        while len(line) < self.HEADER_LEN:
            line.append(None)

        line[-1] = line[12] # move DwgNo
        line[12] = line[1].replace('-', '_', 1)  # copy PartName

        if self.test_id:
            line[1] = line[1].replace('0', str(self.test_id), 1)

        # get Spec, Grade, Test
        line[17:20] = part_grades.setdefault(line[1], [None] * 3)

        return line

def main():
    parser = ArgumentParser()
    parser.add_argument("--id", type=int, help="Id for renaming project")
    parser.add_argument("--gen-parts-grades", action="store_true", help="Generate part grades")
    parser.add_argument("--min-project", type=int, default=0, help="Floor for filtering projects")
    args = parser.parse_args()

    if args.min_project:
        args.min_project = int(str(args.min_project).ljust(7, '0'))
        print("Min project:", args.min_project)

    if args.gen_parts_grades:
        generate_part_grades(floor=args.min_project)
    else:
        part_grades.update(load_bom_parts())
        converter = ReadyFile(test_id=args.id)
        for f in os.listdir(os.path.join(FOLDER, "input")):
            converter.process(f)

def generate_part_grades(floor=0):
    import pyodbc
    from tqdm import tqdm

    conn = pyodbc.connect("DRIVER={};SERVER=HSSSQLSERV;Trusted_connection=yes;".format(pyodbc.drivers()[0]))
    cursor = conn.cursor()

    # get structid
    cursor.execute("EXEC BOM.SAP.GetEngStructures")
    jobs = list((line.Structure, line.StructID) for line in cursor.fetchall() if int(line.Project) >= floor)

    # get shipments
    progress = tqdm(jobs, desc="Reading Job BOMs")
    for job, structid in progress:
        cursor.execute("EXEC BOM.SAP.GetEngShipments @StructID=?", structid)
        shipments = list(line.ShipNo for line in cursor.fetchall())

        for ship in tqdm(shipments, desc="Reading Shipments for {}".format(job), position=1, leave=False):
            try:
                cursor.execute("EXEC BOM.SAP.GetBOMData @Job=?, @Ship=?", job, ship)
                for line in cursor.fetchall():
                    if line.Commodity not in ["PL", "MISC", "SHEET"]:
                        continue

                    mark = f"{job}-{line.Piecemark}".upper()
                    spec = line.Specification
                    grade = line.Grade
                    test = line.ImpactTest
                    if spec == 'A606 Type 4':
                        part_grades[mark] = ['A606', 'TYPE4', None]
                        continue

                    if test and grade.startswith("HPS"):
                        test += '3'
                    elif test:
                        test += '2'
                    part_grades[mark] = [spec, grade, test]
                    # else:
                    #     print("Grade not parsed:", line.Grade)
            except Exception as e:
                progress.write(f"Error fetching BOM data for job {job} and ship {ship} ({structid}): {e}")

    cursor.close()

    with open("part_grades.csv", "w", newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Mark', 'Specification', 'Grade', 'ImpactTest'])
        for mark, data in part_grades.items():
            writer.writerow([mark] + data)

def load_bom_parts():
    with open("part_grades.csv", "r") as f:
        reader = csv.reader(f)
        next(reader)  # Skip header
        return {row[0]: row[1:] for row in reader}

if __name__ == "__main__":
    main()
