from os import path
import re

USE_DB = re.compile("USE SNDBaseDev;")
SIMTRANS_DB = re.compile(r"(FROM|INTO) SNDBaseDev(\.\w+\.\w+)")
CONFIG = re.compile(
    # i.e. (1, '\\hssieng\SNDataQas\', ...)
    r"\(\d+, '(\\\\\w+\\SNData)\w+([\\a-zA-Z]+)'([^\n]*)\)"
)

template_file = path.join(path.dirname(__file__), "SimTransCtrl_Proc.sql")
dbs = {
    # "SimTrans Env": [("Sigmanest Env", "District")],
    "Prd": [
        ("Prd", 1),
    ],
    "Dev": [
        ("Qas", 2),
        ("Dev", 3),
    ],
}

with open(template_file) as sql:
    template = sql.read()


def generate(env, district, simtrans):
    sql = USE_DB.sub(f"USE SNDBase{env};", template)
    sql = SIMTRANS_DB.sub(f"\\1 SNDBase{simtrans}\\2", sql)
    sql = CONFIG.sub(f"({district}, '\\1{env}\\2'\\3)", sql)

    with open("SimTransCtrl_Proc_{}.sql".format(env), "w") as sql_file:
        sql_file.write(sql)


def main():
    for simtrans, env in dbs.items():
        generate(*env, simtrans)


if __name__ == "__main__":
    main()

    # testing
    # generate(*dbs["Dev"][2], "Dev")
