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
        Some(mut programs) => programs
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
        None => {
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
                remnant_name: r.get::<&str, _>("SheetName").unwrap().into(),
                length: r.get("SheetName").unwrap(),
                width: r.get("SheetName").unwrap(),
                area: r.get("SheetName").unwrap(),
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

pub async fn export_feedback(
    conn: &mut SqlConn<'_>,
    nest: &String,
) -> Result<NestExport, SqlError> {
    let mut results = conn
        .query(
            r#"
select
	AutoId, ProgramName, RepeatID,
	ArchivePacketID, TransType,
	MachineName, CuttingTime,
	UsedArea, ScrapFraction
from STPrgArc
where ProgramName=@P1;
select
	AutoId, ProgramName, RepeatID,
	ArchivePacketID, TransType,
	WONumber, PartName, QtyInProcess,
	TrueArea, NestedArea
from STPIPArc
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

    match results.next() {
        Some(program_rows) => {
            // TODO: cannot use program_rows[0] because of repeatID and table might have multiple entries
            let archive_packet_id = program_rows[0].get("ArchivePacketID").unwrap_or_default();

            let state = match program_rows[0].get("TransType") {
                Some("SN100") => todo!(),
                Some("SN101") => TransactionType::Deleted,
                Some("SN102") => TransactionType::Updated,
                _ => unreachable!(),
            };

            Ok(NestExport {
                archive_packet_id,
                state,
            })
        }
        None => Ok(NestExport {
            archive_packet_id: -1,
            state: TransactionType::NotFound,
        }),
    }
}
