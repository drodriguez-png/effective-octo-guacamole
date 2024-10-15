use serde::{Deserialize, Serialize};

use crate::{db::DbPool, Result};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Program {
    pub id: i32,
    pub archive_packet_id: i32,
    pub program_name: String,
    pub machine_name: String,
    pub cutting_time: f64,
}

impl Program {
    /// get in process and updated programs from feedback
    pub async fn get_feedback(pool: DbPool) -> Result<Vec<Self>> {
        pool.get()
            .await?
            .simple_query(
                r#"
SELECT
    AutoID,
    ArchivePacketID,
    TransType,
    ProgramName,
    MachineName,
    CuttingTime
FROM STPrgArc
        "#,
            )
            .await?
            .into_first_result()
            .await?
            .iter()
            .map(Self::try_from)
            .collect()
    }
}

impl TryFrom<&tiberius::Row> for Program {
    type Error = crate::Error;

    fn try_from(row: &tiberius::Row) -> Result<Self> {
        Ok(Self {
            id: row.try_get("AutoID")?.unwrap(),
            archive_packet_id: row.try_get("ArchivePacketID")?.unwrap(),
            program_name: row
                .try_get::<&str, _>("ProgramName")?
                .map(Into::into)
                .unwrap(),
            machine_name: row
                .try_get::<&str, _>("MachineName")?
                .map(Into::into)
                .unwrap(),
            cutting_time: row.try_get("CuttingTime")?.unwrap(),
        })
    }
}
