
mod demand;
mod execution;
mod inventory;
mod nest;

pub use demand::Demand;
pub use execution::Execution;
pub use inventory::Inventory;
pub use nest::Nest;

#[derive(Debug)]
pub enum Status<T> {
	Same,
	Add(T),
	Delete,
	Change(T),
}

pub trait SapSigmanestDiff {
	type Change;

    fn diff(&self, other: &Self) -> Status<Self::Change>;
}
