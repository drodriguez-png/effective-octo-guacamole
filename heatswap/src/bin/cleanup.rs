
use heatswap::get_machine_post_folder;
use log;
use simplelog::{
    ColorChoice, CombinedLogger, Config, LevelFilter, TermLogger, TerminalMode, WriteLogger,
};
use std::fmt::Display;
use std::fs::{self, OpenOptions};
use std::io;

use gumdrop::Options;
use glob::glob;

/// Heat Swap NC code interface
#[derive(Debug, gumdrop::Options)]
struct Cli {
    /// name of the program's machine
    #[options(free)]
    machine: String,
    /// name of the NC program
    #[options(free)]
    program: String,

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
    #[error("I/O Error")]
    IoError(#[from] std::io::Error),
}

#[derive(Debug)]
struct Program {
    machine: String,
    name: String,
}

impl Display for Program {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{} -> at {}",
            self.name,
            self.machine
        )
    }
}

impl Cli {
    fn validate(self) -> Result<Program, ValidationError> {
        // TODO: validate program name (file exists)
        if self.program == "invalid" {
            return Err(ValidationError::InvalidProgramName);
        }

        // TODO: validate machine from config
        if self.machine == "invalid" {
            return Err(ValidationError::InvalidMachine);
        }

        Ok(Program {
            machine: self.machine,
            name: self.program,
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
                .open("cleanup.log")?,
        ),
    ]);

    log::debug!("{:?}", args);
    let prog = args.validate()?;

    let cfg = get_machine_post_folder(&prog.machine)
        .map_err(|_| ValidationError::InvalidMachine)?;

    log::info!("{}", cfg);
    // move_code_4p(prog)

    Ok(())
}

#[allow(dead_code)]
fn move_code_4b(prog: &Program) -> io::Result<()> {
    // TODO: path from OYS HeatSwap config (QAS/DEV)
    let src_files = glob(&format!(r"\\hssieng\SNDataDev\NC\AtMachine\{}*", prog.name)).unwrap();
    for src in src_files {
        let src = src.unwrap();
        fs::rename(&src, &src.to_str().unwrap().replace("AtMachine", "Archive"))?;
    }

    Ok(())
}
