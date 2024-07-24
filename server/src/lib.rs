pub mod db;

pub mod error {
    use axum::{
        http::StatusCode,
        response::{IntoResponse, Response},
    };
    use tiberius::error::Error as SqlError;

    // Error handling: see
    //  https://docs.rs/axum/latest/axum/error_handling/index.html
    //  https://github.com/tokio-rs/axum/blob/main/examples/anyhow-error-response/src/main.rs
    #[derive(Debug)]
    pub enum Error {
        SqlError,
        NotFound(String),
    }

    // Tell axum how to convert `AppError` into a response.
    impl IntoResponse for Error {
        fn into_response(self) -> Response {
            let error = match self {
                Self::SqlError => String::from("Database error: see server logs."),
                Self::NotFound(s) => s,
            };

            (StatusCode::INTERNAL_SERVER_ERROR, error).into_response()
        }
    }

    impl From<SqlError> for Error {
        fn from(value: SqlError) -> Self {
            log::error!("Casting tiberius error to app error: {:#?}", value);
            Self::SqlError
        }
    }

    impl<T: std::fmt::Debug> From<bb8::RunError<T>> for Error {
        fn from(value: bb8::RunError<T>) -> Self {
            log::error!("Casting tiberius error to app error: {:#?}", value);
            Self::SqlError
        }
    }
}

pub use error::Error;
pub type Result<T> = std::result::Result<T, Error>;
