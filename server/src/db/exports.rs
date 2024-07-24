use serde::{Deserialize, Serialize};
use tokio::sync::{mpsc, oneshot};

use super::{
    api::{FeedbackEntry, Nest, Part, Remnant, TransactionType},
    DbPool,
};
use crate::Result;

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct STArcEntry<T> {
    archive_packet_id: i32,
    state: TransactionType<T>,
}

#[derive(Debug)]
enum GetProgramData {
    GetParts(i32, String, oneshot::Sender<Result<Vec<Part>>>),
    GetRemnants(String, i32, oneshot::Sender<Result<Vec<Remnant>>>),
}
pub async fn export_feedback(db: DbPool) -> Result<Vec<FeedbackEntry<Nest>>> {
    let mut programs: Vec<FeedbackEntry<Nest>> = db
        .get()
        .await?
        .simple_query(
            r#"
select
	ProgramName,
    RepeatID,
	ArchivePacketID,
    TransType,
	MachineName,
    CuttingTime,
    Stock.SheetName,
    PrimeCode as MaterialMaster
from STPrgArc
inner join Stock on Stock.SheetName=STPrgArc.SheetName;
        "#,
        )
        .await?
        .into_first_result()
        .await?
        .iter()
        .map::<Result<FeedbackEntry<Nest>>, _>(FeedbackEntry::try_from)
        .collect::<Result<Vec<FeedbackEntry<Nest>>>>()?;

    // db fetching actor
    // let mut conn = db.get().await?;
    let (get_parts, mut rx) = mpsc::channel(8);
    tokio::spawn(async move {
        while let Some(payload) = rx.recv().await {
            let conn = &mut db
                .get()
                .await
                .expect("Failed to get db connection in worker");

            match payload {
                GetProgramData::GetParts(apid, tcode, respond_to) => {
                    let _ =
                        respond_to.send(Part::get_ip_feedback_by_program(conn, apid, tcode).await);
                }
                GetProgramData::GetRemnants(program, repeat_id, respond_to) => {
                    let _ = respond_to.send(
                        Remnant::get_future_remnants_by_program(conn, program, repeat_id).await,
                    );
                }
            }
        }
    });

    let mut nests = Vec::new();
    while let Some(mut program) = programs.pop() {
        if let TransactionType::Created(ref mut nest) = program.state {
            // get parts
            let (respond_to, parts) = oneshot::channel();
            let _ = get_parts
                .send(GetProgramData::GetParts(
                    program.archive_packet_id,
                    String::from("SN100"),
                    respond_to,
                ))
                .await;

            // get remnants
            let (respond_to, rems) = oneshot::channel();
            let _ = get_parts
                .send(GetProgramData::GetRemnants(
                    nest.program.program_name.to_string(),
                    nest.program.repeat_id,
                    respond_to,
                ))
                .await;

            // store parts result
            if let Ok(parts) = parts.await {
                nest.parts.append(&mut parts?);
            }
            // store remnants result
            if let Ok(rems) = rems.await {
                nest.remnants.append(&mut rems?);
            }
        }

        nests.push(program);
    }

    Ok(nests)
}
