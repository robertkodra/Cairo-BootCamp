%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp, storage_write
from starkware.cairo.common.math import unsigned_div_rem, assert_le_felt, assert_le, assert_nn, assert_not_zero
from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.pow import pow
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.hash_state import hash_init, hash_update
from starkware.cairo.common.bitwise import bitwise_and, bitwise_xor, bitwise_or
from lib.constants import TRUE, FALSE

// Constants
//#########################################################################################
const MAX_LEN               = 31; 
const KEY_PROPOSALS_TITLE   = 0x018E41c9c91ea1EaB61438Ab3dcB93EB2dD4f80072dD0e5F0f7B22eaAbd70dAc;
const KEY_PROPOSALS_LINK    = 0x00DE2037e2ECC908B792b5190Ef35147Fc4d43cA5Bca37598550b53C578b692E;
const KEY_PROPOSALS_ANSWERS = 0x04b5B35c8356d83b5e8313084D3aE055432DECa382412F30Cf26085115270f6c;


// Structs
//#########################################################################################

struct Consortium {
    chairperson: felt,
    proposal_count: felt,
}

struct Member {
    votes: felt,
    prop: felt,
    ans: felt,
}

struct Answer {
    text: felt,
    votes: felt,
}

struct Proposal {
    type: felt,  // whether new answers can be added
    win_idx: felt,  // index of preffered option
    ans_idx: felt,
    deadline: felt,
    over: felt,
}

// remove in the final asnwerless
struct Winner {
    highest: felt,
    idx: felt,
}

// Storage
//#########################################################################################

@storage_var
func consortium_idx() -> (idx: felt) {

}

@storage_var
func consortiums(consortium_idx: felt) -> (consortium: Consortium) {
}

@storage_var
func members(consortium_idx: felt, member_addr: felt) -> (memb: Member) {
}

@storage_var
func proposals(consortium_idx: felt, proposal_idx: felt) -> (win_idx: Proposal) {
}

@storage_var
func proposals_idx(consortium_idx: felt) -> (idx: felt) {
}

@storage_var
func proposals_title(consortium_idx: felt, proposal_idx: felt, string_idx: felt) -> (
    substring: felt
) {
}

@storage_var
func proposals_link(consortium_idx: felt, proposal_idx: felt, string_idx: felt) -> (
    substring: felt
) {
}

@storage_var
func proposals_answers(consortium_idx: felt, proposal_idx: felt, answer_idx: felt) -> (
    answers: Answer
) {
}

@storage_var
func voted(consortium_idx: felt, proposal_idx: felt, member_addr: felt) -> (true: felt) {
}

@storage_var
func answered(consortium_idx: felt, proposal_idx: felt, member_addr: felt) -> (true: felt) {
}

// External functions
//#########################################################################################

@external
func create_consortium{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // creator becomes chairperson and member 
    // initialize consortium 

    let (caller: felt) = get_caller_address(); 

    tempvar consortium: Consortium* = new Consortium(chairperson = caller, proposal_count = 0);

    let (consortium_idx_) = consortium_idx.read(); 
    
    consortiums.write(consortium_idx = consortium_idx_, value = [consortium]);

    consortium_idx.write(value=consortium_idx_+1);

    tempvar member: Member* = new Member(votes = 100, prop = 1, ans = 1);
    
    members.write(consortium_idx=consortium_idx_, member_addr=caller, value=[member]);
    return ();
}

@external
func add_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt,
    title_len: felt,
    title: felt*,
    link_len: felt,
    link: felt*,
    ans_len: felt,
    ans: felt*,
    type: felt,
    deadline: felt,
) {
    // only can be done by any member that has right to add proposals 
    alloc_locals;

    // get caller adddress and verify if it has rights
    let (caller : felt) = get_caller_address();
    let (member) = members.read(consortium_idx, caller);

    with_attr error_message("Only members are allowed to propose."){
        assert TRUE = member.prop;
    }

    // add proposal title
    let (local proposal_idx_ : felt) = proposals_idx.read(consortium_idx);

    let proposal: Proposal = Proposal(
        type=type,
        win_idx=0,
        ans_idx=ans_len,
        deadline=deadline,
        over=FALSE,
    );
    
    proposals.write(consortium_idx, proposal_idx_, value = proposal);
    proposals_idx.write(consortium_idx, value=proposal_idx_ + 1);

    // title
    load_selector(
    string_len = title_len,
    string = title,
    slot_idx = 0,
    proposal_idx = proposal_idx_,
    consortium_idx = consortium_idx,
    selector = KEY_PROPOSALS_TITLE,
    offset = MAX_LEN,
    );

    // link

    load_selector(
    string_len = link_len,
    string = link,
    slot_idx = 0,
    proposal_idx = proposal_idx_,
    consortium_idx = consortium_idx,
    selector = KEY_PROPOSALS_LINK,
    offset = MAX_LEN,
    );

    // answers
    load_selector(
    string_len = ans_len,
    string = ans,
    slot_idx = 0,
    proposal_idx = proposal_idx_,
    consortium_idx = consortium_idx,
    selector = KEY_PROPOSALS_ANSWERS,
    offset = 1,
    );

    return ();
}

@external
func add_member{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, member_addr: felt, prop: felt, ans: felt, votes: felt
) {
  
    // get chairperson address and compare to the caller address
    let (consortium) = consortiums.read(consortium_idx); 

    let (caller : felt) = get_caller_address(); 

    with_attr error_message("Only the chairperson is allowed."){
        assert caller = consortium.chairperson;
    }

    // add member
    tempvar member: Member* = new Member(votes = votes, prop = prop, ans = ans);
    
    members.write(consortium_idx=consortium_idx, member_addr=member_addr, value=[member]);
    return ();
}

@external
func add_answer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, string_len: felt, string: felt*
) {
    // only done by permitted member
    alloc_locals;
    let (caller : felt) = get_caller_address();
    let (member) = members.read(consortium_idx, caller);

    with_attr error_message("Only members are allowed to answer."){
        assert TRUE = member.ans;
    }

    // proposal has to allow additions

    let (proposal) = proposals.read(consortium_idx, proposal_idx);

    with_attr error_message("The proposal doesn't allow ansers."){
        assert TRUE = proposal.type;
    }


    // one member can add only one answer
    let (local member_answered : felt) = answered.read(consortium_idx, proposal_idx, caller);

    with_attr error_message("Member already answered."){
        assert FALSE = member_answered;
    }
 
    // answers
    load_selector(
    string_len = string_len,
    string = string,
    slot_idx = proposal.ans_idx,
    proposal_idx = proposal_idx,
    consortium_idx = consortium_idx,
    selector = KEY_PROPOSALS_ANSWERS,
    offset = 1,
    );

    answered.write(consortium_idx, proposal_idx, caller, 1);

    // Update proposal record
    tempvar new_proposal: Proposal* = new Proposal(
        type=proposal.type,
        win_idx=proposal.win_idx,
        ans_idx=proposal.ans_idx+1,
        deadline=proposal.deadline,
        over=proposal.over,
    );
    proposals.write(
        consortium_idx=consortium_idx,
        proposal_idx=proposal_idx,
        value=[new_proposal],
    );


    return ();
}

@external
func vote_answer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, answer_idx: felt
) {
    // only can be done by the member with at least 1 vote who didn't voted on the proposal yet
    
    let (caller : felt) = get_caller_address();
    let (member) = members.read(consortium_idx, caller);


    // check if they have votes
    with_attr error_message("Not enough votes."){
        assert_le(1, member.votes);
    }

    let (member_voted) = voted.read(consortium_idx, proposal_idx, caller);

    // check if voted
    with_attr error_message("Already voted.") {
        assert FALSE = member_voted;
    }

    // get answer votes
    let (current_answer) = proposals_answers.read(consortium_idx, proposal_idx, answer_idx);

    // update answer with user vote
    tempvar update_answer : Answer* = new Answer(text = current_answer.text, votes = current_answer.votes + member.votes);
    proposals_answers.write(consortium_idx, proposal_idx, answer_idx, value=[update_answer]);


    // register the caller that it voted
    voted.write(consortium_idx, proposal_idx, caller, 1);

    // reduce votes to the member 
    tempvar update_member : Member* = new Member(votes = member.votes - 1, prop = member.prop, ans = member.votes);
    members.write(consortium_idx, caller, value=[update_member]);

    return ();
}

@external
func tally{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt
) -> (win_idx: felt) {
    // only done by chairman, anytime or by anyone provided vote deadline has expired. 
    // index of the answer with the highest amount of votes is return as the winner 
    let (proposal: Proposal) = proposals.read(
        consortium_idx=consortium_idx,
        proposal_idx=proposal_idx
    );

    // If before deadline, only Chairperson can call this
    let (caller: felt) = get_caller_address();
    let (consortium: Consortium) = consortiums.read(consortium_idx=consortium_idx);
    let (current_timesamp: felt) = get_block_timestamp();
    let is_before_deadline: felt = is_le(current_timesamp, proposal.deadline);

    if (is_before_deadline == TRUE) {
        with_attr error_message("Only Chairperson can tally before deadline has passed") {
            assert caller = consortium.chairperson;
        }
    }

    let (winner_idx: felt) = find_highest(
        consortium_idx=consortium_idx,
        proposal_idx=proposal_idx,
        highest=0,
        idx=0,
        countdown=proposal.ans_idx,
    );
    return (winner_idx,);
}


// Internal functions
//#########################################################################################


func find_highest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, highest: felt, idx: felt, countdown: felt
) -> (idx: felt) {

    // return the index of the answer with the highest amount of votes
    if (countdown == 0) {
        return (highest,);
    }

    // Compare the votes of the two Answers by index
    let (answer_1: Answer) = proposals_answers.read(
        consortium_idx=consortium_idx,
        proposal_idx=proposal_idx,
        answer_idx=highest,
    );

    let (answer_2: Answer) = proposals_answers.read(
        consortium_idx=consortium_idx,
        proposal_idx=proposal_idx,
        answer_idx=idx,
    );

    // If votes for answer_1 is less than answer_2, highest = current idx
    let is_1_le_2: felt = is_le(answer_1.votes, answer_2.votes);
    if (is_1_le_2 == TRUE) {
        tempvar highest = idx;
    } else {
        tempvar highest = highest;
    }

    return find_highest(
        consortium_idx=consortium_idx,
        proposal_idx=proposal_idx,
        highest=highest,
        idx=idx+1,
        countdown=countdown-1,
    );    
}

// Loads it based on length, internall calls only
func load_selector{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    string_len: felt,
    string: felt*,
    slot_idx: felt,
    proposal_idx: felt,
    consortium_idx: felt,
    selector: felt,
    offset: felt,
) {
    let (q : felt, r: felt) = unsigned_div_rem(string_len, offset);
    let r_nn: felt = is_not_zero(r);

    if (q == 0 and r == 0) {
        return (); 
    }

    let (hash_1: felt) = hash2{hash_ptr=pedersen_ptr}(selector, consortium_idx);
    let (hash_2: felt) = hash2{hash_ptr=pedersen_ptr}(hash_1, proposal_idx);
    let (key: felt) = hash2{hash_ptr=pedersen_ptr}(hash_2, slot_idx);

    storage_write(
        address=key,
        value=[string]
    );

    if (r_nn == TRUE) {
        tempvar offset = r;
    } else {
        tempvar offset = offset; 
    }
    
    load_selector(
        string_len = string_len-offset,
        string = string+offset,
        slot_idx = slot_idx+1,
        proposal_idx = proposal_idx,
        consortium_idx = consortium_idx,
        selector = selector,
        offset = offset
        );

    return ();
}