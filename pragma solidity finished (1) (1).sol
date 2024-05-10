pragma solidity >=0.5.0 < 0.9.0;
//SPDX-License-Identifier: GPL-3.0+
import "hardhat/console.sol";

/* set up the attributes of Transaction (id, initiator of transaction, hehavior[deposit, withdrawal...], trading amount)
*/
struct Transaction{
    uint tranIndex;
    address accountOwner;
    string behavior;
    uint amount;
}
/* set up the attributes of personal account in the commercial bank(id, owner, balance)
*/
struct SavingAccount{
    uint accountID;
    address accountOwner;
    uint accountBalance; 
}
/* construct a entity of commercial bank with attributes and functions
*/
contract CommercialBank{
    // owner/boss of commercial bank
    address public BankOwner;
    // the central bank's address and complete entity (that the commercial bank belongs to)
    address payable public RTGSBank; // the bank with payable address can accept transfers from others
    RTGS public central; 
    // a book to store all transaction records
    Transaction[] public bankLedger;
    // a book to store all accounts that open in this commercial bank
    SavingAccount[] public accountList;
    // the information of deposit / withdrawal / leger / transfer behaviors that will triggered in the console by "emit" 
    event depositLog(address ownerAddress, uint amountDeposited);
    event withdrawLog(address ownerAddress, uint amountWithdrawed);
    event legerLog(Transaction[]);
    event transferLog(address userAdd, address recBank, uint amount);

    // initial a commercial bank that can accept transfer from others
    constructor() payable{
        // "msg.value" means the input value in the VALUE box in remix "DEPLOY & RUN TRANSACTIONS"
        // check if the amount of ether/wei in the account is enough to open a commercial bank
        // the second argument in require() is the output if the condition is false
        require(msg.value >= 0.1 ether, "Need at least 0.1 eth to open a commercial bank!");
        // set the owner of commercial bank to be the account's address from where the function call came from.
        BankOwner = msg.sender;
    }

    // trigger the function to receive the value(Ether) when a contract receive the value but no empty calld data(msg.data)
    receive() external payable {}
    
    // trigger the function for contract to receive data when no function matched the function called(not even the receive function)
    fallback() external payable {}

    /* A function that opens the account in commercial bank for account opening person
    */
    function openAccount() public{
        // check if the account opening person is the owner of commerical bank
        // if yes, then break off the function and undo all actions before
        require(BankOwner != msg.sender, "This is your bank.");
        // a commercial bank can only accept 10 account opening persons
        if(accountList.length == 10){
            // break off the function and undo all actions before
            // output the error message
            revert("Each bank can not have more than 10 accounts");
        }
        // check if the account opening person has been opened account before
        for(uint i = 0; i < accountList.length; i++){
            require(msg.sender != accountList[i].accountOwner, "You already have an account.");
        }
        // "memory" in Solidity is a temporary place to store data 
        // whereas "storage" holds data between function calls
        // create a new account and save in the account book
        SavingAccount memory user1 = SavingAccount(accountList.length+1, msg.sender, 0);
        accountList.push(user1);
    }

    /*  A function that checks the current balance of the account hold by the person who calls function
        The function only returns the current balance of the account when it's the account owner who request the balance.
    */
    function CheckBalance() public view returns(uint){ // "view" means the function name and return(return type: uint) will show in the left side
        // checking if the account owner who calls function(request the balance) exists in the account book
        // if yes, then return the balance of account
        for(uint i = 0; i < accountList.length; i++){
            if(accountList[i].accountOwner == msg.sender){
                return accountList[i].accountBalance;
            } 
        }

        // throw error if user does not have an account  
        revert ("You do not have an account in this bank!");
    }

    /*  A function that checks the current balance of the given account (user)
        The function only returns the current balance of the account when the account owner is the given user
    */
    function BankOwnerCheckBalance(address user) public returns(uint) {
        //checking identity
        for(uint i= 0; i < accountList.length; i++){
            if(accountList[i].accountOwner == user ){
                return accountList[i].accountBalance;
            } 
        }
    }

    /* A function that allows the account owner to deposit money.
        Require the user to input the deposit amount in the VALUE box in remix "DEPLOY & RUN TRANSACTIONS" before clicking this deposit function.
        An event log will be provided in the console about "who deposit" "how much deposit" everytime that this function is called
    */
    function Deposit() public payable returns(bool){ // As long as there is cash in circulation in the function, "payable" should be added here
        for(uint i= 0; i < accountList.length; i++){
            // check if the account of user who calls function is in the bank
            // if yes, current account balance of the user will be updated by adding the input value and return true
            // Otherwise it throws an error.
            if(accountList[i].accountOwner == msg.sender){

                // event log on who deposit and how much is triggered by "emit"
                emit depositLog(msg.sender,  msg.value);

                // update account balance
                // account owner actually does not have a wallet in the bank, just a number(balance)
                // the actual holder of money is the bank
                // so there is no real transfer action here
                accountList[i].accountBalance = msg.value + accountList[i].accountBalance;

                // add this transaction to bank ledger
                Transaction memory mm = Transaction(bankLedger.length+1, accountList[i].accountOwner, "Deposit", msg.value); 
                bankLedger.push(mm);
                return true;
            }
        }   

        //throw error if user is not the owner of the account / the account of user who call functions is not in this bank
        revert ("You cannot transfer as you might not be the owner of the account or you do not have an account in this bank!");
        
    }

    /*  A function that only allows owner of the account to withdraw money.
    */
    function Withdraw(uint256 withdrawValue) public payable returns(bool){
        // check if the account of user who calls function is in the bank
        for(uint i= 0; i < accountList.length; i++){
            if(accountList[i].accountOwner == msg.sender){
                // check if the current balance is enough to withdraw the specific amount 
                // If both conditions are satisfied, update current account balance by substracting the withdraw value and gas fee, and then return "true"
                // Otherwise it throws an error.
                require(withdrawValue < accountList[i].accountBalance,"Insufficient fund!");

                // emit Audit Log for withdraw
                emit withdrawLog(msg.sender, withdrawValue);

                // tranfer the withdrawn money to the personal wallet(account address of the owner)
                // how to use transfer(): reciever.transfer(amount)
                payable(accountList[i].accountOwner).transfer(withdrawValue);

                accountList[i].accountBalance =  accountList[i].accountBalance - withdrawValue - tx.gasprice;

                // add this transaction to bank ledger
                Transaction memory mm = Transaction(bankLedger.length+1, accountList[i].accountOwner,  "Withdraw", withdrawValue); 
                bankLedger.push(mm);
                return true;
            }
        } 

        //throw error if user is not the owner of the account / the account of user who call functions is not in this bank
        revert ("You cannot transfer since you are not the owner of the account!");
    }

    /* A function for bank owner to display ledger of bank.
    */
    function checkBankLedger() public{
        // check if the user who calls function is the commercial bank owner
        require(BankOwner == msg.sender, "Only bank owner can view bank ledger!");
        // display all transaction records in the console
        emit legerLog(bankLedger); // how to make the log more readable?
    }

    /* the function is to close the commercial bank
    */
    function closeBank() payable public{
        // check if the user who calls function is the commercial bank owner
        require(BankOwner == msg.sender, "Only the bank owner can close bank!");

        // check if the commercial bank has the central bank (address(0) means central bank "None")
        // if yes, call the function in RTGS contract: transfer the account balance(deposit) in central bank to the personal wallet of commercial bank owner 
        if(RTGSBank != address(0)){
            central.bankwithdraw(address(this));    
        }
        
        // check if the current balance of commercial bank is enough to pay back to all account opening persons
        for(uint i = 0; i<accountList.length; i++){
            require(address(this).balance > accountList[i].accountBalance,"Bank doesn't have enogh money to pay back to users.");
            
            // tranfer the withdrawn amount to account owners(account opening persons)
            payable(accountList[i].accountOwner).transfer(accountList[i].accountBalance);
        }
        // delete the account book in this commercial bank
        delete accountList;

        // transfer the rest of fund back to commercial bank owner
        payable(BankOwner).transfer(address(this).balance);    
        selfdestruct(payable(BankOwner));
        
    }

    // the function is to open a specific central bank account for the commercial bank 
    // opening a central bank account request the commercial bank to transfer at least 3 ethers to its central bank
    function registerRTGS(address centralbank_address, uint amountEther) payable public {

        // check if the central bank account opening person is the commerical bank owner
        require(BankOwner == msg.sender, "Only bank owner can open RTGS account.");
        amountEther = amountEther * 1 ether;

        // "msg.value" is the amount that commercial bank want to transfer(deposit) in the central bank 
        // check if the money amount in the commercial bank is enough to transfer for opening central bank account
        // address(this).balance is the money amount hold by commercial bank rather than commercial bank owner(bank owners has their owner accounts)
        require(amountEther < address(this).balance, "Insufficient balance!");

        // check if the commercial bank owner have enough money(at lest 3 ether = 3e19 wei) to send to central bank
        require(amountEther >= 0.1 ether, "At least 0.1 ether should be transfer to RTGS!");

        // check if the commercial bank have a central bank account
        require(RTGSBank == address(0), "This bank already has a RTGS account");

        // transfer money of the commercial bank owner to the central bank
        payable(centralbank_address).transfer(amountEther);

        // update the central bank address of the commercial bank
        RTGSBank = payable(centralbank_address);

        // set up the central bank for the commercial bank with given central bank address
        setCentralBank(centralbank_address);

        // call the function in RTGS(central bank) to add this commerical bank address and the input value info of commercial bank owner
        central.addOneBank(address(this), amountEther);

    }
    
    // the function is to update the complete central bank info of the commerical bank
    function setCentralBank(address central_bank) internal{
        central = RTGS(payable(central_bank));
    }

    // the function is to tranfer money from through the given central bank
    function transferMoney(address userAdd, address recieveBank, address central_Bank, uint amountEther) public payable{
        // check if central bank address of the commercial bank is the one that is responsible for transfering 
        require(central_Bank == RTGSBank, "Wrong central bank!");
        amountEther = amountEther * 1 ether;

        // check if the Transfer Initiator has enough money to transfer
        if(accountCheck(msg.sender,amountEther) == true){
            emit transferLog(userAdd, recieveBank, amountEther);
            // make the transaction between two commercial banks(transfer initiator and reciever) under the central bank
            if (central.InterbankTransaction(address(this),recieveBank, userAdd, amountEther) == true){
                Transaction memory mm = Transaction(bankLedger.length+1, msg.sender,  "Transfer Out", (amountEther + tx.gasprice)); 
                bankLedger.push(mm); 
                for(uint i = 0; i < accountList.length; i++){
                    if(msg.sender == accountList[i].accountOwner){
                        accountList[i].accountBalance = accountList[i].accountBalance - amountEther;
                    }
                }
            }

        }else{
            revert("Tansaction cannot be processed due to insufficient fund or not authorised to the account.");
        }
    }
    
    // the function is to check if the Transfer Initiator has enough money to transfer
    function accountCheck(address _executeUser, uint transferAmount) public returns(bool){
        
        for(uint i= 0; i < accountList.length; i++){
            // check if the Transfer Initiator has an account in this commercial bank
            if(accountList[i].accountOwner == _executeUser){
                // check if the Transfer Initiator has enough money to transfer
                if(transferAmount < accountList[i].accountBalance){
                    return true;
                }
            }
        } 
        return false;
    }

    // the function is to check if the given account is in the account book of commercial bank 
    function CheckUser(address accountOwner) public returns(bool){
        for(uint i = 0; i < accountList.length; i++){
            if (accountOwner == accountList[i].accountOwner){
                return true;
            }
        }
        return false;
    }
    
    // the commercial bank which calls function transfer the specific amount to the account owner(user/reciever)
    function TranstoUser(address userAdd, uint amount) public {
        // check if the user/reciever is in the account book of the commercial bank
        for(uint i= 0; i < accountList.length; i++){
            if(accountList[i].accountOwner == userAdd){
                //this loop is not needed
                //for(uint i= 0; i < accountList.length; i++){
                 // add this transaction to commercial bank ledger
                Transaction memory mm = Transaction(bankLedger.length+1, accountList[i].accountOwner,  "Receive Transfer", amount); 
                bankLedger.push(mm);
                //}
                // update the account balance of user
               
                accountList[i].accountBalance = amount + accountList[i].accountBalance;

            }
        }
    }

}

/* set up the attributes of commercial banks accounts in the central bank (address, balance)
*/
struct RTGSAccount{
    address bankAddress;
    uint RTGSBalance;
}

contract RTGS{
    address public RTGSOwner; // the central bank owner (address)
    RTGSAccount[] public RTGSledger; // a book to store all commercial banks
    CommercialBank public bBank; // initial type of "bBank" be "CommercialBank"

    event RTGSLedger(RTGSAccount[]);     
    event InterBankTrasferLog(address initiator, address recipient, uint amount);
    event bankwithdrawlog(address bank);

    receive() external payable {}
    fallback() external payable {}

    // call constructor when deploying the contract
    constructor(){
        RTGSOwner = msg.sender;
    }

    // add the commerical bank address and the value input by commercial bank owner into the commercial bank records in the central bank
    function addOneBank(address _bank, uint _bankBalance) public{
        RTGSAccount memory a = RTGSAccount(_bank, _bankBalance);
        RTGSledger.push(a);
    }
    
    // view the commercial bank records(ledgers) in the central bank
    function getLedgerRTGS() public {
        require(RTGSOwner == msg.sender, "Only the owner of the RTGS can view RTGS ledger!");
        emit RTGSLedger(RTGSledger);
    }
    
    // the function is to make the transaction between two commercial banks(transfer initiator and reciever) inside the central bank
    // _bankA is the address of initiator's commercial bank, _bankB is the address of reciever's commercial bank, userBAdd is the account address of reciever
    function InterbankTransaction(address _bankA, address _bankB, address userBAdd, uint amount) public returns(bool){

        // pack the given recieve account address as a "Commercial bank" contract 
        bBank = CommercialBank(payable(_bankB));

        // call the function in "Commercial bank" contract
        // check if the given account is in the account book of commercial bank
        if (bBank.CheckUser(userBAdd) == true){

            // log the transaction
            emit InterBankTrasferLog(_bankA, _bankB,  amount);

            // check if both the commercial bank address of transfer initiator and that if transfer reciever are all stored in the central bank
            // otherwise, throw error
            uint counter = 0;
            for(uint i = 0; i < RTGSledger.length; i++){
                if(RTGSledger[i].bankAddress == _bankA){
                    counter += 1;
                }else if(RTGSledger[i].bankAddress == _bankB){
                    counter += 1;
                }
            }
            require(counter == 2, "The recipent or initiator hasn't registered under this central bank");
            
            // update the account balance of transfer initiator and reciever in the central bank
            for(uint i = 0; i < RTGSledger.length; i++){
                if(RTGSledger[i].bankAddress == _bankA){
                    RTGSledger[i].RTGSBalance = RTGSledger[i].RTGSBalance - amount;
                }
                if (RTGSledger[i].bankAddress == _bankB){
                    RTGSledger[i].RTGSBalance = amount + RTGSledger[i].RTGSBalance;
                }
            }

            // call function in bank B to transfer to user
            bBank.TranstoUser(userBAdd, amount);
            return true;
        
        }else{
            revert("Recipent doesn't have an account in that bank!");
        }
    }

    // the function is that the commercial bank withdraw money from the central bank
    function bankwithdraw(address bank) public payable{
        for(uint i = 0; i < RTGSledger.length; i++){
            // check if the commercial bank which calls withdraw function is stored in the central bank
            if(RTGSledger[i].bankAddress == bank){
                // log 
                emit bankwithdrawlog(bank);
                // transfer the money stored in the central bank by commercial bank back to commercial bank
                payable(bank).transfer(RTGSledger[i].RTGSBalance);
                // update the balance of the commercial bank in the central bank
                RTGSledger[i].RTGSBalance = 0;
            }
        }
        
    }
}

