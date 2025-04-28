
from argparse import ArgumentParser
from dataclasses import dataclass
from pathlib import Path
import shutil
from tqdm import tqdm

FILE_SERVER = Path(r"\\hssieng")


@dataclass
class Db:
    server: str
    sndb: str
    interdb: str


@dataclass
class Env:
    env: str
    db: Db

    def __init__(self, env: str, db_server: str):
        self.env = env
        self.db = Db(
            db_server,
            f"SNDBase{self.env}",
            f"SNInter{self.env}",
        )

    @property
    def network_path(self):
        return FILE_SERVER / f"SNData{self.env}"

    @property
    def post_dir(self):
        return self.network_path / "Post"


DEV = Env("Dev", "HIISQLSERV6")
QAS = Env("Qas", "HIISQLSERV6")
PRD = Env("Prd", "HSSSNData")


def main():
    parser = ArgumentParser()
    parser.add_argument("--src", dest="src", help="Source environment")
    parser.add_argument("--dst", dest="dst", help="Destination environment")
    args = parser.parse_args()

    match (args.src, args.dst):
        case ("dev", "qas"):
            dev_to_qas()
        case ("qas", "prd"):
            qas_to_prd()
        case ("prd", "qas"):
            prd_to_qas()
        case _:
            print("Unsupported transport environments")
            print("Options are:")
            print("\tdev -> qas")
            print("\tqas -> prd")
            print("\tprd -> qas")


def dev_to_qas():
    copy_posts(DEV, QAS)


def qas_to_prd():
    copy_posts(QAS, PRD)


def prd_to_qas():
    pass


def copy_posts(src: Env, dest: Env):
    for path in tqdm(list(src.post_dir.glob("*.Nc.xml")), desc="[TEC] Task Params"):
        shutil.copy(path, dest.post_dir)


if __name__ == "__main__":
    main()
