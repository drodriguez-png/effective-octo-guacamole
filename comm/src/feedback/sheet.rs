
use crate::Result;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Sheet {
    pub sheet_name: String,
    pub material_master: String,
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
