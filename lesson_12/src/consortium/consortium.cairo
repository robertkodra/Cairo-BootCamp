%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.math import unsigned_div_rem, assert_le_felt, assert_le, assert_nn
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.pow import pow
from starkware.cairo.common.hash_state import hash_init, hash_update
from starkware.cairo.common.bitwise import bitwise_and, bitwise_xor, bitwise_or
from lib.constants import TRUE, FALSE

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
    let (chairperson) = get_caller_address();
    let (consortium_id) = consortium_idx.read();

    consortiums.write(consortium_id, Consortium(chairperson, 0));
    members.write(consortium_id, chairperson, Member(100, TRUE, TRUE));

    tempvar new_consortium_id = consortium_id + 1;
    consortium_idx.write(new_consortium_id);

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
    alloc_locals;
    let (caller) = get_caller_address();

    // check that the caller has the right to make a proposal
    let (member) = members.read(consortium_idx, caller);
    assert TRUE = member.prop;

    let (local proposal_id) = proposals_idx.read(consortium_idx);

    if (title_len - 1 == 0) {
        // create a Proposal struct
        proposals.write(consortium_idx, proposal_id, Proposal(type, 0, 0, deadline, 0));

        // string_idx for title starts from 0
        proposals_title.write(consortium_idx, proposal_id, title_len - 1, [title]);

        if (link_len - 1 == 0) {
            proposals_link.write(consortium_idx, proposal_id, [link], link_len - 1);

            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    if (ans_len == 0) {
        // increment the proposal id of the consortium
        proposals_idx.write(consortium_idx, proposal_id + 1);

        // increment the number of proposal of the consortium
        let (consortium) = consortiums.read(consortium_idx);
        tempvar current_consortium_proposal = consortium.proposal_count;
        consortiums.write(
            consortium_idx, Consortium(consortium.chairperson, current_consortium_proposal + 1)
        );

        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        let (proposal) = proposals.read(consortium_idx, proposal_id);
        tempvar nb_answers = proposal.ans_idx;  // get number of answers for the current proposal - starting from 0

        // write answers of the proposal
        proposals_answers.write(
            consortium_idx, proposal_id, ans_len - 1, Answer(ans[ans_len - 1], 0)
        );

        // increment the number of answersfor this proposal
        proposals.write(
            consortium_idx,
            proposal_id,
            Proposal(proposal.type, proposal.win_idx, nb_answers + 1, proposal.deadline, proposal.over),
        );

        add_proposal(consortium_idx, 0, title, 0, link, ans_len - 1, ans, type, deadline);  // recursive call to add all the answers

        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    return ();
}

@external
func add_member{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, member_addr: felt, prop: felt, ans: felt, votes: felt
) {
    // check that the caller is the chairperson
    let (caller) = get_caller_address();
    let (consortium) = consortiums.read(consortium_idx);
    assert caller = consortium.chairperson;

    // add new member
    members.write(consortium_idx, member_addr, Member(votes, prop, ans));

    return ();
}

@external
func add_answer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, string_len: felt, string: felt*
) {
    alloc_locals;
    if (string_len == 0) {
        return ();
    }

    // check that the caller has the right to make a answer
    let (local caller) = get_caller_address();
    let (member) = members.read(consortium_idx, caller);
    assert TRUE = member.ans;

    let (proposal) = proposals.read(consortium_idx, proposal_idx);  // get Proposal struct thanks to consortium id + proposal id
    tempvar nb_answers = proposal.ans_idx;  // get number of answers for the current proposal - starting from 0

    proposals_answers.write(consortium_idx, proposal_idx, nb_answers, Answer([string], 0));

    // increment the number of answersfor this proposal
    proposals.write(
        consortium_idx,
        proposal_idx,
        Proposal(proposal.type, proposal.win_idx, nb_answers + 1, proposal.deadline, proposal.over),
    );

    add_answer(consortium_idx, proposal_idx, string_len - 1, string + 1);  // recursive call until string_len is 0

    // store that the caller has made a answer's proposal
    answered.write(consortium_idx, proposal_idx, caller, TRUE);

    return ();
}

@external
func vote_answer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, answer_idx: felt
) {
    // check that the caller has at least one vote
    let (caller) = get_caller_address();
    let (member) = members.read(consortium_idx, caller);
    assert_nn(member.votes);

    // check that the caller has not voted yet
    let (state_voted) = voted.read(consortium_idx, proposal_idx, caller);
    assert state_voted = 0;

    // take into account the vote of the caller
    let (answer) = proposals_answers.read(consortium_idx, proposal_idx, answer_idx);
    tempvar current_answer_votes = answer.votes;

    proposals_answers.write(
        consortium_idx,
        proposal_idx,
        answer_idx,
        Answer(answer.text, current_answer_votes + member.votes),
    );

    // add the caller as a voter
    voted.write(consortium_idx, proposal_idx, caller, 1);

    return ();
}

@external
func tally{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt
) -> (win_idx: felt) {
    // check taht the caller is the chairman
    let (caller) = get_caller_address();
    let (consortium) = consortiums.read(consortium_idx);
    assert consortium.chairperson = caller;

    let (proposal) = proposals.read(consortium_idx, proposal_idx);
    tempvar nb_answers = proposal.ans_idx;

    let (winner_idx) = find_highest(consortium_idx, proposal_idx, 0, 0, nb_answers);

    return (winner_idx,);
}

// Internal functions
//#########################################################################################

func find_highest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, highest: felt, idx: felt, countdown: felt
) -> (idx: felt) {
    if (countdown == 0) {
        return (idx=idx);
    }

    let (answer) = proposals_answers.read(consortium_idx, proposal_idx, countdown);

    let is_answer_votes_greater_than_highest = is_le(highest, answer.votes);

    if (is_answer_votes_greater_than_highest == 1) {
        let (res) = find_highest(
            consortium_idx, proposal_idx, answer.votes, countdown, countdown - 1
        );
        return (idx=res);
    }

    let (idx) = find_highest(consortium_idx, proposal_idx, highest, idx, countdown - 1);

    return (idx,);
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
    return ();
}
