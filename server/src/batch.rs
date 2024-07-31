use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Batch {
    pub id: String,
    pub mm: String,
    #[serde(rename(deserialize = "remnant"))]
    pub r#type: BatchType,
}

impl Batch {
    pub fn new(id: &str, mm: &str) -> Self {
        Self {
            id: String::from(id),
            mm: String::from(mm),
            r#type: BatchType::New,
        }
    }

    pub fn remnant(id: &str, mm: &str) -> Self {
        Self {
            id: String::from(id),
            mm: String::from(mm),
            r#type: BatchType::Remnant,
        }
    }

    pub fn get_batches() -> crate::Result<Vec<Self>> {
        csv::Reader::from_path("batches.csv")?
            .into_deserialize::<Batch>()
            .map(|r| r.map_err(crate::Error::from))
            .collect()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum BatchType {
    #[serde(rename(deserialize = "N"))]
    New,
    #[serde(rename(deserialize = "Y"))]
    Remnant,
}
