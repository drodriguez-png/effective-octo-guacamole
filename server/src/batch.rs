use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Batch {
    pub id: String,
    pub mm: String,
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
        Ok(vec![
            Self::new("B000001", "50/50W-0008"),
            Self::new("B005038", "50/50W-0008"),
            Self::new("B000701", "50/50W-0008"),
            Self::new("B010064", "50/50W-0008"),
            Self::new("B008802", "50/50W-0008"),
            Self::new("B000031", "50/50W-0008"),
        ])
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum BatchType {
    New,
    Remnant,
}
