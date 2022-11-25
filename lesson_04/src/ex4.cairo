// Return summation of every number below and up to including n
func calculate_sum(n: felt) -> (sum: felt) {
    if (n == 0) {
        // when it's end of the recurssion, return 0. 
        return(sum=0); 
    }

    let (sum) = calculate_sum(n=n - 1);

    let new_sum = sum + n; 
    return (sum=new_sum);
}