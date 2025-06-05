from os import path, mkdir
from glob import glob
import re

ENV_CONFIG = {
    # "SimTrans Env": [("Sigmanest Env", "District", "LogProcedureCalls")],
    # SimTrans/Sigmanest Env maps to which database said Env is on
    #   for example, "Dev" maps to SNDBaseDev
    "Dev": [
        ("Qas", 4, True),
        ("Dev", 3, True),
    ],
    "Prd": [
        ("Prd", 5, False),
    ],
}

INTER_DB = re.compile("SNInterDev")
SIGMA_DB = re.compile(r"(SNDBase)Dev(\.\w+\.(?!TransAct)\w+)")
SIMTRANS_DB = re.compile(r"(SNDBase)Dev(\.dbo\.TransAct)")
CONFIG_DISTRICT = re.compile(r"(DECLARE @district INT =) 1;")
CONFIG_LOGGING = re.compile(r"(DECLARE @do_logging BIT =) 0;")
CONFIG_ENV = re.compile(r"(DECLARE @env_name VARCHAR\(8\) =) 'Qas';")

schema_dir = path.join(path.dirname(__file__), "schema")

def generate(env, district, do_logging, simtrans):
    try:
        mkdir("dist")
    except FileExistsError:
        pass

    for f in glob("SapInter_*.sql", root_dir=schema_dir):
        with open(path.join(schema_dir, f), "r") as sql_file:
            sql = sql_file.read()

        sql = INTER_DB.sub(f"SNInter{env}", sql)
        sql = SIGMA_DB.sub(f"\\1{env}\\2", sql)
        sql = SIMTRANS_DB.sub(f"\\1{simtrans}\\2", sql)

        if f == "SapInter_HssSchema.sql":
            sql = CONFIG_DISTRICT.sub(f"\\1 {district};", sql)
            sql = CONFIG_LOGGING.sub(f"\\1 {int(do_logging)};", sql)
            sql = CONFIG_ENV.sub(f"\\1 '{env}';", sql)

        with open(path.join("dist", f"{env}_{f}"), "w") as sql_file:
            sql_file.write(sql)


def main():
    for simtrans, envs in ENV_CONFIG.items():
        for env in envs:
            generate(*env, simtrans)


if __name__ == "__main__":
    main()
