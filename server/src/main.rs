use std::sync::Arc;

use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::Json,
    routing::get,
    Router,
};
use serde_json::{json, Value};

use sigmanest_interface::db;

#[derive(Debug, serde::Deserialize)]
struct QueryParams {
    program: Option<String>,
    machine: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
struct PostParams {
    program: String,
    batch: String,
}

#[derive(Debug)]
struct AppState {
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
async fn main() -> Result<(), std::io::Error> {
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
        .level_for("sigmanest_interface", log::LevelFilter::Trace)
        .chain(std::io::stdout())
        .chain(std::fs::OpenOptions::new()
            .create(true)
            .truncate(true)
            .write(true)
            .open("server.log")?)
        .apply()
        .expect("failed to init logging");

    let state = Arc::new(AppState::new().await);

    // build our application with a single route
    let app = Router::new()
        .route("/", get(|| async { "root request not implemented yet" }))
        .route("/machines", get(get_machines))
        .route("/programs", get(get_programs)) // TODO: combine this with /program
        .route("/program", get(get_program).post(update_program))
        .with_state(state);

    // run our app with hyper, listening globally on port 3080
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3080").await?;
    axum::serve(listener, app).await
}

async fn get_machines(State(state): State<Arc<AppState>>) -> (StatusCode, Json<Value>) {
    log::debug!("Requested machines list");

    let state = Arc::clone(&state);

    let mut conn = state.db.get_owned().await.unwrap();
    let results = conn
        .simple_query("select distinct MachineName from ProgramMachine")
        .await;
    match results {
        Ok(stream) => match stream.into_first_result().await {
            Ok(rows) => {
                let machines: Vec<String> = rows
                    .iter()
                    .map(|row| row.get::<&str, _>(0))
                    .map(|val| String::from(val.unwrap_or("")))
                    .collect();

                (StatusCode::OK, Json(json!({ "machines": machines })))
            }
            Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(Value::Null)),
        },
        Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(Value::Null)),
    }
}

async fn get_programs(
    State(state): State<Arc<AppState>>,
    params: Query<QueryParams>,
) -> (StatusCode, Json<Value>) {
    log::debug!("Requested programs for machine {:?}", params);

    match &params.machine {
        Some(machine) => {
            let state = Arc::clone(&state);

            let mut conn = state.db.get_owned().await.unwrap();
            let results = conn
                .query(
                    "select distinct ProgramName from ProgramMachine where MachineName=@P1",
                    &[machine],
                )
                .await;
            match results {
                Ok(stream) => match stream.into_first_result().await {
                    Ok(rows) => {
                        let programs: Vec<String> = rows
                            .iter()
                            .map(|row| row.get::<&str, _>(0))
                            .map(|val| String::from(val.unwrap_or("")))
                            .collect();

                        (StatusCode::OK, Json(json!({ "programs": programs })))
                    }
                    Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(Value::Null)),
                },
                Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(Value::Null)),
            }
        }
        None => (StatusCode::BAD_REQUEST, Json(Value::Null)),
    }
}

async fn get_program(
    State(_state): State<Arc<AppState>>,
    params: Query<QueryParams>,
) -> (StatusCode, Json<Value>) {
    log::debug!("Requested batches for {:?}", params);

    match &params.program {
        Some(program) if program.chars().nth(1) == Some('2') => (StatusCode::OK, Json(json!({ "name": program, "batches": vec![9], "remnant": Value::Null }))),
        Some(program) if program.chars().nth(1) == Some('3') => (StatusCode::OK, Json(json!({ "name": program, "batches": vec![4,5,6], "remnant": Value::Null }))),
        Some(program) => (StatusCode::OK, Json(json!({ "name": program, "batches": vec![1,2,3], "remnant": Some(json!({ "width": 43.2, "length": 120})) }))),
        None => (StatusCode::BAD_REQUEST, Json(Value::Null)),
    }
}

async fn update_program(
    State(_state): State<Arc<AppState>>,
    params: Json<PostParams>,
) -> (StatusCode, Json<Value>) {
    log::debug!(
        "Requested update for {}<{}>",
        params.0.program,
        params.0.batch
    );

    // TODO: post update to SimTrans

    (StatusCode::CREATED, Json(Value::Null))
}
