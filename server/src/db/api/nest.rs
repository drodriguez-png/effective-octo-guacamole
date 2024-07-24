use crate::{Error, Result};

use super::super::SqlConn;
use super::{Part, Program, Remnant, Sheet};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Nest {
    // pub archive_packet_id: i32,
    pub program: Program,
    pub parts: Vec<Part>,
    pub sheet: Sheet,
    pub remnants: Vec<Remnant>,
}

impl Nest {
    pub async fn get(conn: &mut SqlConn<'_>, nest: &String) -> crate::Result<Self> {
        // TODO: seems to work for now, but should refactor find by program
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
	PIP.WONumber, PIP.PartName, QtyInProcess as Qty,
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

        let (_archive_packet_id, program) = match results.next() {
            Some(mut programs) if programs.len() > 0 => programs
                .pop()
                .map(|p| {
                    Program::try_from(&p)
                        .map(|prg| (p.get::<i32, _>("ArchivePacketID").unwrap(), prg))
                })
                .unwrap(),
            _ => {
                return Err(Error::NotFound(format!("Program {} not found", nest)));
            }
        }?;

        let parts = results
            .next()
            .unwrap()
            .iter()
            .map(|row| Part::try_from(row))
            .collect::<Result<Vec<Part>>>()?;

        let sheet = match results.next() {
            Some(mut sheets) if sheets.len() > 0 => {
                sheets.pop().map(|row| Sheet::try_from(&row)).unwrap()?
            }
            _ => {
                return Err(Error::NotFound(format!(
                    "No sheet found for program {}",
                    nest
                )));
            }
        };

        let remnants = match results.next() {
            Some(rems) => rems
                .iter()
                .map(|row| Remnant::try_from(row))
                .collect::<Result<Vec<Remnant>>>()?,
            None => Vec::new(),
        };

        Ok(Nest {
            // archive_packet_id,
            program,
            parts,
            sheet,
            remnants,
        })
    }
}

impl TryFrom<&tiberius::Row> for Nest {
    type Error = crate::Error;

    fn try_from(row: &tiberius::Row) -> Result<Self> {
        Ok(Nest {
            // archive_packet_id: row.try_get("ArchivePacketID")?.unwrap(),
            program: Program::try_from(row)?,
            parts: Vec::new(),
            sheet: Sheet::try_from(row)?,
            remnants: Vec::new(),
        })
    }
}
