use super::{Nest, Program};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[repr(u8)]
pub enum TransactionType<T> {
    NotFound,
    Created(T),
    Deleted,
    Updated,
}

impl<T> TransactionType<T> {
    pub fn unwrap(self) -> T {
        match self {
            TransactionType::Created(value) => value,
            _ => panic!("Unwrap called on a TransactionType marker variant"),
        }
    }

    pub fn tcode(&self) -> &str {
        match self {
            TransactionType::NotFound => panic!("NotFound has not TCode"),
            TransactionType::Created(_) => "SN100",
            TransactionType::Deleted => "SN101",
            TransactionType::Updated => "SN102",
        }
    }
}

impl<'a, T> TryFrom<&'a tiberius::Row> for TransactionType<T>
where
    T: TryFrom<&'a tiberius::Row>,
    crate::Error: From<<T as TryFrom<&'a tiberius::Row>>::Error>,
{
    type Error = crate::Error;

    fn try_from(row: &'a tiberius::Row) -> crate::Result<TransactionType<T>> {
        match row.try_get::<&str, _>("TransType")? {
            Some("SN100") => Ok(Self::Created(T::try_from(&row)?)),
            Some("SN101") => Ok(Self::Deleted),
            Some("SN102") => Ok(Self::Updated),
            _ => unreachable!(),
        }
    }
}

impl<T, O> PartialEq<TransactionType<O>> for TransactionType<T> {
    fn eq(&self, other: &TransactionType<O>) -> bool {
        let left = unsafe { *<*const _>::from(self).cast::<u8>() };
        let right = unsafe { *<*const _>::from(other).cast::<u8>() };

        left == right
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FeedbackEntry<T> {
    pub archive_packet_id: i32,
    pub state: TransactionType<T>,
}

impl<'a, T> TryFrom<&'a tiberius::Row> for FeedbackEntry<T>
where
    T: TryFrom<&'a tiberius::Row>,
    crate::Error: From<<T as TryFrom<&'a tiberius::Row>>::Error>,
{
    type Error = crate::Error;

    fn try_from(row: &'a tiberius::Row) -> crate::Result<FeedbackEntry<T>> {
        Ok(Self {
            archive_packet_id: row.try_get("ArchivePacketID")?.unwrap(),
            state: TransactionType::try_from(row)?,
        })
    }
}

impl From<FeedbackEntry<Program>> for FeedbackEntry<Nest> {
    fn from(value: FeedbackEntry<Program>) -> FeedbackEntry<Nest> {
        let state = match value.state {
            TransactionType::Created(_) => {
                panic!("cannot implicity convert TransactionType with data");
            }
            TransactionType::NotFound => TransactionType::NotFound,
            TransactionType::Deleted => TransactionType::Deleted,
            TransactionType::Updated => TransactionType::Updated,
        };

        FeedbackEntry {
            archive_packet_id: value.archive_packet_id,
            state,
        }
    }
}

impl<T, O> PartialEq<FeedbackEntry<O>> for FeedbackEntry<T> {
    fn eq(&self, other: &FeedbackEntry<O>) -> bool {
        self.archive_packet_id == other.archive_packet_id && self.state == other.state
    }
}
