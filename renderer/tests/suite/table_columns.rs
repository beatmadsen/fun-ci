//! Where a row's parts sit: the name, then the marks, the words and the age
//! just after the longest name, so each row reads as one phrase; on a narrow
//! screen the air goes before the names are cut, and the words never are.

use fun_ci_renderer::table::columns::Columns;

#[test]
fn the_marks_start_four_columns_after_the_longest_name() {
    let columns = Columns::fit(120, 17, 21);

    assert_eq!(columns.strip, columns.branch + 17 + 4);
}

#[test]
fn a_name_longer_than_thirty_columns_is_cut_to_thirty() {
    assert_eq!(Columns::fit(200, 55, 21).name, 30);
}

#[test]
fn the_age_ends_three_columns_and_four_more_after_the_longest_words() {
    let columns = Columns::fit(120, 17, 21);

    assert_eq!(columns.age_end, columns.words + 21 + 3 + 4);
}

#[test]
fn the_margin_is_a_twelfth_of_the_width() {
    assert_eq!(Columns::fit(120, 17, 21).margin, 10);
}

#[test]
fn a_label_sits_two_columns_in_and_a_name_four() {
    let columns = Columns::fit(120, 17, 21);

    assert_eq!([columns.label, columns.branch], [12, 14]);
}

#[test]
fn a_screen_too_narrow_for_the_whole_name_cuts_it_while_it_keeps_twelve_columns() {
    let columns = Columns::fit(80, 17, 26);

    assert_eq!([columns.name, columns.gap], [16, 4]);
}

#[test]
fn a_screen_too_narrow_to_leave_a_name_twelve_columns_closes_the_gaps_first() {
    assert_eq!(Columns::fit(70, 17, 26).gap, 2);
}

#[test]
fn nothing_ends_past_the_right_margin_at_sixty_columns() {
    let columns = Columns::fit(60, 40, 26);

    assert!(columns.age_end + columns.margin <= 60, "{columns:?}");
}
