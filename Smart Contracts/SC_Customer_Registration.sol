//SPDX-License-Identifier: MIT

pragma solidity^0.8.0;
import "./SC_Bank_Registration.sol";

contract SC_Customer_Registration 
{
    address public addr_SC_Bank_Registration;
    SC_Bank_Registration instance_SC_Bank_Registration;

    struct CustomerRegistration 
    {
        address customerAddr;
        uint256 bankID;
        uint256 timestamp_lock_security_money_by_customer;
        uint256 timestamp_lock_security_money_by_bank;
        bytes32 commitment;
        uint256 timestamp_commitment;
        bool response1;
        uint256 timestamp_response1;
        bool response2;
        uint256 timestamp_response2;
        uint256 timestamp_registration_done;
        uint256 security_money_received_by_payer;
        uint256 timestamp_get_security_money_by_payer;
        uint256 security_money_received_by_issuer_bank;
        uint256 timestamp_get_security_money_by_issuer_bank;
        bool protocol_aborted;
    }

    mapping(address => mapping(uint256 => bool)) customerBelongingToBank; //Maps: customerBelongToBank[customer Addr][Bank ID] => TRUE/FALSE;
    mapping(address => mapping(uint256 => uint256)) latestCustomerRegProtcolID; //Maps: latestCustomerRegProtcolID[customer Addr][Bank ID] => protocolID
    mapping(uint256 => CustomerRegistration) customerRegistration; //Maps: customerRegistration[customerRegProtocolID] => struct CustomerRegistration
    mapping(uint256 => bool) customerRegistrationProtocolCurrentlyRuns; //Maps: customerRegistrationProtocolCurrentlyRuns[customerRegProtocolID] => TRUE/FALSE; 
    
    //mapping(address => mapping(uint256 => Customer)) customer; //Maps: customer[customer address][bankID] => struct Customer;

    uint256 customerRegProtcolIDGenerator = 0;

    uint256 public constant timeLimit = 300 seconds;
    uint256 public constant lockingAmount = 1000 wei;
    

    constructor(address _addr_SC_Bank_Registration) 
    {
        addr_SC_Bank_Registration = _addr_SC_Bank_Registration;
        instance_SC_Bank_Registration = SC_Bank_Registration(addr_SC_Bank_Registration);
    }


    /**
        Interface to other smart contract
    */
    function isCustomerRegisteredToBank(address _cAddr, uint256 _bankID) external view returns(bool)
    {
        return(customerBelongingToBank[_cAddr][_bankID]);
    }

    /**
        PROTOCOL: Customer Registration 
    */

    /**
    Caller: Customer
    When: To initiate customer registration process towards bank.
    Previous Function: NA
    **/
    function lockMoneyByCustomer(uint256 _bankID) public payable
    {
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(customerBelongingToBank[msg.sender][_bankID] == false, "The customer is already registered for this bank!!");

        uint256 _custRegProtocolID  = latestCustomerRegProtcolID[msg.sender][_bankID];
        require(customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] == false, "Previous instance of the customer registration protocol is not yet terminated!!");
        require(msg.value == lockingAmount, "Incorrect locking amount!!");

        customerRegProtcolIDGenerator ++;
        _custRegProtocolID = customerRegProtcolIDGenerator;
        latestCustomerRegProtcolID[msg.sender][_bankID] = _custRegProtocolID;

        CustomerRegistration memory new_customer_registration = customerRegistration[_custRegProtocolID];
        new_customer_registration.customerAddr = msg.sender;
        new_customer_registration.bankID = _bankID;
        new_customer_registration.timestamp_lock_security_money_by_customer = block.timestamp;
        customerRegistration[_custRegProtocolID] = new_customer_registration;

        customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] = true;
    }
    
    /**
    Caller: Customer
    When: If the bank does not lock money within time limit, customer can abort the protocol and unlock its money.
    Previous Function: lockMoneyByCustomer by Customer
    **/
    function exit1CustomerReg(uint256 _bankID) external
    {
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(customerBelongingToBank[msg.sender][_bankID] == false, "The customer is already registered for this bank!!");

        uint256 _custRegProtocolID  = latestCustomerRegProtcolID[msg.sender][_bankID];
        require(customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] == true, "No instance of the customer registration protocol is running at present!!");

        CustomerRegistration memory new_customer_registration = customerRegistration[_custRegProtocolID];
        require(new_customer_registration.customerAddr == msg.sender, "You are not holding the intended customer address!!");
        require(new_customer_registration.bankID == _bankID, "Given bankID is not the intended one!!");
        require(new_customer_registration.timestamp_lock_security_money_by_customer != 0, "The customer not yet locked the money!!");
        require(new_customer_registration.timestamp_lock_security_money_by_bank == 0, "The bank has already locked its money!!");
        require((block.timestamp - new_customer_registration.timestamp_lock_security_money_by_customer) > timeLimit, "Timelimit not yet exceeded!!");

        payable(msg.sender).transfer(lockingAmount);
        new_customer_registration.security_money_received_by_payer = lockingAmount;
        new_customer_registration.timestamp_get_security_money_by_payer = block.timestamp;
        new_customer_registration.protocol_aborted = true;
        customerRegistration[_custRegProtocolID] = new_customer_registration;

        customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] = false;
    }


    /**
    Caller: Bank (holding a valid bankID)
    When: Once customer locked money on smart contract, bank invokes this function to lock the security money.
    Previous Function: lockMoneyByCustomer() by Customer
    **/
    function lockMoneyByBank(address _cAddr) public payable
    {
        uint256 _bankID = instance_SC_Bank_Registration.getBankID(msg.sender);
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(customerBelongingToBank[_cAddr][_bankID] == false, "The customer is already registered for this bank!!");
        
        uint256 _custRegProtocolID  = latestCustomerRegProtcolID[_cAddr][_bankID];
        require(customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] == true, "No instance of the customer registration protocol is running at present!!");
        require(msg.value == lockingAmount, "Incorrect locking amount!!");

        CustomerRegistration memory new_customer_registration = customerRegistration[_custRegProtocolID];
        require(new_customer_registration.customerAddr == _cAddr, "Given customer address is invalid!!");
        require(new_customer_registration.bankID == _bankID, "You are not holding the intended bankID!!");
        require(new_customer_registration.timestamp_lock_security_money_by_customer != 0, "The customer not yet locked the money!!");
        require(new_customer_registration.timestamp_lock_security_money_by_bank == 0, "The bank has already locked its money!!");
        require((block.timestamp - new_customer_registration.timestamp_lock_security_money_by_customer) <= timeLimit, "Timelimit exceeded!!");
        
        new_customer_registration.timestamp_lock_security_money_by_bank = block.timestamp;
        customerRegistration[_custRegProtocolID] = new_customer_registration;
    }

    /**
    Caller: Bank (holding a valid bankID)
    When: Once bank locked money on smart contract, but customer does not commit account info within time limit, 
          bank can abort the protocol and unlock its money. Here, the system will penalize the customer by deducting
          its locked amount and transfer the same to the bank.
    Previous Function: lockMoneyByBank() by Bank
    **/
    function exit2CustomerReg(address _cAddr) external
    {
        uint256 _bankID = instance_SC_Bank_Registration.getBankID(msg.sender);
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(customerBelongingToBank[_cAddr][_bankID] == false, "The customer is already registered for this bank!!");
        uint256 _custRegProtocolID  = latestCustomerRegProtcolID[_cAddr][_bankID];
        require(customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] == true, "No instance of the customer registration protocol is running at present!!");

        CustomerRegistration memory new_customer_registration = customerRegistration[_custRegProtocolID];
        require(new_customer_registration.customerAddr == _cAddr, "Given customer address is invalid!!");
        require(new_customer_registration.bankID == _bankID, "You are not holding the intended bankID!!");
        require(new_customer_registration.timestamp_lock_security_money_by_bank != 0, "The bank not yet locked the money!!");
        require(new_customer_registration.timestamp_commitment == 0, "The customer has already commited for the account information!!");
        require((block.timestamp - new_customer_registration.timestamp_lock_security_money_by_customer) > timeLimit, "Timelimit not yet exceeded!!");

        payable(msg.sender).transfer(2*lockingAmount);
        new_customer_registration.security_money_received_by_payer = 0;
        new_customer_registration.security_money_received_by_issuer_bank = 2*lockingAmount;
        new_customer_registration.timestamp_get_security_money_by_payer = block.timestamp;
        new_customer_registration.timestamp_get_security_money_by_issuer_bank = block.timestamp;

        new_customer_registration.protocol_aborted = true;
        customerRegistration[_custRegProtocolID] = new_customer_registration;

        customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] = false;
    } 

    /**
    Caller: Customer
    When: After locking money by bank, customer sends information regarding the proof of holding an account with this bank in offline mode.
          And invokes this function to commit the information send in offline.
    Previous Function: lockMoneyByBank() by Bank
    **/
    function commitAccountInfo(bytes32 _commitment, uint256 _bankID) public 
    {
        require(customerBelongingToBank[msg.sender][_bankID] == false, "You are already registered for this bank.");
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        uint256 _custRegProtocolID  = latestCustomerRegProtcolID[msg.sender][_bankID];
        require(customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] == true, "No instance of the customer registration protocol is running at present!!");

        CustomerRegistration memory new_customer_registration = customerRegistration[_custRegProtocolID];
        require(new_customer_registration.customerAddr == msg.sender, "You are not holding the intended customer address!!");
        require(new_customer_registration.bankID == _bankID, "Given bankID is not the intended one!!");
        require(new_customer_registration.timestamp_lock_security_money_by_bank != 0, "The bank not yet locked the money!!");
        require(new_customer_registration.timestamp_commitment == 0, "The customer has already commited the value!!");
        require((block.timestamp - new_customer_registration.timestamp_lock_security_money_by_bank) <= timeLimit, "Timelimit exceeded!!");
        
        new_customer_registration.commitment = _commitment;
        new_customer_registration.timestamp_commitment = block.timestamp;
        customerRegistration[_custRegProtocolID] = new_customer_registration;
    }

    /**
    Caller: Customer
    When: If the bank does not send response1 within time limit, customer can abort the protocol and unlock its money.
          Here, the system will penalize the bank by deducting its locked amount and transfer the same to the customer.
    Previous Function: commitAccountInfo() by Customer
    **/
    function exit3CustomerReg(uint256 _bankID) external
    {
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(customerBelongingToBank[msg.sender][_bankID] == false, "The customer is already registered for this bank!!");

        uint256 _custRegProtocolID  = latestCustomerRegProtcolID[msg.sender][_bankID];
        require(customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] == true, "No instance of the customer registration protocol is running at present!!");

        CustomerRegistration memory new_customer_registration = customerRegistration[_custRegProtocolID];
        require(new_customer_registration.customerAddr == msg.sender, "You are not holding the intended customer address!!");
        require(new_customer_registration.bankID == _bankID, "Given bankID is not the intended one!!");
        require(new_customer_registration.timestamp_commitment != 0, "The customer not yet commited for the account information!!");
        require(new_customer_registration.timestamp_response1 == 0, "The bank has already send its first response!!");
        require((block.timestamp - new_customer_registration.timestamp_commitment) > timeLimit, "Timelimit not yet exceeded!!");

        payable(msg.sender).transfer(2*lockingAmount);
        new_customer_registration.security_money_received_by_payer = 2*lockingAmount;
        new_customer_registration.security_money_received_by_issuer_bank = 0;
        new_customer_registration.timestamp_get_security_money_by_payer = block.timestamp;
        new_customer_registration.timestamp_get_security_money_by_issuer_bank = block.timestamp;

        new_customer_registration.protocol_aborted = true;
        customerRegistration[_custRegProtocolID] = new_customer_registration;

        customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] = false;
    }


    /**
    Caller: Bank
    When: After the customer commits account information, the bank checks if the commitment matches with the received information.
          And invokes this function to register the response.
    Previous Function: commitAccountInfo() by Customer
    **/
    function checkIfCommitmentMatches(address _cAddr, bool _response1) public
    {
        uint256 _bankID = instance_SC_Bank_Registration.getBankID(msg.sender);
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(customerBelongingToBank[_cAddr][_bankID] == false, "The customer is already registered for this bank!!");
        uint256 _custRegProtocolID  = latestCustomerRegProtcolID[_cAddr][_bankID];
        require(customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] == true, "No instance of the customer registration protocol is running at present!!");
        
        CustomerRegistration memory new_customer_registration = customerRegistration[_custRegProtocolID];
        require(new_customer_registration.customerAddr == _cAddr, "Given customer address is invalid!!");
        require(new_customer_registration.bankID == _bankID, "You are not holding the intended bankID!!");    
        require(new_customer_registration.timestamp_commitment != 0, "The customer not yet commited for the account information!!");
        require(new_customer_registration.timestamp_response1 == 0, "The bank has already send its first response!!");
        require(block.timestamp - new_customer_registration.timestamp_commitment <= timeLimit, "Timelimit exceeded!!");
        
        new_customer_registration.response1 = _response1;
        new_customer_registration.timestamp_response1 = block.timestamp;

        if(_response1 == false)
        {
            //unlock money and transfer to individual's account..
            payable(_cAddr).transfer(lockingAmount);
            payable(msg.sender).transfer(lockingAmount);
            
            new_customer_registration.security_money_received_by_payer = lockingAmount;
            new_customer_registration.security_money_received_by_issuer_bank = lockingAmount;
            new_customer_registration.timestamp_get_security_money_by_payer = block.timestamp;
            new_customer_registration.timestamp_get_security_money_by_issuer_bank = block.timestamp;

            new_customer_registration.protocol_aborted = true;

            customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] = false;
        }

        customerRegistration[_custRegProtocolID] = new_customer_registration;
    }

    /**
    Caller: Customer
    When: If the bank does not send response2 within time limit after sending response1, customer can abort the protocol and unlock its money.
          Here, the system will penalize the bank by deducting its locked amount and transfer the same to the customer.
    Previous Function: checkIfCommitmentMatches() by Bank
    **/
    function exit4CustomerReg(uint256 _bankID) external
    {
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(customerBelongingToBank[msg.sender][_bankID] == false, "The customer is already registered for this bank!!");

        uint256 _custRegProtocolID  = latestCustomerRegProtcolID[msg.sender][_bankID];
        require(customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] == true, "No instance of the customer registration protocol is running at present!!");

        CustomerRegistration memory new_customer_registration = customerRegistration[_custRegProtocolID];
        require(new_customer_registration.customerAddr == msg.sender, "You are not holding the intended customer address!!");
        require(new_customer_registration.bankID == _bankID, "Given bankID is not the intended one!!");
        require(new_customer_registration.timestamp_response1 != 0, "The bank not yet send its first response!!");
        require(new_customer_registration.timestamp_response2 == 0, "The bank has already send its second response!!");
        require((block.timestamp - new_customer_registration.timestamp_response1) > timeLimit, "Timelimit not yet exceeded!!");

        payable(msg.sender).transfer(2*lockingAmount);
        new_customer_registration.security_money_received_by_payer = 2*lockingAmount;
        new_customer_registration.security_money_received_by_issuer_bank = 0;
        new_customer_registration.timestamp_get_security_money_by_payer = block.timestamp;
        new_customer_registration.timestamp_get_security_money_by_issuer_bank = block.timestamp;

        new_customer_registration.protocol_aborted = true;
        customerRegistration[_custRegProtocolID] = new_customer_registration;

        customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] = false;
    }

    /**
    Caller: Bank
    When: Once the bank verifies if the customer belongs to the bank, it invokes this function to register the verification result on BC.
    Previous Function: checkIfCommitmentMatches() by Bank
    **/
    function sendVerificationResult(address _cAddr, bool _response2) public 
    {
        uint256 _bankID = instance_SC_Bank_Registration.getBankID(msg.sender);
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(customerBelongingToBank[_cAddr][_bankID] == false, "The customer is already registered for this bank!!");
        uint256 _custRegProtocolID  = latestCustomerRegProtcolID[_cAddr][_bankID];
        require(customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] == true, "No instance of the customer registration protocol is running at present!!");
        
        CustomerRegistration memory new_customer_registration = customerRegistration[_custRegProtocolID];
        require(new_customer_registration.customerAddr == _cAddr, "Given customer address is invalid!!");
        require(new_customer_registration.bankID == _bankID, "You are not holding the intended bankID!!");
        require(new_customer_registration.timestamp_response1 != 0, "The bank not yet send its first response!!");
        require(new_customer_registration.timestamp_response2 == 0, "The bank has already given its second response!!");
        require(block.timestamp - new_customer_registration.timestamp_response1 <= timeLimit, "Timelimit exceeded!!"); 

        new_customer_registration.response2 = _response2;
        new_customer_registration.timestamp_response2 = block.timestamp;

        //unlock money and transfer to individual's account..
        payable(_cAddr).transfer(lockingAmount);
        payable(msg.sender).transfer(lockingAmount);            
        new_customer_registration.security_money_received_by_payer = lockingAmount;
        new_customer_registration.security_money_received_by_issuer_bank = lockingAmount;
        new_customer_registration.timestamp_get_security_money_by_payer = block.timestamp;
        new_customer_registration.timestamp_get_security_money_by_issuer_bank = block.timestamp;

        if(_response2 == true)
        {
            //Regsiter the customer..
            customerBelongingToBank[_cAddr][_bankID] = true;
        }
        else
        {
            new_customer_registration.protocol_aborted = true;
        }

        customerRegistration[_custRegProtocolID] = new_customer_registration;
        customerRegistrationProtocolCurrentlyRuns[_custRegProtocolID] = false;
    }
}
