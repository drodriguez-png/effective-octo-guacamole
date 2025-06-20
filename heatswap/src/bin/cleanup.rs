use chrono::Utc;
use log;
use simplelog::{CombinedLogger, TermLogger, WriteLogger};
use std::{env, fs};

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
    if !cfg!(debug_assertions) {
        // try to set the current directory to the executable's parent
        let _ = env::current_exe().map(|p| p.parent().map(|p| env::set_current_dir(p)));
    }

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
                .open(format!("LogData/cleanup_{}.log", Utc::now().format("%Y-%m-%d")))?,
        ),
    ]);

    let cfg = heatswap::get_database_config()?;

    smol::block_on(async {
        // connect to database and call stored procedure
        let tcp = net::TcpStream::connect(cfg.get_addr()).await?;
        log::debug!("Connected to database at {}", cfg.get_addr());

        let mut client = Client::connect(cfg, tcp)
            .await
            .expect("failed to build SQL client");
        log::debug!("Connected to SQL client");

        // try to log call
        let _ = client.execute(
            r#"
INSERT INTO log.UpdateProgramCalls(ProcCalled)
SELECT 'NcCodeCleanup'
FROM sap.InterfaceConfig
WHERE LogProcedureCalls = 1;
        "#,
            &[],
        );

        for program in heatswap::Program::get_programs(&mut client).await? {
            log::info!("Processing program: {}", program);

            if let Err(e) = program.archive_code(&mut client).await {
                log::error!("Failed to archive code for program {program}: {e}");
            };
        }

        Ok(())
    })
}
