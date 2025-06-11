
use heatswap::Program;
use log;
use simplelog::{
    CombinedLogger, TermLogger, WriteLogger,
};
use std::{fs, io};

use smol::net;
use tiberius::{self, Client};

#[derive(Debug, thiserror::Error)]
enum AppError {
    #[error("I/O Error")]
    IoError(#[from] std::io::Error),
    #[error("Database Error")]
    DatabaseError(#[from] tiberius::error::Error),
}

fn main() -> Result<(), AppError> {
    let _ = CombinedLogger::init(vec![
        TermLogger::new(
            simplelog::LevelFilter::Warn,
            simplelog::Config::default(),
            simplelog::TerminalMode::Mixed,
            simplelog::ColorChoice::Auto,
        ),
        WriteLogger::new(
            simplelog::LevelFilter::Debug,
            simplelog::Config::default(),
            fs::OpenOptions::new()
                .write(true)
                .append(true)
                .create(true)
                .open("LogData/cleanup.log")?,
        ),
    ]);

    // TODO: what happens for programs with a repeat?
    let cfg = heatswap::get_database_config()?;

    smol::block_on(async {
        // connect to database and call stored procedure
        let tcp = net::TcpStream::connect(cfg.get_addr()).await?;
        log::debug!("Connected to database at {}", cfg.get_addr());

        let mut client = Client::connect(cfg, tcp)
            .await
            .expect("failed to build SQL client");
        log::debug!("Connected to SQL client");

        for program in get_programs(&mut client).await? {
            log::info!("Processing program: {}", program);

            match program.archive_code() {
                Ok(_) => log::info!("Successfully archived code for program: {}", program),
                Err(ref e) if e.kind() == io::ErrorKind::NotFound =>
                    log::warn!("NC for Program {} not found. Skipping archive.", program),
                Err(e) => log::error!("Failed to archive code for program {}: {}", program, e),
            }
        }

        Ok(())
    })
}

async fn get_programs(client: &mut Client<net::TcpStream>) -> tiberius::Result<Vec<Program>> {
    client
        .simple_query("SELECT * FROM sap.MoveCodeQueue").await?
        .into_first_result().await?
        .iter()
        .map(TryFrom::try_from)
        .collect()
}
