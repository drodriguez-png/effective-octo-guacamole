use serde::{Deserialize, Serialize};

use super::FeedbackEntry;
use crate::{db::SqlConn, Result};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Program {
    pub program_name: String,
    pub repeat_id: i32,
    pub machine_name: String,
    pub cutting_time: f64,
}

impl Program {
    /// get in process and updated programs from feedback
    pub async fn get_feedback(conn: &mut SqlConn<'_>) -> Result<Vec<FeedbackEntry<Self>>> {
        conn.simple_query(
            r#"
select
	ProgramName, RepeatID,
	ArchivePacketID, TransType,
	MachineName, CuttingTime
from STPrgArc;
        "#,
        )
        .await?
        .into_first_result()
        .await?
        .iter()
        .map(FeedbackEntry::try_from)
        .collect()
    }
}

impl TryFrom<&tiberius::Row> for Program {
    type Error = crate::Error;

    fn try_from(row: &tiberius::Row) -> Result<Self> {
        Ok(Self {
            program_name: row
                .try_get::<&str, _>("ProgramName")?
                .map(Into::into)
                .unwrap(),
            repeat_id: row.try_get::<i32, _>("RepeatID")?.unwrap(),
            machine_name: row
                .try_get::<&str, _>("MachineName")?
                .map(Into::into)
                .unwrap(),
            cutting_time: row.try_get("CuttingTime")?.unwrap(),
        })
    }
}
