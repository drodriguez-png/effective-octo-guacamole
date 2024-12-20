from os import path

template_file = path.join(path.dirname(__file__), "SimTransCtrl_Proc.sql")
dbs = [
    # SAP Env, Database, District, SimTransDatabase
    ("PRD", "SNDBasePrd", 1, "SNDBasePrd"),
    ("QAS", "SNDBaseQas", 2, "SNDBaseDev"),
    ("DEV", "SNDBaseDev", 3, "SNDBaseDev"),
    ("SBX", "SNDBaseSbx", 4, "SNDBaseDev"),
]

with open(template_file) as sql:
    template = sql.read()

for env, db, district, simtransdb in dbs:
    network_path = path.join(r"\\hssieng", db)

    sql = template.replace("SNDBaseISap", db)
    sql = sql.replace("SNDBaseDev", simtransdb)
    sql = sql.replace(
        r"'QAS', 1, '\\hssieng\SNDataQas",
        "'{}', {}, '{}".format(env, district, network_path),
    )

    with open("SimTransCtrl_Proc_{}.sql".format(env), "w") as sql_file:
        sql_file.write(sql)
