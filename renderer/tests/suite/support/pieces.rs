//! The table's pieces as short words a test can compare: `blank`, `label a`,
//! `row 3`, `conflict 3`, `top`, `bottom`, `folded 2`, `4 more below`.

use fun_ci_renderer::table::stack::Piece;

pub fn kind(piece: &Piece) -> String {
    match piece {
        Piece::Blank => "blank".into(),
        Piece::Label(section) => format!("label {}", section.project),
        Piece::Row(run) => format!("row {}", run.id),
        Piece::Conflict(run) => format!("conflict {}", run.id),
        Piece::Edge(top) => (if *top { "top" } else { "bottom" }).into(),
        Piece::Folded(runs) => format!("folded {}", runs.len()),
        Piece::More(count, below) => format!("{count} more {}", if *below { "below" } else { "above" }),
    }
}
