
use crate::Result;
use axum::{http::StatusCode, Json};
use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Demand {}

impl Demand {
	pub async fn process_sap_events(Json(events): Json<Vec<Self>>) -> Result<StatusCode> {
		log::debug!("{:?}", events);

		// TODO: add failure status reasons
		Ok(StatusCode::OK)
	}
}