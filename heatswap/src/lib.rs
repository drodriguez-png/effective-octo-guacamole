use spex::parsing::XmlReader;
use std::fmt::Display;
use std::path::PathBuf;
use std::{fs, io};

const CONFIG_PATH: &str = "Settings.XML";

type DbClient = tiberius::Client<smol::net::TcpStream>;

enum MachineAttr {
    PostFolder,
    ProductionFolder,
    ArchiveFolder,
    Extension,
}

impl MachineAttr {
    fn xml_tag(&self) -> &'static str {
        match self {
            MachineAttr::PostFolder => "SourceNCFolder",
            MachineAttr::ProductionFolder => "OutputNCFolder",
            MachineAttr::ArchiveFolder => "ArchiveNCFolder",
            MachineAttr::Extension => "NCFileExtension",
        }
    }
}

fn get_machine_config(name: &str, attr: MachineAttr) -> io::Result<String> {
    let file = fs::File::open(CONFIG_PATH)?;
    let doc = XmlReader::parse_auto(file)?;

    log::trace!("Finding machine: {}", name);

    let root = doc.root();

    // Find the machine in the XML configuration
    // found at : ConfigSettings(root) > SNMachineList > SNMachine
    let folder = root
        .first("SNMachineList")
        .all("SNMachine")
        .iter()
        .filter(|m| {
            m.req("SNMachineName")
                .text()
                .map(|s| s.to_ascii_uppercase())
                == Ok(name.to_ascii_uppercase())
        })
        .map(|m| m.req(attr.xml_tag()).text())
        .next();

    log::debug!("machine folder: {:?}", folder);
    match folder {
        Some(Ok(f)) => Ok(f.to_string()),
        _ => Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("Machine {} not found in configuration", name),
        )),
    }
}

pub fn get_machine_extension(name: &str) -> Result<String, io::Error> {
    get_machine_config(name, MachineAttr::Extension)
}

#[derive(Debug)]
pub struct Program {
    pub id: i32,
    pub machine: String,
    pub name: String,
}

impl Program {
    pub async fn get_programs(client: &mut DbClient) -> tiberius::Result<Vec<Self>> {
        client
            .simple_query("SELECT Id, ProgramName, MachineName FROM sap.MoveCodeQueue")
            .await?
            .into_first_result()
            .await?
            .iter()
            .map(TryFrom::try_from)
            .collect()
    }

    /// burn the code to the machine
    pub fn move_code_to_prod(&self) -> io::Result<()> {
        let mut src =
            get_machine_config(&self.machine, MachineAttr::PostFolder).map(PathBuf::from)?;
        let mut dest =
            get_machine_config(&self.machine, MachineAttr::ProductionFolder).map(PathBuf::from)?;
        let ext = get_machine_extension(&self.machine)?;

        let file = format!("{}{}", &self.name, ext);
        src.push(&file);
        dest.push(&file);
        log::debug!("Moving file from {} to {}", src.display(), dest.display());
        std::fs::copy(&src, &dest)?;
        log::info!("File moved successfully");

        Ok(())
    }

    /// archive the code after it has been burned
    pub async fn archive_code(&self, client: &mut DbClient) -> io::Result<()> {
        let mut src =
            get_machine_config(&self.machine, MachineAttr::ProductionFolder).map(PathBuf::from)?;
        let archive_folder =
            get_machine_config(&self.machine, MachineAttr::ArchiveFolder).map(PathBuf::from)?;
        let ext = get_machine_extension(&self.machine)?;

        let file = format!("{}{}", &self.name, ext);
        src.push(&file);

        // Find an available filename in the archive folder
        let mut dest = archive_folder.clone();
        dest.push(&file);

        let mut index = 0;
        while dest.exists() {
            index += 1;
            let indexed_file = format!("{}_{}{}", &self.name, index, ext);
            dest = archive_folder.clone();
            dest.push(&indexed_file);
        }

        log::debug!("Moving file from {} to {}", src.display(), dest.display());
        match std::fs::rename(&src, &dest) {
            Ok(_) => {
                log::info!("Successfully archived code for program: {self}");
                let _ = self.delete_from_queue(client).await;
            }
            Err(ref e) if e.kind() == io::ErrorKind::NotFound => {
                log::warn!("NC for Program {self} not found. Skipping archive.");
                let _ = self.delete_from_queue(client).await;
            }

            Err(e) => log::error!("Failed to archive code for program {self}: {e}"),
        };
        log::info!("File moved successfully");

        Ok(())
    }

    /// Delete this program from the MoveCodeQueue
    pub async fn delete_from_queue(&self, client: &mut DbClient) -> tiberius::Result<()> {
        client
            .execute("DELETE FROM sap.MoveCodeQueue WHERE Id = @P1", &[&self.id])
            .await
            .map(|_| ())
    }
}

impl Display for Program {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} at {}", self.name, self.machine)
    }
}

impl TryFrom<&tiberius::Row> for Program {
    type Error = tiberius::error::Error;

    fn try_from(row: &tiberius::Row) -> Result<Self, Self::Error> {
        let id: i32 = row.get::<i32, _>("Id").unwrap_or_default();
        let machine: String = row
            .get::<&str, _>("MachineName")
            .unwrap_or_default()
            .to_string();
        let name: String = row
            .get::<&str, _>("ProgramName")
            .unwrap_or_default()
            .to_string();

        Ok(Program { id, machine, name })
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
    cfg.trust_cert();

    let attrs = db_config.split(';').filter_map(|s| {
        let mut parts = s.split('=');
        match (parts.next(), parts.next()) {
            (Some(key), Some(value)) => Some((key.trim(), value.trim())),
            _ => None,
        }
    });

    log::debug!("Database configuration attributes: {:?}", attrs);

    let mut user = None;
    let mut password = None;
    for (key, value) in attrs {
        match key {
            "Data Source" => cfg.host(value),
            "Initial Catalog" => cfg.database(value),
            "User ID" => user = Some(value),
            "Password" => password = Some(value),
            _ => log::debug!("Ignoring unknown database config key: {} -> {}", key, value),
        }
    }

    cfg.authentication(match (user, password) {
        (Some(user), Some(pwd)) => tiberius::AuthMethod::sql_server(user, pwd),
        _ => tiberius::AuthMethod::Integrated,
    });

    Ok(cfg)
}
