use std::path::Display;

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

    help: bool,
}

#[derive(Debug, thiserror::Error)]
enum ValidationError {
    #[error("Invalid program name")]
    InvalidProgramName,
}

#[derive(Debug)]
struct Program {
    name: String,
    heat: Vec<String>,
}

impl Display for Program {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: [{}]", self.name, self.heat.join("|"))
    }
}

impl Cli {
    fn validate(self) -> Result<Program, ValidationError> {
        // TODO: validate

        Ok(Program {
            name: self.program,
            heat: self.heat,
        })
    }
}

fn main() -> Result<(), ValidationError> {
    let args = Cli::parse_args_default_or_exit();

    println!("{:#?}", args);

    let prog = args.validate()?;
    println!("{}", prog);

    Ok(())
}
