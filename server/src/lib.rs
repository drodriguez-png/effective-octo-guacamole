pub mod db;

pub mod error {
    use axum::{
        http::StatusCode,
        response::{IntoResponse, Response},
    };

    // Error handling: see
    //  https://docs.rs/axum/latest/axum/error_handling/index.html
    //  https://github.com/tokio-rs/axum/blob/main/examples/anyhow-error-response/src/main.rs
    #[derive(Debug, thiserror::Error)]
    pub enum Error {
        #[error("Database error: see server logs.")]
        SqlError(#[from] tiberius::error::Error),
        #[error("Database pool error: see server logs.")]
        SqlPoolError,
        #[error("Requested resource not found")]
        NotFound(String),
    }

    // Tell axum how to convert `AppError` into a response.
    impl IntoResponse for Error {
        fn into_response(self) -> Response {
            // let error = match self {
            //     Self::SqlError(e) => e.to_string(),
            //     Self::SqlPoolError => todo!(),
            //     Self::NotFound(s) => s,
            // };

            (StatusCode::INTERNAL_SERVER_ERROR, self.to_string()).into_response()
        }
    }

    // impl From<SqlError> for Error {
    //     fn from(value: SqlError) -> Self {
    //         log::error!("Casting tiberius error to app error: {:#?}", value);
    //         Self::SqlError
    //     }
    // }

    impl<T: std::fmt::Debug> From<bb8::RunError<T>> for Error {
        fn from(value: bb8::RunError<T>) -> Self {
            log::error!("Casting bb8 error to app error: {:#?}", value);
            Self::SqlPoolError
        }
    }
}

pub use error::Error;
pub type Result<T> = std::result::Result<T, Error>;
