//! The block breathes (design.md, The console): deep wine when its row needs
//! you, deep indigo when the cursor only rests there, lightening and easing
//! once every four seconds, in a few shades a terminal redraws only
//! when the shade changes.

use fun_ci_renderer::table::{night, paper};

/// The block's colour through one breath, a hundredth of a second apart.
fn a_breath() -> Vec<[u8; 3]> {
    (0..400).map(|hundredth| paper(hundredth * 10, true)).collect()
}

#[test]
fn the_block_starts_its_breath_deep_wine() {
    assert_eq!(paper(0, true), night::WINE);
}

#[test]
fn the_block_is_lightest_halfway_through_its_breath() {
    assert_eq!(paper(2_000, true), night::WINE_BREATH);
}

#[test]
fn the_block_breathes_in_five_shades() {
    let mut shades = a_breath();
    shades.sort_unstable();
    shades.dedup();

    assert_eq!(shades.len(), 5);
}

#[test]
fn the_block_is_back_to_deep_wine_after_four_seconds() {
    assert_eq!(paper(4_000, true), night::WINE);
}

#[test]
fn the_block_of_a_row_that_does_not_need_you_is_deep_indigo() {
    assert_eq!(paper(0, false), night::INDIGO);
}

#[test]
fn the_indigo_block_breathes_up_to_its_own_lighter_shade() {
    assert_eq!(paper(2_000, false), night::INDIGO_BREATH);
}
