
use crate::Result;
use axum::{http::StatusCode, Json};
use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Execution {
	id: u32
}

impl Execution {
	pub async fn program_update(Json(exec): Json<Self>) -> Result<StatusCode> {
		log::debug!("Program update requested with ArchivePackeId: {}", exec.id);

		// TODO: add failure status reasons
		Ok(StatusCode::OK)
	}
}
