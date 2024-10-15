import pyodbc
from os import path, getenv
from string import Template
from argparse import ArgumentParser
import re

CONN_STR = Template("DRIVER={$driver};SERVER=$server;UID=$user;PWD=$pwd;DATABASE=$db;")


def main():
    parser = ArgumentParser()
    parser.add_argument("target", help="init stock data")
    parser.add_argument("id", default="?", nargs="?", help="init stock data")
    parser.add_argument("args", default=[], nargs="?", help="additional arguments")
    args = parser.parse_args()
    # print(args)

    func = args.id

    schema = parse_schema(args.target)
    if func == "?":
        print("available functions:")
        for key in list(schema)[::]:
            try:
                int(key)
                continue
            except:
                print(f"\t{key}")
        return

    assert func in schema, f"Unexpected id `{func}`"
    sql(schema[func], args.args)


def parse_schema(cmd):
    with open(path.join(path.dirname(__file__), f"schema/{cmd}.sql")) as f:
        sql = f.read()
    funcs = re.compile(r"-- <(?:(\d+): )?(\w+)>\n(.+?)\n[\n$]", re.DOTALL).findall(sql)
    # print(funcs)

    schema = dict()
    for num, name, sql in funcs:
        schema[name] = sql
        if num:
            # print("added by id", num, name)
            schema[num] = sql

    return schema


def sql(sql="", args=None):
    cnxn_args = dict(
        driver=pyodbc.drivers()[0],
        server="hiisqlserv6",
        db="SNDBaseISap",
        user=getenv("SNDB_USER"),
        pwd=getenv("SNDB_PWD"),
    )

    cnxn = pyodbc.connect(CONN_STR.substitute(**cnxn_args))
    cnxn.execute(sql, args)
    cnxn.commit()


if __name__ == "__main__":
    main()
