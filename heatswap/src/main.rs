use log;
use simplelog::{
    ColorChoice, CombinedLogger, Config, LevelFilter, TermLogger, TerminalMode, WriteLogger,
};
use std::fmt::Display;
use std::fs::OpenOptions;

use gumdrop::Options;
use regex::Regex;

/// Heat Swap NC code interface
#[derive(Debug, gumdrop::Options)]
struct Cli {
    /// name of the program's machine
    #[options(free)]
    machine: String,
    /// name of the NC program
    #[options(free)]
    program: String,
    /// heat number(s) of the selected batch(es)
    #[options(free)]
    heat: String,

    /// print help message
    help: bool,
    #[options(count, help = "show more output")]
    verbose: u32,
}

#[derive(Debug, thiserror::Error)]
enum ValidationError {
    #[error("Invalid machine")]
    InvalidMachine,
    #[error("Invalid program name")]
    InvalidProgramName,
    #[error("At least 1 heat number must be provided")]
    NoHeatNumbers,
    #[error("Heat numbers could not be parsed")]
    HeatNumbersParsingError,
    #[error("I/O Error")]
    IoError(#[from] std::io::Error),
}

#[derive(Debug)]
struct Program {
    machine: String,
    name: String,
    heat: Vec<String>,
}

impl Display for Program {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} -> [{}] at {}", self.name, self.heat.join("|"), self.machine)
    }
}

impl Cli {
    fn validate(&self) -> Result<Program, ValidationError> {
        if self.program == "invalid" {
            return Err(ValidationError::InvalidProgramName);
        }

        if self.machine == "invalid" {
            return Err(ValidationError::InvalidMachine);
        }

        if self.heat.is_empty() {
            return Err(ValidationError::NoHeatNumbers);
        }

        let template = Regex::new(r"(?:\(\w+\))+").unwrap();
        if !template.is_match(&self.heat) {
            return Err(ValidationError::HeatNumbersParsingError);
        }

        let words = Regex::new(r"\w+").unwrap();
        Ok(Program {
            machine: self.machine.clone(),
            name: self.program.clone(),
            heat: words.find_iter(&self.heat).map(|m| String::from(m.as_str())).collect(),
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
