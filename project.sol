// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

contract EtherWithdrawal {

    // to store the owner's address
    address public owner;
    
    // to store the contract balance
    uint public contractBalance;

   /*to store the transaction ,
    "amount" variable to store in that transaction how much amount were transfered.
    "typeTransaction"  variable to store the who sends money like(user transfered money to other account,
                                                                user withdraw the money,
                                                                user receive the money,).
    
    "sender" who sends the money, 
    "receiver" who receive
     sender no needed for fixedDeposit, normalDeposit, but they were need for owner to check the what are 
     the transaction done on the contract*/
    struct Transaction {
        uint amount;
        string typeTransaction;
        address sender;
        address receiver;
        uint time;
    }

     // to sore the borrow 
    struct Borrow{
        // how much amount user borrowed
        uint amount;
        // when user borrowed date
        uint takenDate;
        // the requested tenure
        uint time;
        // when user going to repay it
        uint repaymentDate;
    }

   struct Repay{
        uint amount;
        uint repayDate;
    }

/*---------------------Mapping----------------------------*/

    // it will store the who was repayed and details
    mapping (address => Repay[]) public repaying;

    /*mapping to store the transaction were done in the contract, address variable for the from the which address was done,
    transaction[] variable it is an array because can do more transactions*/
    mapping(address => Transaction[]) public storeTransaction;

     // address will store the who are borrowed the loan
    mapping (address =>Borrow[] ) public Borrowed;

    // for normal Deposit
    mapping(address => uint) public normalDepositBalance;

    // for Fixed Deposit
    mapping(address => uint) public fixedDepositBalance;

    
    /*---------------------MOdifiers----------------------------*/

    // modifier to only owner can do
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // user should accept the Terms and Conditions
    modifier acceptTandC(bool accept){
        require(accept == true,"You need to accept the Terms and Conditions");
        _;
    }

    // before deductiing amount from the contract
    modifier contractbalances(uint amount){
        // contract balance should not equal to zero
        require(contractBalance != 0,"Contract balance is Zero");
        // deduction amount should greater than equal to contract balance
        require(amount <= contractBalance,"Contract has insufficient balance");
        _;
    }

    
    /*---------------------Constructor----------------------------*/

    // when the time of deploying this  contract to the main network should change
    //  the owner address and remove it from the constructor
    // to store the owner address
    constructor() {
        owner = msg.sender;
    }

    /*---------------------Events----------------------------*/
     // for ui to display the log info
    event NormalDeposit(address indexed user,uint amount);
    event FixedDeposit(address indexed user,uint amount);
    event EtherWithdrawn(address indexed user, uint amount);
    event TransferToAccount(uint amount,address sender,address receiver);
    event WithDrawContractBalance(address indexed user,uint amount,uint WithDrawDate);
    event Loantaken(address indexed user, uint amount, uint takenDate,uint tenure, uint repayDate);
    event LoanRepay(address indexed user, uint repayDate);
    event storeTransactionHistory(address indexed user,uint amount,string TransactionType,address sender,address receiver);

    /*---------------------fuctions----------------------------*/

    // function to store the normal deposit
    function normalDeposit() external payable {
         contractBalance += msg.value;
        normalDepositBalance[msg.sender] += msg.value;
        noteTransaction(msg.value, "NormalDeposit", msg.sender, msg.sender);
        emit NormalDeposit(msg.sender,msg.value);
    }

    // function to store the fixed deposit
    function fixedDeposit() external payable {
        contractBalance += msg.value;
        fixedDepositBalance[msg.sender] += msg.value;
        noteTransaction(msg.value, "FixedDeposit", msg.sender, msg.sender);
        emit FixedDeposit(msg.sender,msg.value);
    }

    // for withdrawl
    function withdrawEther(uint amount) external contractbalances(amount){

        // withdrawl amount should greater than 0
        require(amount > 0, "Amount must be greater than zero");

        // user need to contain sufficient balance in their account to withdraw
        require(amount <= normalDepositBalance[msg.sender], "Insufficient balance");

        // to update the user balance
        normalDepositBalance[msg.sender] -= amount;

        // to update the contract balance
        contractBalance -= amount;

        // transfers the amount from contract to user
        payable(msg.sender).transfer(amount);

        // emits the log info
        emit EtherWithdrawn(msg.sender, amount);

        // toStore the transaction
        noteTransaction(amount, "WithDraw", address(this), msg.sender);
    }

    // to withdraw the contract balance, only owner can do it
    function withdrawContractBalance() external onlyOwner {
        require(contractBalance != 0,"Contract balance is Zero");
        uint amountToWithdraw = contractBalance;
        contractBalance = 0;
        payable(owner).transfer(amountToWithdraw);
        noteTransaction(address(this).balance, "With Draw Contract Balance to Owner Account", address(this), msg.sender);
        emit WithDrawContractBalance(owner,address(this).balance,block.timestamp);
    }

    // transfering amount from own account to  any address
    function transferToAccount(uint amount,address receipient) external contractbalances(amount) {
        // amount should greater than user ballance
        require(amount <= normalDepositBalance[msg.sender], "Insufficient balance");
        payable(receipient).transfer(amount);
        contractBalance -= amount;
        normalDepositBalance[msg.sender] -= amount; 
        noteTransaction(amount, "Transfering from user account to other Account", msg.sender, receipient);
        emit TransferToAccount(amount,msg.sender,receipient);
    }

    // user can check the transaction history
    function checkHistory(address add, uint index) public view returns (Transaction memory) {
        require(index < storeTransaction[add].length, "Index out of bounds");
        return storeTransaction[add][index];
    }

    // updating the mapping Borrowed
    function updatingBorrow(uint _amount,uint _takenDate,uint _time,uint _repayDate) internal {
        Borrow memory newBorrow = Borrow(_amount,_takenDate, _time,_repayDate);
        Borrowed[msg.sender].push(newBorrow);
    }

    // the user can take the loan
    function loan(uint amount, uint time, bool accept) external payable acceptTandC(accept) contractbalances(amount){
        normalDepositBalance[msg.sender] += amount;
        uint repayDate = block.timestamp + (24 * 60 * 60 * time);
        uint takenDate = block.timestamp;
        uint tenure = 24 * 60 * 60 * time;
        // transfering the loan amount to user normal deposint account
         normalDepositBalance[msg.sender] += amount;
        // updating the contract balance 
        contractBalance -= amount;
        updatingBorrow(amount, takenDate,tenure,repayDate);
        noteTransaction(amount, "Loan was taken from the contract", address(this),msg.sender);
        emit Loantaken(msg.sender,amount, takenDate,tenure, repayDate);
    }

    // user can repay the loan
    function loanRepayment() external payable {
         contractBalance += msg.value;
         Repay memory Repaying = Repay(msg.value,block.timestamp);
         repaying[msg.sender].push(Repaying);

        noteTransaction(msg.value, "LoanRepayed", msg.sender, address(this));
        emit LoanRepay(msg.sender,block.timestamp);
    }  

    // storing the transactions were done on the contract
    function noteTransaction(uint amount, string memory typeTransaction, address sender, address receiver) internal {
        Transaction memory newTransaction = Transaction({
            amount: amount,
            typeTransaction: typeTransaction,
            sender: sender,
            receiver: receiver,
            time : block.timestamp
        });
         storeTransaction[sender].push(newTransaction);
         emit storeTransactionHistory(msg.sender,amount,typeTransaction,sender,receiver);

    }
}
