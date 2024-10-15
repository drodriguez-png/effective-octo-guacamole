use super::{Part, Program, Remnant, Sheet};
use crate::Result;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TransactionType {
    Created(Nest),
    Deleted,
    Updated,
}

impl TryFrom<&tiberius::Row> for TransactionType {
    type Error = crate::Error;

    fn try_from(row: &tiberius::Row) -> Result<TransactionType> {
        match row.try_get::<&str, _>("TransType")? {
            Some("SN100") => Ok(Self::Created(todo!("create nest from row"))),
            Some("SN101") => Ok(Self::Deleted),
            Some("SN102") => Ok(Self::Updated),
            _ => unreachable!(),
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FeedbackEntry {
    pub archive_packet_id: i32,
    pub state: TransactionType,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Nest {
    pub program: Program,
    pub parts: Vec<Part>,
    pub sheet: Vec<Sheet>,
    pub remnants: Vec<Remnant>,
}

impl Nest {
    pub async fn get_nest(db: crate::db::DbPool) -> Result<Self> {
        todo!()
    }
}
