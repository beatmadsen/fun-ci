//! Terminal output, shared by what draws the header and what draws the table:
//! the colours the terminal has, and the backend that writes a frame's cells
//! as the bytes a terminal reads.

pub mod backend;
pub mod depth;
