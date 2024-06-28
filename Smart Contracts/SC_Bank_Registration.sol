//SPDX-License-Identifier: MIT

pragma solidity^0.8.0;

contract SC_Bank_Registration 
{
    struct BankRegistration 
    {
        address bankAddr;
        uint256 timestamp_lock_security_money_by_bank;
        uint256 timestamp_lock_security_money_by_Reg_Body;
        bytes32 commitment;
        uint256 timestamp_commitment;
        bool response1;
        uint256 timestamp_response1;
        bool response2;
        uint256 timestamp_response2;
        uint256 unlock_amount_security_money_by_bank;
        uint256 timestamp_unlock_security_money_by_bank;
        uint256 unlock_amount_security_money_by_Reg_Body;
        uint256 timestamp_unlock_security_money_by_Reg_Body;
        bool protocol_aborted;
    }

    mapping(address => uint256) bankID; //Maps: bankID[bank address] => bankID
    mapping(address => uint256) latestBankRegProtocolID; //Maps: latestBankRegProtocolID[bank address] => protocolID
    mapping(uint256 => BankRegistration) bankRegistration; //Maps: bankRegistration[protocolID] => struct BankRegistration
    mapping(uint256 => bool) bankRegistrationProtocolCurrentlyRuns; //Maps: bankRegistrationProtocolCurrentlyRuns[protocolID] => TRUE/FALSE

    address public regulatory_Body;

    uint256 public bankRegProtocolIDGenerator = 0;
    uint256 public constant timeLimit = 300 seconds;
    uint256 public constant lockingAmount = 1000 wei;
    uint256 bankIDGenerator = 0;

    constructor() 
    {
        regulatory_Body = msg.sender;
    }

    /**
        Interface to other smart contract
    */
    function getBankID(address _bankAddr) external view returns(uint256)
    {
        return(bankID[_bankAddr]);
    }

    function isBankIDValid(uint256 _bankID) external view returns(bool)
    {
        if(_bankID > 0 && _bankID <= bankIDGenerator)
        {
            return(true);
        }
        else
        {
            return(false);
        }
    }

    /**
        PROTOCOL: Bank Registration 
    */

    /**
    Caller: Bank
    When: To initiate bank registration process towards regulatory body.
    Previous Function: NA
    **/
    function lockMoneyByBank() public payable
    {
        require(bankID[msg.sender] == 0, "The bank is already registered!!");
        
        uint256 _bankRegProtocolID  = latestBankRegProtocolID[msg.sender];
        require(bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] == false, "Previous instance of the bank registration protocol is not yet terminated!!");
        require(msg.value == lockingAmount, "Incorrect locking amount!!");

        bankRegProtocolIDGenerator ++;
        _bankRegProtocolID = bankRegProtocolIDGenerator;
        latestBankRegProtocolID[msg.sender] = _bankRegProtocolID;

        BankRegistration memory new_bank_registration = bankRegistration[_bankRegProtocolID];
        new_bank_registration.bankAddr = msg.sender;
        new_bank_registration.timestamp_lock_security_money_by_bank = block.timestamp;

        bankRegistration[_bankRegProtocolID] = new_bank_registration;

        bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] = true;
    }

    /**
    Caller: Bank
    When: If the Regulatory body does not lock money within time limit, bank can abort the protocol and unlock its money.
    Previous Function: lockMoneyByBank by bank
    **/
    function exit1BankReg() external
    {
        require(bankID[msg.sender] == 0, "The bank is already registered!!");
        uint256 _bankRegProtocolID  = latestBankRegProtocolID[msg.sender];
        require(bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] == true, "The protocol is not yet started!!");
        

        BankRegistration memory new_bank_registration = bankRegistration[_bankRegProtocolID];
        require(new_bank_registration.bankAddr == msg.sender, "You are not holding the intended address!!");
        //require(new_bank_registration.bankID == _bankID, "Given bankID is not the intended one!!");
        require(new_bank_registration.timestamp_lock_security_money_by_bank != 0, "The bank not yet locked the money!!");
        require(new_bank_registration.timestamp_lock_security_money_by_Reg_Body == 0, "The Regulatory body has already locked its money!!");
        require((block.timestamp - new_bank_registration.timestamp_lock_security_money_by_bank) > timeLimit, "Timelimit not yet exceeded!!");

        payable(msg.sender).transfer(lockingAmount);
        new_bank_registration.unlock_amount_security_money_by_bank = lockingAmount;
        new_bank_registration.timestamp_unlock_security_money_by_bank = block.timestamp;
        //new_bank_registration.unlock_amount_security_money_by_Reg_Body = 0;
        //new_bank_registration.timestamp_unlock_security_money_by_Reg_Body = block.timestamp;
        new_bank_registration.protocol_aborted = true;
        bankRegistration[_bankRegProtocolID] = new_bank_registration;

        bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] = false;
    }


    /**
    Caller: Regulatory body
    When: Once bank locked money on smart contract, Regulatory body invokes this function to lock the security money.
    Previous Function: lockMoneyByBank() by bank
    **/

    function lockMoneyByRegulatoryBody(address _bankAddr) external payable 
    {
        require(msg.sender == regulatory_Body, "Only reguatory body has access to invoke the function!!");
        require(bankID[_bankAddr] == 0, "The given bank address is incorrect. The bank is already registered!!");
        require(msg.value == lockingAmount, "Incorrect locking amount!!");

        uint256 _bankRegProtocolID  = latestBankRegProtocolID[_bankAddr];
        require(bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] == true, "No instance of the bank registration protocol is running at present!!");

        BankRegistration memory new_bank_registration = bankRegistration[_bankRegProtocolID];
        require(new_bank_registration.bankAddr == _bankAddr, "Access denied as the given bank address is not intended!!");
        require(new_bank_registration.timestamp_lock_security_money_by_bank != 0, "The bank not yet locked its money!!");
        require(new_bank_registration.timestamp_lock_security_money_by_Reg_Body == 0, "The regulatory body has already locked its money!!");
        require((block.timestamp - new_bank_registration.timestamp_lock_security_money_by_bank <= timeLimit), "Timelimit exceeded!!");
        
        new_bank_registration.timestamp_lock_security_money_by_Reg_Body = block.timestamp;
        bankRegistration[_bankRegProtocolID]  = new_bank_registration;
    }


    /**
    Caller: Regulatory Body
    When: Once Reg Body locked money on smart contract, but bank does not commit account info within time limit, 
          Reg Body can abort the protocol and unlock its money. Here, the system will penalize the bank by deducting
          its locked amount and transfer the same to the Reg Body.
    Previous Function: lockMoneyByRegulatoryBody() by Regulatory Body
    **/
    function exit2BankReg(address _bankAddr) external
    {
        require(msg.sender == regulatory_Body, "Only reguatory body has access to invoke the function!!");
        require(bankID[_bankAddr] == 0, "The given bank address is incorrect. The bank is already registered!!");
        
        uint256 _bankRegProtocolID  = latestBankRegProtocolID[_bankAddr];
        require(bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] == true, "No instance of the bank registration protocol is running at present!!");

        BankRegistration memory new_bank_registration = bankRegistration[_bankRegProtocolID];
        require(new_bank_registration.bankAddr == _bankAddr, "You are not holding the intended address!!");
        require(new_bank_registration.timestamp_lock_security_money_by_Reg_Body != 0, "The regulatory body not yet locked the money!!");
        require(new_bank_registration.timestamp_commitment == 0, "The customer has already commited for the account information!!");
        require((block.timestamp - new_bank_registration.timestamp_lock_security_money_by_Reg_Body) > timeLimit, "Timelimit not yet exceeded!!");

        payable(msg.sender).transfer(2*lockingAmount);

        new_bank_registration.unlock_amount_security_money_by_bank = 0;
        new_bank_registration.unlock_amount_security_money_by_Reg_Body = 2*lockingAmount;
        new_bank_registration.timestamp_unlock_security_money_by_bank = block.timestamp;
        new_bank_registration.timestamp_unlock_security_money_by_Reg_Body = block.timestamp;

        new_bank_registration.protocol_aborted = true;
        bankRegistration[_bankRegProtocolID] = new_bank_registration;

        bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] = false;
    } 


    /**
    Caller: Bank
    When: After locking money by regulatory body, bank sends information regarding the proof of banking license(PoBL) in offline mode.
          And invokes this function to commit the information send in offline.
    Previous Function: lockMoneyByRegulatoryBody() by Regulatory body
    **/

    function commitPoBL(bytes32 _commit) external 
    {
        require(bankID[msg.sender] == 0, "The bank is already registered!!");
        
        uint256 _bankRegProtocolID  = latestBankRegProtocolID[msg.sender];
        require(bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] == true, "No instance of the bank registration protocol is running at present!!");

        BankRegistration memory new_bank_registration = bankRegistration[_bankRegProtocolID];
        require(new_bank_registration.bankAddr == msg.sender, "Access denied as the bank does not hold the intended bank address!!");
        require(new_bank_registration.timestamp_lock_security_money_by_Reg_Body != 0, "The regulatory body not yet locked its money!!");
        require(new_bank_registration.timestamp_commitment == 0, "The bank has already committed PoBL!!");
        require((block.timestamp - new_bank_registration.timestamp_lock_security_money_by_Reg_Body <= timeLimit), "Timelimit exceeded!!");

        new_bank_registration.commitment = _commit;
        new_bank_registration.timestamp_commitment = block.timestamp;

        bankRegistration[_bankRegProtocolID]  = new_bank_registration;
    }

    /**
    Caller: Bank
    When: If the Regulatory body does not send response1 within time limit, bank can abort the protocol and unlock its money.
          Here, the system will penalize the Regulatory body by deducting its locked amount and transfer the same to the bank.
    Previous Function: commitPoBL() by bank
    **/
    function exit3BankReg() external
    {
        require(bankID[msg.sender] == 0, "The bank is already registered!!");
        uint256 _bankRegProtocolID  = latestBankRegProtocolID[msg.sender];
        require(bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] == true, "No instance of the bank registration protocol is running at present!!");

        BankRegistration memory new_bank_registration = bankRegistration[_bankRegProtocolID];
        require(new_bank_registration.bankAddr == msg.sender, "Access denied as the bank does not hold the intended bank address!!");
        require(new_bank_registration.timestamp_commitment != 0, "The bank not yet commited for the account information!!");
        require(new_bank_registration.timestamp_response1 == 0, "The regulatory body has not already send its first response!!");
        require((block.timestamp - new_bank_registration.timestamp_commitment) > timeLimit, "Timelimit not yet exceeded!!");

        payable(msg.sender).transfer(2*lockingAmount);

        new_bank_registration.unlock_amount_security_money_by_bank = 2*lockingAmount;
        new_bank_registration.unlock_amount_security_money_by_Reg_Body = 0;
        new_bank_registration.timestamp_unlock_security_money_by_bank = block.timestamp;
        new_bank_registration.timestamp_unlock_security_money_by_Reg_Body = block.timestamp;

        new_bank_registration.protocol_aborted = true;
        bankRegistration[_bankRegProtocolID] = new_bank_registration;

        bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] = false;
    }


    /**
    Caller: Regulatory body
    When: After the bank commits account information, the Regulatory body checks if the commitment matches with the received information.
          And invokes this function to register the response.
    Previous Function: commitPoBL() by bank
    **/

    function checkIfCommitmentMatches(address _bankAddr, bool _response1) external
    {
        require(regulatory_Body == msg.sender, "Only reguatory body has access to invoke the function!!");

        require(bankID[_bankAddr] == 0, "The given bank address is incorrect. The bank is already registered!!");

        uint256 _bankRegProtocolID  = latestBankRegProtocolID[_bankAddr];
        require(bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] == true, "No instance of the bank registration protocol is running at present!!");

        BankRegistration memory new_bank_registration = bankRegistration[_bankRegProtocolID];
        require(new_bank_registration.timestamp_commitment != 0, "The bank not yet committed!!");
        require(new_bank_registration.timestamp_response1 == 0, "The regulatory body already send its response1!!");
        require(block.timestamp - new_bank_registration.timestamp_commitment <= timeLimit, "Timelimit exceeded!!");

        new_bank_registration.response1 = _response1;
        new_bank_registration.timestamp_response1 = block.timestamp;

        if(_response1 == false) 
        {
            payable(_bankAddr).transfer(lockingAmount);
            payable(msg.sender).transfer(lockingAmount);

            new_bank_registration.unlock_amount_security_money_by_bank = lockingAmount;
            new_bank_registration.unlock_amount_security_money_by_Reg_Body = lockingAmount;
            new_bank_registration.timestamp_unlock_security_money_by_bank = block.timestamp;
            new_bank_registration.timestamp_unlock_security_money_by_Reg_Body = block.timestamp;

            new_bank_registration.protocol_aborted = true;
            bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] = false;
        }

        bankRegistration[_bankRegProtocolID]  = new_bank_registration;
    }


    /**
    Caller: Bank
    When: If the Regulatory body does not send response2 within time limit, bank can abort the protocol and unlock its money.
          Here, the system will penalize the Regulatory body by deducting its locked amount and transfer the same to the bank.
    Previous Function: checkIfCommitmentMatches() by Reg Body
    **/
    function exit4BankReg() external
    {
        require(bankID[msg.sender] == 0, "The bank is already registered!!");
        uint256 _bankRegProtocolID  = latestBankRegProtocolID[msg.sender];
        require(bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] == true, "No instance of the bank registration protocol is running at present!!");

        BankRegistration memory new_bank_registration = bankRegistration[_bankRegProtocolID];
        require(new_bank_registration.bankAddr == msg.sender, "Access denied as the bank does not hold the intended bank address!!");
        require(new_bank_registration.timestamp_response1 != 0, "The regulatory body has already send its first response!!");
        require(new_bank_registration.timestamp_response2 == 0, "The regulatory body has not already send its second response!!");
        require((block.timestamp - new_bank_registration.timestamp_response1) > timeLimit, "Timelimit not yet exceeded!!");

        payable(msg.sender).transfer(2*lockingAmount);

        new_bank_registration.unlock_amount_security_money_by_bank = 2*lockingAmount;
        new_bank_registration.unlock_amount_security_money_by_Reg_Body = 0;
        new_bank_registration.timestamp_unlock_security_money_by_bank = block.timestamp;
        new_bank_registration.timestamp_unlock_security_money_by_Reg_Body = block.timestamp;

        new_bank_registration.protocol_aborted = true;
        bankRegistration[_bankRegProtocolID] = new_bank_registration;

        bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] = false;
    }


    /**
    Caller: Regulatory body
    When: Once the Regulatory body verifies if the bank belongs to the Regulatory body, it invokes this function to register the verification result on BC.
    Previous Function: checkIfCommitmentMatches() by Regulatory body
    **/

    function sendVerificationResult(address _bankAddr, bool _response2) external 
    {
        require(regulatory_Body == msg.sender, "Only reguatory body has access to invoke the function!!");
        require(bankID[_bankAddr] == 0, "The given bank address is incorrect. The bank is already registered!!");
        uint256 _bankRegProtocolID  = latestBankRegProtocolID[_bankAddr];
        require(bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] == true, "No instance of the bank registration protocol is running at present!!");

        BankRegistration memory new_bank_registration = bankRegistration[_bankRegProtocolID] ;
        require(new_bank_registration.timestamp_response2 == 0, "The regulatory body has already send its response2!!");
        require(new_bank_registration.timestamp_response1 != 0, "The regulatory body must provide its response1 before sending response2!!");
        require(block.timestamp - new_bank_registration.timestamp_response1 <= timeLimit, "Timelimit exceeded");

        new_bank_registration.response2 = _response2;
        new_bank_registration.timestamp_response2 = block.timestamp;
    
        payable(_bankAddr).transfer(lockingAmount);
        payable(msg.sender).transfer(lockingAmount);

        new_bank_registration.unlock_amount_security_money_by_bank = lockingAmount;
        new_bank_registration.unlock_amount_security_money_by_Reg_Body = lockingAmount;
        new_bank_registration.timestamp_unlock_security_money_by_bank = block.timestamp;
        new_bank_registration.timestamp_unlock_security_money_by_Reg_Body = block.timestamp;
        
        if(_response2 == true) 
        {
            bankIDGenerator++;
            bankID[_bankAddr] = bankIDGenerator; 
            
        }
        else
        {
            new_bank_registration.protocol_aborted = true;
        }
        
        bankRegistration[_bankRegProtocolID]  = new_bank_registration;
        bankRegistrationProtocolCurrentlyRuns[_bankRegProtocolID] = false;
    }

}
