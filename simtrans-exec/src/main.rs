
use smol::{io, net};
use tiberius::{AuthMethod, Client, Config};

const PRD_SERVER: &str = "HSSSNData";
const DEV_SERVER: &str = "hiisqlserv6";

#[derive(Debug)]
struct SqlParams {
    server: &'static str,
    database: &'static str,
    query: &'static str,
}

fn parse_args() -> io::Result<SqlParams> {
        let args: Vec<String> = std::env::args().collect();
        if args.len() < 3 {
            eprintln!("Usage: simtrans-exec <environment> <phase>");
            return Err(io::Error::new(io::ErrorKind::InvalidInput, "Not enough arguments"));
        }

        let (server, database) = match args[1].as_str() {
            "--help" | "-h" | "help" => {
                println!("Usage: simtrans-exec <environment> <phase>");
                println!("Environment should be one of: dev, qas, prd");
                println!("Phase should be one of: preexec, postexec");
                std::process::exit(0);
            }
            "dev" => (DEV_SERVER, "SNInterDev"),
            "qas" => (DEV_SERVER, "SNInterQas"),
            "prd" => (PRD_SERVER, "SNInterPrd"),
            _ => {
                eprintln!("Invalid environment `{}`.\nExpecting one of `dev`, `qas`, or `prd`", args[1]);
                return Err(io::Error::new(io::ErrorKind::InvalidInput, "Invalid environment"));
            },
        };

        // should be one of "preexec", "postexec"
        let query = match args[2].as_str() {
            "preexec" => "EXEC sap.SimTransPreExec;",
            "postexec" => "EXEC sap.SimTransPostExec;",
            _ => {
                eprintln!("Invalid phase `{}`.\nExpecting one of `preexec` or `postexec`", args[2]);
                return Err(io::Error::new(io::ErrorKind::InvalidInput, "Invalid phase"));
            },
        };

        Ok(SqlParams { server, database, query })
}

fn main() -> io::Result<()> {
    let start = std::time::Instant::now();

    let params = parse_args()?;

    let mut cfg = Config::new();
    cfg.host(params.server);
    cfg.database(params.database);
    cfg.authentication(AuthMethod::Integrated); 
    cfg.trust_cert();

    let res = smol::block_on(async {
        // connect to database and call stored procedure
        let tcp = net::TcpStream::connect(cfg.get_addr()).await?;

        let mut client = Client::connect(cfg, tcp)
            .await
            .expect("failed to build SQL client");
        let _ = client.simple_query(params.query).await;

        Ok(())
    });

    println!("Time elapsed: {:.2?}", start.elapsed());

    res
}
