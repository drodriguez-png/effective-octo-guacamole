
use crate::Result;
use axum::{http::StatusCode, Json};
use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Nest {}

impl Nest {
	pub async fn get_feedback() -> Result<(StatusCode, Json<Vec<Self>>)> {
		log::debug!("Requested feedback");

		// TODO: add failure status reasons
		Ok((StatusCode::OK, Json(vec![])))
	}
	async fn get_program_feedback(
		State(state): State<Arc<AppState>>,
	) -> Result<(StatusCode, Json<Vec<Program>>)> {
		log::debug!("Requested programs feedback");

		let state = Arc::clone(&state);
		let feedback = Program::get_feedback(state.db.clone()).await?;

		Ok((StatusCode::OK, Json(feedback)))
	}

	async fn get_part_feedback(
		State(state): State<Arc<AppState>>,
	) -> Result<(StatusCode, Json<Vec<Part>>)> {
		log::debug!("Requested parts feedback");

		let state = Arc::clone(&state);
		let feedback = Part::get_feedback(state.db.clone()).await?;

		Ok((StatusCode::OK, Json(feedback)))
}
}