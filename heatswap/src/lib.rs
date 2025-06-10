
use std::{fs, io};
use spex::parsing::XmlReader;

// TODO: SAP env
const CONFIG_PATH: &str = r"\\hssieng\SNDataDev\OYSPlugins\SAPPost\Settings.XML";

pub fn get_machine_post_folder(name: &str) -> Result<String, io::Error> {
    let file = fs::File::open(CONFIG_PATH)?;
    let doc = XmlReader::parse_auto(file)?;

    println!("Finding machine: {}", name);

    let root = doc.root();

    // Find the machine in the XML configuration
    // found at : ConfigSettings(root) > SNMachineList > SNMachine
    let folder =  root
        .first("SNMachineList")
        .all("SNMachine")
        .iter()
        .filter(|m| m.req("SNMachineName").text() == Ok(name))
        .map(|m| m.req("ProductionNCFolder").text())
        .next();

    log::debug!("machine folder: {:?}", folder);
    match folder {
        Some(Ok(f)) => Ok(f.to_string()),
        _ => Err(io::Error::new(io::ErrorKind::NotFound, format!("Machine {} not found in configuration", name))),
    }
}
