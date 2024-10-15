use crate::{db::SqlConn, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Remnant {
    pub remnant_name: String,
    pub area: f64,
}

impl Remnant {
    /// get remnants to be created by a program
    pub async fn get_future_remnants_by_program(
        conn: &mut SqlConn<'_>,
        program: String,
        rid: i32,
    ) -> Result<Vec<Self>> {
        conn.query(
            r#"
select
	RemnantName,
    Area
from Remnant
where ProgramName=@P1 and RepeatId=@P2;
        "#,
            &[&program, &rid],
        )
        .await?
        .into_first_result()
        .await?
        .iter()
        .map(Self::try_from)
        .collect()
    }
}

impl TryFrom<&tiberius::Row> for Remnant {
    type Error = crate::Error;

    fn try_from(row: &tiberius::Row) -> Result<Self> {
        Ok(Self {
            remnant_name: row
                .try_get::<&str, _>("RemnantName")?
                .map(Into::into)
                .unwrap(),
            area: row.try_get("Area")?.unwrap(),
        })
    }
}
