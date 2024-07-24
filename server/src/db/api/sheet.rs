use std::collections::HashMap;

use crate::{db::SqlConn, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Sheet {
    pub sheet_name: String,
    pub material_master: String,
}

impl Sheet {
    /// get in process sheets
    pub async fn get_ip_sheets(conn: &mut SqlConn<'_>) -> Result<HashMap<String, Self>> {
        conn.simple_query(
            r#"
select
	ProgramName,
	Stock.SheetName,
	PrimeCode as MaterialMaster
from Stock
inner join STPrgArc on STPrgArc.SheetName=Stock.SheetName
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
                Self::try_from(row)?,
            ))
        })
        .collect()
    }
}

impl TryFrom<&tiberius::Row> for Sheet {
    type Error = crate::Error;

    fn try_from(row: &tiberius::Row) -> Result<Self> {
        Ok(Self {
            sheet_name: row
                .try_get::<&str, _>("SheetName")?
                .map(Into::into)
                .unwrap_or_default(),
            material_master: row
                .try_get::<&str, _>("MaterialMaster")?
                .map(Into::into)
                .unwrap_or_default(),
        })
    }
}
