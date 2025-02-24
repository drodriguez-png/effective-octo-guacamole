from os import path
import re

ENV_CONFIG = {
    # "SimTrans Env": [("Sigmanest Env", "District")],
    # SimTrans/Sigmanest Env maps to which database said Env is on
    #   for example, "Dev" maps to SNDBaseDev
    "Prd": [
        ("Prd", 2),
    ],
    "Dev": [
        ("Qas", 4),
        ("Dev", 3),
    ],
}

USE_DB = re.compile("USE SN(DBase|Inter)Dev;")
SIMTRANS_DB = re.compile(r"(FROM|INTO) SNDBaseDev(\.\w+\.\w+)")
CONFIG = re.compile(
    # i.e. (1, '\\hssieng\SNDataQas\', ...)
    r"\(\d+, '(\\\\\w+\\SNData)\w+([\\a-zA-Z]+)'([^\n]*)\)"
)

schema_dir = path.dirname(__file__)
st_template_file = path.join(schema_dir, "SimTransCtrl_Proc.sql")
oys_template_file = path.join(schema_dir, "OysSchema.sql")

with open(st_template_file) as sql:
    st_template = sql.read()
with open(oys_template_file) as sql:
    oys_template = sql.read()


def generate(env, district, simtrans):
    sql = USE_DB.sub(f"USE SNInter{env};", st_template)
    sql = SIMTRANS_DB.sub(f"\\1 SNDBase{simtrans}\\2", sql)
    sql = CONFIG.sub(f"({district}, '\\1{env}\\2'\\3)", sql)

    with open("SimTransCtrl_Proc_{}.sql".format(env), "w") as sql_file:
        sql_file.write(sql)

    sql = re.sub(f"SNInterDev", f"SNInter{env}", oys_template)
    with open("OysSchema_{}.sql".format(env), "w") as sql_file:
        sql_file.write(sql)


def main():
    for simtrans, envs in ENV_CONFIG.items():
        for env in envs:
            generate(*env, simtrans)


if __name__ == "__main__":
    main()
