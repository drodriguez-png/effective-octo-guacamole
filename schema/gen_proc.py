from os import path
import re

USE_DB = re.compile("USE SNDBaseISap;")
SIMTRANS_DB = re.compile(r"(FROM|INTO) SNDBaseDev(\.\w+\.\w+)")
CONFIG = re.compile(
    r"\('[A-Z]{3}', \d+, '(\\\\\w+\\)\w+([\\a-zA-Z]+<\w+>.dxf)'([^\n]*)\)"
)

template_file = path.join(path.dirname(__file__), "SimTransCtrl_Proc.sql")
dbs = {
    # "SimTrans Database": [("Env", "Sigmanest Database", "District")],
    "SNDBasePrd": [
        ("PRD", "SNDBasePrd", 1),
    ],
    "SNDBaseDev": [
        ("QAS", "SNDBaseQas", 2),
        ("DEV", "SNDBaseDev", 3),
        ("SBX", "SNDBaseSbx", 4),
    ],
}

with open(template_file) as sql:
    template = sql.read()


def generate(env, db, district, simtransdb):
    sql = USE_DB.sub(f"USE {db};", template)
    sql = SIMTRANS_DB.sub(f"\\1 {simtransdb}\\2", sql)
    sql = CONFIG.sub(f"('{env}', {district}, '\\1{db}\\2'\\3)", sql)

    with open("SimTransCtrl_Proc_{}.sql".format(env), "w") as sql_file:
        sql_file.write(sql)


def main():
    for db, env in dbs.items():
        generate(*env, simtransdb)


if __name__ == "__main__":
    main()

    # testing
    # generate(*dbs["SNDBaseDev"][2], "SNDBaseDev")
