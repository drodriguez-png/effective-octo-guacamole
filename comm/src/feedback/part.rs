use serde::{Deserialize, Serialize};

use super::{Sheet, TransactionType};
use crate::{db::DbPool, Result};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Part {
    pub id: i32,
    pub archive_packet_id: i32,
    pub part_name: String,
    pub part_qty: i32,
    pub job: String,
    pub shipment: i32,
    pub true_area: f64,
    pub nested_area: f64,
    #[serde(flatten)]
    pub sheet: Sheet,
}

impl Part {
    /// get in process parts from feedback and Part table
    pub async fn get_feedback(pool: DbPool) -> Result<Vec<Self>> {
        pool.get()
            .await?
            .simple_query(
                r#"
SELECT
    AutoID,
    ArchivePacketID,
    STPIPArc.PartName,
    QtyInProcess AS Qty,
    Data1 AS Job,
    CAST(Data2 AS INT) AS Shipment,
    TrueArea,
    NestedArea,
    Stock.SheetName,
    Stock.PrimeCode AS MaterialMaster
FROM STPIPArc
INNER JOIN Part
    ON Part.PartName=STPIPArc.PartName
    AND Part.WONumber=STPIPArc.WONumber
INNER JOIN Stock
    ON STPIPArc.SheetName=Stock.SheetName
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

impl TryFrom<&tiberius::Row> for Part {
    type Error = crate::Error;

    fn try_from(row: &tiberius::Row) -> Result<Self> {
        Ok(Self {
            id: row.try_get("AutoID")?.unwrap(),
            archive_packet_id: row.try_get("ArchivePacketID")?.unwrap(),
            part_name: row
                .try_get::<&str, _>("PartName")?
                .map(Into::into)
                .unwrap_or_default(),
            part_qty: row.try_get("Qty")?.unwrap(),
            job: row
                .try_get::<&str, _>("Job")?
                .map(Into::into)
                .unwrap_or_default(),
            shipment: row.try_get("Shipment")?.unwrap_or_default(),
            true_area: row.try_get("TrueArea")?.unwrap(),
            nested_area: row.try_get("NestedArea")?.unwrap(),
            sheet: Sheet::try_from(row)?,
        })
    }
}
