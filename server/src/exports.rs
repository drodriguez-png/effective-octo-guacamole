use std::collections::HashMap;

use bb8::PooledConnection;
use bb8_tiberius::ConnectionManager;
use serde::{Deserialize, Serialize};
use tiberius::error::Error as SqlError;

type SqlConn<'a> = PooledConnection<'a, ConnectionManager>;

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NestExport {
    archive_packet_id: i32,
    state: TransactionType<Nest>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
enum TransactionType<T> {
    NotFound,
    Created(T),
    Deleted,
    Updated,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Nest {
    archive_packet_id: i32,
    program: Program,
    parts: Vec<Part>,
    sheet: Sheet,
    remnants: Vec<Remnant>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Program {
    program_name: String,
    repeat_id: i32,
    machine_name: String,
    cutting_time: f64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Part {
    part_name: String,
    part_qty: i32,
    job: String,
    shipment: i32,
    true_area: f64,
    nested_area: f64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Sheet {
    sheet_name: String,
    material_master: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Remnant {
    remnant_name: String,
    length: f64,
    width: f64,
    area: f64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct STArcEntry<T> {
    archive_packet_id: i32,
    state: TransactionType<T>,
}

// type FeedbackProgram = STArcEntry<Program>;
// type FeedbackPart = STArcEntry<Part>;

pub async fn export_nest(conn: &mut SqlConn<'_>, nest: &String) -> Result<Nest, anyhow::Error> {
    let mut results = conn
        .query(
            r#"
select
	ProgramName, RepeatID, ArchivePacketID,
	MachineName, CuttingTime
from Program
where ProgramName=@P1;
select
	ProgramName, RepeatID,
	PIP.WONumber, PIP.PartName, QtyInProcess,
	Data1 as Job, cast(Data2 as int) as Shipment,
	TrueArea, NestedArea
from PIP
inner join Part on PIP.PartName=Part.PartName
where ProgramName=@P1;
select distinct
	Stock.SheetName, PrimeCode as MaterialMaster
from Stock
inner join Program on Stock.SheetName=Program.SheetName
where ProgramName=@P1;
select
	RemnantName, ProgramName, RepeatID,
	Length, Width, Area, Weight,
	PrimeCode, Qty
from Remnant
where ProgramName=@P1;
    "#,
            &[nest],
        )
        .await?
        .into_results()
        .await
        .map(|res| {
            log::trace!("{:#?}", res);
            res
        })?
        .into_iter();

    let (archive_packet_id, program) = match results.next() {
        Some(mut programs) if programs.len() > 0 => programs
            .pop()
            .map(|p| {
                (
                    p.get::<i32, _>("ArchivePacketID").unwrap(),
                    Program {
                        program_name: p.get::<&str, _>("ProgramName").unwrap().into(),
                        repeat_id: p.get::<i32, _>("RepeatID").unwrap(),
                        machine_name: p.get::<&str, _>("MachineName").unwrap().into(),
                        cutting_time: p.get("CuttingTime").unwrap(),
                    },
                )
            })
            .unwrap(),
        _ => {
            return Err(anyhow::anyhow!("Program {} not found", nest));
        }
    };

    let parts = match results.next() {
        Some(parts) => parts
            .iter()
            .map(|p| Part {
                part_name: p.get::<&str, _>("PartName").unwrap().into(),
                part_qty: p.get("QtyInProcess").unwrap(),
                job: p.get::<&str, _>("Job").unwrap().into(),
                shipment: p.get("Shipment").unwrap(),
                true_area: p.get("TrueArea").unwrap(),
                nested_area: p.get("NestedArea").unwrap(),
            })
            .collect(),
        None => Vec::new(),
    };

    let sheet = match results.next() {
        Some(mut sheets) => sheets
            .pop()
            .map(|s| Sheet {
                sheet_name: s.get::<&str, _>("SheetName").unwrap().into(),
                material_master: s.get::<&str, _>("MaterialMaster").unwrap().into(),
            })
            .unwrap(),
        None => {
            return Err(anyhow::anyhow!("No sheet found for program {}", nest));
        }
    };

    let remnants = match results.next() {
        Some(rems) => rems
            .iter()
            .map(|r| Remnant {
                remnant_name: r.get::<&str, _>("RemnantName").unwrap().into(),
                length: r.get("Length").unwrap(),
                width: r.get("Width").unwrap(),
                area: r.get("Area").unwrap(),
            })
            .collect(),
        None => Vec::new(),
    };

    Ok(Nest {
        archive_packet_id,
        program,
        parts,
        sheet,
        remnants,
    })
}

pub async fn export_feedback(conn: &mut SqlConn<'_>) -> Result<Vec<NestExport>, SqlError> {
    let mut results = conn
        .simple_query(
            r#"
select
	AutoId, ProgramName, RepeatID,
	ArchivePacketID, TransType,
	STPIPArc.WONumber, STPIPArc.PartName, QtyInProcess,
    Data1 as Job, cast(Data2 as int) as Shipment,
	TrueArea, NestedArea
from STPIPArc
inner join Part on Part.PartName=STPIPArc.PartName and Part.WONumber=STPIPArc.WONumber;
select
	RemnantName, ProgramName, RepeatID,
	Length, Width, Area, Weight,
	PrimeCode, Qty
from Remnant;
select
	AutoId, ProgramName, RepeatID,
	ArchivePacketID, TransType,
	MachineName, CuttingTime,
	UsedArea, ScrapFraction,
	Stock.SheetName, Stock.PrimeCode
from STPrgArc
inner join Stock on Stock.SheetName = STPrgArc.SheetName;
    "#,
        )
        .await?
        .into_results()
        .await
        .map(|res| {
            log::trace!("{:?}", res);
            res
        })?
        .into_iter();

    let mut parts: HashMap<(String, i32), Vec<Part>> = match results.next() {
        Some(parts_rows) => {
            let mut parts: HashMap<(String, i32), Vec<Part>> = HashMap::new();

            for row in parts_rows {
                let key = (
                    row.get::<&str, _>("ProgramName").unwrap().into(),
                    row.get::<i32, _>("RepeatID").unwrap(),
                );
                let part = Part {
                    part_name: row.get::<&str, _>("PartName").unwrap().into(),
                    part_qty: row.get("QtyInProcess").unwrap(),
                    job: row.get::<&str, _>("Job").unwrap().into(),
                    shipment: row.get("Shipment").unwrap(),
                    true_area: row.get("TrueArea").unwrap(),
                    nested_area: row.get("NestedArea").unwrap(),
                };

                match parts.get_mut(&key) {
                    Some(found) => found.push(part),
                    None => {
                        parts.insert(key, vec![part]);
                    }
                }
            }

            parts
        }
        _ => HashMap::new(),
    };

    let mut remnants: HashMap<(String, i32), Vec<Remnant>> = match results.next() {
        Some(rems) => {
            let mut remnants: HashMap<(String, i32), Vec<Remnant>> = HashMap::new();

            for row in rems {
                log::debug!("{:?}", row);
                let key = (
                    row.get::<&str, _>("ProgramName").unwrap().into(),
                    row.get::<i32, _>("RepeatID").unwrap(),
                );

                let rem = Remnant {
                    remnant_name: row.get::<&str, _>("RemnantName").unwrap().into(),
                    length: row.get("Length").unwrap(),
                    width: row.get("Width").unwrap(),
                    area: row.get("Area").unwrap(),
                };

                match remnants.get_mut(&key) {
                    Some(found) => found.push(rem),
                    None => {
                        remnants.insert(key, vec![rem]);
                    }
                }
            }

            remnants
        }
        _ => HashMap::new(),
    };

    match results.next() {
        Some(program_rows) => {
            program_rows
                .iter()
                .map(|row| {
                    // TODO: cannot use program_rows[0] because of repeatID and table might have multiple entries
                    let archive_packet_id = row.get("ArchivePacketID").unwrap_or_default();

                    let state = match row.get("TransType") {
                        Some("SN100") => {
                            let key: (String, i32) = (
                                row.get::<&str, _>("ProgramName").unwrap().into(),
                                row.get::<i32, _>("RepeatID").unwrap(),
                            );

                            let program = Program {
                                program_name: row.get::<&str, _>("ProgramName").unwrap().into(),
                                repeat_id: row.get::<i32, _>("RepeatID").unwrap(),
                                machine_name: row.get::<&str, _>("MachineName").unwrap().into(),
                                cutting_time: row.get("CuttingTime").unwrap(),
                            };

                            let sheet = Sheet {
                                sheet_name: row.get::<&str, _>("SheetName").unwrap().into(),
                                material_master: row.get::<&str, _>("PrimeCode").unwrap().into(),
                            };

                            TransactionType::Created(Nest {
                                archive_packet_id,
                                program,
                                parts: parts.remove(&key).unwrap_or(Vec::new()),
                                sheet,
                                remnants: remnants.remove(&key).unwrap_or(Vec::new()),
                            })
                        }
                        Some("SN101") => TransactionType::Deleted,
                        Some("SN102") => TransactionType::Updated,
                        _ => unreachable!(),
                    };

                    Ok(NestExport {
                        archive_packet_id,
                        state,
                    })
                })
                .collect()
        }
        None => Ok(vec![]),
    }
}
