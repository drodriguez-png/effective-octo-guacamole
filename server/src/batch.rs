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
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum BatchType {
    New,
    Remnant,
}
