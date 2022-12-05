## Results:

1. The bug is where the two roles are hardcoded as `"m"` and `"b"`. 
   1. When `"m"` is converted to ASCII the value becomes `109` and for `"b"` it becomes `98`, then the account who has a token balence of `109` can freely mint tokens and the account who has `98` tokens can freely burn tokens. The function `can(Roles.Mint)` will return true for any of these cases.
2. The following exercises
   1. Check for zero and negative numbers as well. 
   2. The normalization part is wrong because division with decimals might give the wrong result.

Code1:

```
@storage_var
func max_supply() -> (res: felt) {
}

@external
func bad_function{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() {
    let (value: felt) = ERC20.total_supply();
    assert_le{range_check_ptr=range_check_ptr}(value, max_supply.read());

    // do something...

    return ();
}
```

Code2:

```
@external
func bad_normalize_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    normalized_balance: felt
) {
    let (user) = get_caller_address();

    let (user_current_balance) = user_balances.read(user);
    let (normalized_balance) = user_current_balance / 10 ** 18;

    return (normalized_balance,);
}
```