use hoil::helpers::{convert_from_int_to_Fixed, convert_from_Fixed_to_int};

use cubit::f128::types::fixed::{Fixed, FixedTrait};
use debug::PrintTrait;

// Computes the portfolio value if it moved from current (fetched from Empiric) to the specific strike
fn compute_portfolio_value(curr_price: Fixed, notional: u128, calls: bool, strike: Fixed) -> Fixed {
    let x = convert_from_int_to_Fixed(notional, 18);
    let y = x * curr_price;
    let k = x * y;
    
    let y_at_strike = k.sqrt() * strike.sqrt();
    let x_at_strike = k.sqrt() / strike.sqrt();
    
    convert_excess(x_at_strike, y_at_strike, x, strike, curr_price, calls)
}

// converts the excess to the hedge result asset (calls -> convert to eth)
// ensures the call asset / put assset (based on calls bool) is equal to notional (or equivalent amount in puts)
// returns amount of asset that isn't fixed
fn convert_excess(
    call_asset: Fixed,
    put_asset: Fixed,
    notional: Fixed,
    strike: Fixed,
    entry_price: Fixed,
    calls: bool
) -> Fixed {
    if calls {
        assert(strike > entry_price, 'strike<=entry price');
        assert(call_asset < notional, 'hedging at odd strikes, warning');
        let extra_put_asset = if ((notional * entry_price) > put_asset) {
            (notional * entry_price) - put_asset
        } else {
            put_asset - (notional * entry_price)
        };
        let res: Fixed = (extra_put_asset / strike) + call_asset;
        res
    } else {
        assert(strike < entry_price, 'strike>=entry price');
        let extra_call_asset = if (call_asset > notional) {
            call_asset - notional
        } else {
            notional - call_asset
        };
        let res: Fixed = (extra_call_asset * strike) + put_asset;
        res
    }
}

#[cfg(test)]
fn test_convert_excess() {
    let x_at_strike = FixedTrait::from_felt(0x10c7ebc96a119c8bd); // 1.0488088481662097
    let y_at_strike = FixedTrait::from_felt(0x6253699028cfb2bd398); // 1573.2132722467607
    let x = FixedTrait::from_felt(0x100000000000000000); // 1
    let strike = FixedTrait::from_felt(0x5dc0000000000000000); // 1500
    let curr_price = FixedTrait::from_felt(0x6720000000000000000); // 1650
    let calls = false;
    let res = convert_excess(x_at_strike, y_at_strike, x, strike, curr_price, calls);
    res.print(); // 0x66e6d320524ee400704 = 1646.426544496075
}


use hoil::helpers::percent;
#[cfg(test)]
fn test_compute_portfolio_value() {
    // k = 1500, initial price 1500.
    // price being considered 1700.
    let ONEETH = 1000000000000000000;
    let res = compute_portfolio_value(
        FixedTrait::from_unscaled_felt(1500), ONEETH, true, FixedTrait::from_unscaled_felt(1700)
    );
    assert(res < FixedTrait::ONE(), 'loss must happen due to IL');
    assert(res > percent(95), 'loss weirdly high');

    // k = 1500, initial price 1500.
    // price being considered 1300.
    let res = compute_portfolio_value(
        FixedTrait::from_unscaled_felt(1500), ONEETH, false, FixedTrait::from_unscaled_felt(1300)
    );
    assert(res < FixedTrait::from_unscaled_felt(1500), 'loss must happen');
    assert(res > FixedTrait::from_unscaled_felt(1492), 'loss too high');

    // repro attempt
    let res = compute_portfolio_value(
        FixedTrait::from_unscaled_felt(1650), ONEETH, true, FixedTrait::from_unscaled_felt(1800)
    );
    assert(res < FixedTrait::ONE(), 'loss must happen due to IL');
    assert(res > percent(97), 'loss weirdly high');
}
