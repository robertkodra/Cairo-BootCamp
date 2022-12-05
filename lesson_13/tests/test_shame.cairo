%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_sub, uint256_eq
from starkware.starknet.common.syscalls import get_caller_address

const MINT_ADMIN = 0x00348f5537be66815eb7de63295fcb5d8b8b2ffe09bb712af4966db7cbb04a91;
const TEST_ACC1 = 0x00348f5537be66815eb7de63295fcb5d8b8b2ffe09bb712af4966db7cbb04a95;
const TEST_ACC2 = 0x3fe90a1958bb8468fb1b62970747d8a00c435ef96cda708ae8de3d07f1bb56b;
from lib.constants import TRUE, FALSE
from src.IERC20 import IERC20 as Erc20


@external
func __setup__() {
    // Deploy contract
    %{
        context.contract_a_address  = deploy_contract("./src/shame_erc20.cairo", [
               6010169650794424686,             ## name:   ShitCoin
               1397246292,                      ## symbol: SHIT
               10000000000,                     ## initial_supply[1]: 10000000000
               0,                               ## initial_supply[0]: 0
               ids.MINT_ADMIN
               ]).contract_address
    %}
    return ();
}

@external
func test_transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local contract_address;
    %{ ids.contract_address = context.contract_a_address %}

    // Call as admin
    %{ stop_prank_callable = start_prank(ids.MINT_ADMIN, ids.contract_address) %}

    // Transfer even amount as mint owner to TEST_ACC1
    Erc20.transfer(contract_address=contract_address, recipient=TEST_ACC1, amount=Uint256(1, 0));
    let (balance: Uint256) = Erc20.balanceOf(contract_address=contract_address, account=TEST_ACC1);
    let (is_eq) = uint256_eq(balance, Uint256(1,0));
    assert is_eq = TRUE;
    %{ stop_prank_callable() %}

   // Call as TEST_ACC1, approve one token to send to TEST_ACC2
    %{ stop_prank_callable_1 = start_prank(ids.TEST_ACC1, ids.contract_address) %}
    Erc20.approve(
        contract_address=contract_address,
        spender=MINT_ADMIN,
        amount=Uint256(1,0),
    );
    %{ stop_prank_callable_1() %}

    // Call as admin (spender of token of TEST_ACC1)
    %{ stop_prank_callable = start_prank(ids.MINT_ADMIN, ids.contract_address) %}
    // Transfer one token from TEST_ACC1 to TEST_ACC2
    Erc20.transferFrom(
        contract_address=contract_address,
        sender=TEST_ACC1,
        recipient=TEST_ACC2,
        amount=Uint256(1,0),
    );

    // Check balance change
    let (balance_1: Uint256) = Erc20.balanceOf(contract_address=contract_address, account=TEST_ACC1);
    let (balance_2: Uint256) = Erc20.balanceOf(contract_address=contract_address, account=TEST_ACC2);

    // TEST_ACC1 should have 0
    let (is_eq) = uint256_eq(balance_1, Uint256(0,0));
    assert is_eq = TRUE;

    // TEST_ACC2 should have 1
    let (is_eq) = uint256_eq(balance_2, Uint256(1,0));
    assert is_eq = TRUE;
    %{ stop_prank_callable() %}

    return ();
}