use log;
use simplelog::{
    ColorChoice, CombinedLogger, Config, LevelFilter, TermLogger, TerminalMode, WriteLogger,
};
use std::fmt::Display;
use std::fs::OpenOptions;

use gumdrop::Options;

/// Heat Swap NC code interface
#[derive(Debug, gumdrop::Options)]
struct Cli {
    /// name of the NC program
    #[options(free)]
    program: String,
    /// heat number(s) of the selected batch(es)
    #[options(free)]
    heat: Vec<String>,

    /// print help message
    help: bool,
    #[options(count, help = "show more output")]
    verbose: u32,
}

#[derive(Debug, thiserror::Error)]
enum ValidationError {
    #[error("Invalid program name")]
    InvalidProgramName,
    #[error("At least 1 heat number must be provided")]
    NoHeatNumbers,
    #[error("I/O Error")]
    IoError(#[from] std::io::Error),
}

#[derive(Debug)]
struct Program {
    name: String,
    heat: Vec<String>,
}

impl Display for Program {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} -> [{}]", self.name, self.heat.join("|"))
    }
}

impl Cli {
    fn validate(&self) -> Result<Program, ValidationError> {
        if self.program == "invalid" {
            return Err(ValidationError::InvalidProgramName);
        }

        if self.heat.is_empty() {
            return Err(ValidationError::NoHeatNumbers);
        }

        Ok(Program {
            name: self.program.clone(),
            heat: self.heat.clone(),
        })
    }
}

fn main() -> Result<(), ValidationError> {
    let args = Cli::parse_args_default_or_exit();

    let mut term_level = LevelFilter::Warn;
    if args.verbose > 0 {
        term_level = LevelFilter::Info;
    }

    let _ = CombinedLogger::init(vec![
        TermLogger::new(
            term_level,
            Config::default(),
            TerminalMode::Mixed,
            ColorChoice::Auto,
        ),
        WriteLogger::new(
            LevelFilter::Trace,
            Config::default(),
            OpenOptions::new()
                .write(true)
                .append(true)
                .create(true)
                .open("heatswap.log")?,
        ),
    ]);

    log::debug!("{:?}", args);
    match args.validate() {
        Ok(prog) => log::info!("{}", prog),
        Err(e) => log::error!("Error: {}", e),
    }

    Ok(())
}
