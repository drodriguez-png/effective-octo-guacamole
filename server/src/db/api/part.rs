use serde::{Deserialize, Serialize};

use super::FeedbackEntry;
use crate::{db::SqlConn, Result};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Part {
    pub part_name: String,
    pub part_qty: i32,
    pub job: String,
    pub shipment: i32,
    pub true_area: f64,
    pub nested_area: f64,
}

impl Part {
    /// get in process parts from feedback
    pub async fn get_ip_feedback(conn: &mut SqlConn<'_>) -> Result<Vec<FeedbackEntry<Self>>> {
        conn.simple_query(
            r#"
select
	ArchivePacketID,
    TransType,
	STPIPArc.PartName,
    QtyInProcess as Qty,
    Data1 as Job,
    cast(Data2 as int) as Shipment,
	TrueArea,
    NestedArea
from STPIPArc
inner join Part on Part.PartName=STPIPArc.PartName and Part.WONumber=STPIPArc.WONumber;
        "#,
        )
        .await?
        .into_first_result()
        .await?
        .iter()
        .map(FeedbackEntry::try_from)
        .collect()
    }

    /// get in process part from feedback
    pub async fn get_ip_feedback_by_program(
        conn: &mut SqlConn<'_>,
        id: i32,
        tcode: String,
        // program: &FeedbackEntry<Program>,
    ) -> Result<Vec<Self>> {
        conn.query(
            r#"
select
	STPIPArc.PartName,
    QtyInProcess as Qty,
    Data1 as Job,
    cast(Data2 as int) as Shipment,
	TrueArea,
    NestedArea
from STPIPArc
inner join Part on Part.PartName=STPIPArc.PartName and Part.WONumber=STPIPArc.WONumber
where ArchivePacketID=@P1 and TransType=@P2;
        "#,
            &[&id, &tcode],
        )
        .await?
        .into_first_result()
        .await?
        .iter()
        .map(Self::try_from)
        .collect()
    }

    /// get updated parts from feedback
    pub async fn get_complete_feedback(conn: &mut SqlConn<'_>) -> Result<Vec<Self>> {
        conn.simple_query(
            r#"
select
	ArchivePacketID,
	PartName,
    QtyProgram as Qty,
    Data1 as Job,
    cast(Data2 as int) as Shipment,
	TrueArea,
    NestedArea
from STPrtArc;
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
        })
    }
}
