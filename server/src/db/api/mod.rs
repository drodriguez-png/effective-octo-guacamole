mod feedback;
mod nest;
mod part;
mod program;
mod remnant;
mod sheet;

pub use feedback::{FeedbackEntry, TransactionType};
pub use nest::Nest;
pub use part::Part;
pub use program::Program;
pub use remnant::Remnant;
pub use sheet::Sheet;

pub fn get<'a, T>(row: &'a tiberius::Row, aliases: &[&str]) -> crate::Result<T>
where
    T: tiberius::FromSql<'a>,
{
    for column in aliases {
        if let Some(value) = row.get::<T, _>(*column) {
            return Ok(value);
        }
    }

    Err(crate::Error::NotFound(format!(
        "SQL column not found for any alias of {:?}",
        aliases
    )))
}
