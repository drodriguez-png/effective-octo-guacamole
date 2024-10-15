use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};

use comm::db;
use comm::feedback::{Part, Program};
use comm::Result;
use comm::interfaces;

use std::sync::Arc;

#[derive(Debug)]
pub struct AppState {
    pub db: db::DbPool,
}

impl AppState {
    pub async fn new() -> Self {
        Self {
            db: db::build_db_pool().await,
        }
    }
}

#[tokio::main]
async fn main() -> std::io::Result<()> {
    fern::Dispatch::new()
        .format(|out, message, record| {
            out.finish(format_args!(
                "[{} {} {}] {}",
                humantime::format_rfc3339_seconds(std::time::SystemTime::now()),
                record.level(),
                record.target(),
                message
            ))
        })
        .level(log::LevelFilter::Error)
        .level_for("comm", log::LevelFilter::Trace)
        .chain(
            fern::Dispatch::new()
                .level(log::LevelFilter::Debug)
                .chain(std::io::stdout())
        )
        .chain(
            fern::Dispatch::new().level(log::LevelFilter::Trace).chain(
                std::fs::OpenOptions::new()
                    .create(true)
                    .truncate(true)
                    .write(true)
                    .open("server.log")?,
            )
        )
        .apply()
        .expect("failed to init logging");

    let state = Arc::new(AppState::new().await);
    let app = Router::new()
        .route("/", get(|| async { "root request not implemented yet" }))
        .route("/demand", post(interfaces::Demand::process_sap_events))
        .route("/execution", post(interfaces::Execution::program_update))
        .route("/inventory", post(interfaces::Inventory::process_sap_events))
        .route("/feedback", get(interfaces::Nest::get_feedback))
        .with_state(state);

    // run our app with hyper, listening globally on port 3000
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    axum::serve(listener, app).await
}

