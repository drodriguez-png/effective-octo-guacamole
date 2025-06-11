
use std::fmt::Display;
use std::{fs, io};
use std::path::PathBuf;
use spex::parsing::XmlReader;

const CONFIG_PATH: &str = "Settings.XML";

enum MachineAttr {
    PostFolder,
    ProductionFolder,
    ArchiveFolder,
    Extension,
}

impl MachineAttr {
    fn xml_tag(&self) -> &'static str {
        match self {
            MachineAttr::PostFolder => "PostNCFolder",
            MachineAttr::ProductionFolder => "ProductionNCFolder",
            MachineAttr::ArchiveFolder => "ArchiveNCFolder",
            MachineAttr::Extension => "NCExtension",
        }
    }
}

fn get_machine_config(name: &str, attr: MachineAttr) -> io::Result<String> {
    let file = fs::File::open(CONFIG_PATH)?;
    let doc = XmlReader::parse_auto(file)?;

    log::debug!("Finding machine: {}", name);

    let root = doc.root();

    // Find the machine in the XML configuration
    // found at : ConfigSettings(root) > SNMachineList > SNMachine
    let folder =  root
        .first("SNMachineList")
        .all("SNMachine")
        .iter()
        .filter(|m| m.req("SNMachineName").text() == Ok(name))
        .map(|m| m.req(attr.xml_tag()).text())
        .next();
    
    log::debug!("machine folder: {:?}", folder);
    match folder {
        Some(Ok(f)) => Ok(f.to_string()),
        _ => Err(io::Error::new(io::ErrorKind::NotFound, format!("Machine {} not found in configuration", name))),
    }
}

pub fn get_machine_extension(name: &str) -> Result<String, io::Error> {
    get_machine_config(name, MachineAttr::Extension)
}

#[derive(Debug)]
pub struct Program {
    pub machine: String,
    pub name: String,
    pub heat: Vec<String>,
}

impl Program {
    fn move_code(&self, src: MachineAttr, dest: MachineAttr) -> io::Result<()> {
        let mut src = get_machine_config(&self.machine, src).map(PathBuf::from)?;
        let mut dest = get_machine_config(&self.machine, dest).map(PathBuf::from)?;
        let ext = get_machine_extension(&self.machine)?;

        let file = format!("{}{}", &self.name, ext);
        src.push(&file);
        dest.push(&file);
        log::info!("Moving file from {} to {}", src.display(), dest.display());
        std::fs::rename(&src, &dest)?;
        log::info!("File moved successfully");

        Ok(())
    }

    pub fn move_code_to_prod(&self) -> io::Result<()> {
        self.move_code(MachineAttr::PostFolder, MachineAttr::ProductionFolder)
    }
    
    /// archive the code after it has been burned
    pub fn archive_code(&self) -> io::Result<()> {
        self.move_code(MachineAttr::ProductionFolder, MachineAttr::ArchiveFolder)
    }
}

impl Display for Program {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{} -> [{}] at {}",
            self.name,
            self.heat.join("|"),
            self.machine
        )
    }
}

impl TryFrom<&tiberius::Row> for Program {
    type Error = tiberius::error::Error;

    fn try_from(row: &tiberius::Row) -> Result<Self, Self::Error> {
        let machine: String = row.get::<&str, _>("MachineName").unwrap_or_default().to_string();
        let name: String = row.get::<&str, _>("ProgramName").unwrap_or_default().to_string();

        Ok(Program {
            machine,
            name,
            heat: Vec::new(),
        })
    }
}

pub fn get_database_config() -> io::Result<tiberius::Config> {
    let file = fs::File::open(CONFIG_PATH)?;
    let doc = XmlReader::parse_auto(file)?;

    let root = doc.root();
    let db_config = root
        .req("SN_SAP_INTConnectionStr")
        .text()
        .map_err(|_| io::Error::new(io::ErrorKind::NotFound, "Database configuration not found"))?;

    let mut cfg = tiberius::Config::new();
    cfg.authentication(tiberius::AuthMethod::Integrated); 
    cfg.trust_cert();

    let attrs = db_config.split(';')
        .filter_map(|s| {
            let mut parts = s.split('=');
            match (parts.next(), parts.next()) {
                (Some(key), Some(value)) => Some((key.trim(), value.trim())),
                _ => None,
            }
        });

    log::debug!("Database configuration attributes: {:?}", attrs);

    for (key, value) in attrs {
        match key {
            "Data Source" => cfg.host(value),
            "Initial Catalog" => cfg.database(value),
            _ => log::debug!("Ignoring unknown database config key: {} -> {}", key, value),
        }
    }

    Ok(cfg)
}
