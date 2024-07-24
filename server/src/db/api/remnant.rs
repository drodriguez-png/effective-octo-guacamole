use crate::{db::SqlConn, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Remnant {
    pub remnant_name: String,
    pub length: f64,
    pub width: f64,
    pub area: f64,
}

impl Remnant {
    /// get remnants to be created by programs
    pub async fn get_future_remnants(conn: &mut SqlConn<'_>) -> Result<Vec<(String, i32, Self)>> {
        conn.simple_query(
            r#"
select
	RemnantName,
    ProgramName,
    RepeatId,
	Length,
    Width,
    Area
from Remnant;
        "#,
        )
        .await?
        .into_first_result()
        .await?
        .iter()
        .map(|row| {
            Ok((
                row.try_get::<&str, _>("ProgramName")?
                    .map(Into::into)
                    .unwrap(),
                row.try_get::<i32, _>("RepeatID")?.map(Into::into).unwrap(),
                Self::try_from(row)?,
            ))
        })
        .collect()
    }

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
	Length,
    Width,
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
            length: row.try_get("Length")?.unwrap(),
            width: row.try_get("Width")?.unwrap(),
            area: row.try_get("Area")?.unwrap(),
        })
    }
}
