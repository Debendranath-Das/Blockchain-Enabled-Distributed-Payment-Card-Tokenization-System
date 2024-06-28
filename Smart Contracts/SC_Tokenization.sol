//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SC_Bank_Registration.sol";
import "./SC_Customer_Registration.sol";

contract SC_Tokenization
{
    address public addr_SC_Bank_Registration;
    SC_Bank_Registration instance_SC_Bank_Registration;

    address public addr_SC_Customer_Registration;
    SC_Customer_Registration instance_SC_Customer_Registration;

    struct Token
    {
        uint256 tokenID;
        address payer;
        address payee;
        uint256 issuer_bankID;
        uint256 timestamp_issuance_token;
        uint256 timestamp_debit_token_amount_from_payer;
        uint256 acquirer_bankID;
        uint256 timestamp_credit_token_amount_to_payee;
        uint256 timestamp_ask_to_refund_token_amount_to_payer;
        bool refund_token_amount_to_payer;
        uint256 timestamp_refund_token_amount_to_payer;
    }

    struct TokenAppl
    {
        uint256 tokenApplID;
        address payer;
        uint256 issuer_bankID;
        uint256 timestamp_lock_security_money_by_payer;
        uint256 timestamp_lock_security_money_by_issuer_bank;
        bytes32 card_commitment;
        uint256 timestamp_card_commitment;
        bool response1;
        uint256 timestamp_response1;
        bool response2;
        uint256 timestamp_response2;
        bool response3;
        uint256 timestamp_response3;
        address payee;
        uint256 token_amount;
        uint256 timestamp_requesting_token;
        bool response4;
        uint256 timestamp_response4;
        uint256 security_money_received_by_payer;
        uint256 timestamp_get_security_money_by_payer;
        uint256 security_money_received_by_issuer_bank;
        uint256 timestamp_get_security_money_by_issuer_bank;
    }

    struct TokenExecutionForPayer
    {
        uint256 tokenID;
        uint256 timestamp_lock_security_money_by_payer;
        uint256 timestamp_lock_security_money_by_issuer_bank;
        uint256 timestamp_execute_token_by_payer;
        uint256 timestamp_debit_token_amount;
        bool transaction_debit_status;
        uint256 security_money_received_by_payer;
        uint256 timestamp_get_security_money_by_payer;
        uint256 security_money_received_by_issuer_bank;
        uint256 timestamp_get_security_money_by_issuer_bank;
    }

    struct TokenExecutionForPayee
    {
        uint256 tokenID;
        uint256 timestamp_lock_security_money_by_payee;
        uint256 timestamp_lock_security_money_by_acquirer_bank;
        uint256 timestamp_execute_token_by_payee;
        uint256 timestamp_credit_token_amount;
        bool transaction_credit_status;
        uint256 security_money_received_by_payee;
        uint256 timestamp_get_security_money_by_payee;
        uint256 security_money_received_by_acquirer_bank;
        uint256 timestamp_get_security_money_by_acquirer_bank;
    }

    mapping(address => mapping(uint256 => uint256)) public latestTokenApplID; //Maps: latestTokenApplID[customer Addr][Bank ID] => tokenApplID
    mapping(uint256 => bool) public tokenApplUnderProcess; // e.g tokenApplUnderProcess[tokenApplID] = TRUE/FALSE;
    mapping(uint256 => bool) public tokenApplAborted; // e.g. tokenApplAborted[tokenApplID] => TRUE/FALSE;
    mapping(uint256 => TokenAppl) public tokenIssuanceAppl; // e.g. tokenIssuanceAppl[tokenApplID] => struct TokenAppl;

    mapping(uint256 => TokenExecutionForPayer) public tokenExecutionForPayer; // e.g. tokenExecutionForPayer[tokenID] = struct TokenExecutionForPayer;
    mapping(uint256 => bool) public tokenExecutionForPayerUnderProcess; // e.g. tokenExecutionForPayerUnderProcess[tokenID] = TRUE/FALSE;

    mapping(uint256 => TokenExecutionForPayee) public tokenExecutionForPayee; // e.g. tokenExecutionForPayee[tokenID] = struct TokenExecutionForPayee;
    mapping(uint256 => bool) public tokenExecutionForPayeeUnderProcess; // e.g. tokenExecutionForPayeeUnderProcess[tokenID] = TRUE/FALSE;

    mapping(uint256 => Token) public token; // e.g. token[tokenID] => struct Token;
    

    uint256 public tokenApplIDGenerator = 0;
    uint256 public tokenIDGenerator = 0;
    uint256 public constant timeLimit = 300 seconds;
    uint256 public constant lockingAmount = 1000 wei;
 
    event event_payerCanRequestToken(address _receiver, uint256 _tokenApplID); // Is it required?? Yes, because using this event customer can upload the receiver's address and the amount.
    event event_tokenIssued(address _payer, uint256 _tokenID);
    event event_notifyPayerAboutDebitStatus(address _payer, uint256 _tokenID);
    event event_notifyPayeeAboutCreditStatus(address _payee, uint256 _tokenID);
    event event_notifyPayeeToUtilizeToken(address _payee, uint256 _tokenID);
    event event_requestToRefundTokenAmount(address payer, uint256 _issuerBankID, uint256 _tokenID);
    event event_notifyPayerAboutRefundStatus(address _payer, uint256 _tokenID);

    constructor(address _addr_SC_Bank_Registration, address _addr_SC_Customer_Registration) 
    {
        addr_SC_Bank_Registration = _addr_SC_Bank_Registration;
        instance_SC_Bank_Registration = SC_Bank_Registration(addr_SC_Bank_Registration);

        addr_SC_Customer_Registration = _addr_SC_Customer_Registration;
        instance_SC_Customer_Registration = SC_Customer_Registration(addr_SC_Customer_Registration);
    }


    /*****************************************************************************
    Part 1: Token Issuance
    *****************************************************************************/

    /**
    Caller: Payer
    When: To initiate token issuance process towards bank, payer locks its money in the smart contract.
    Previous Function: NA
    **/
    function lockSecurityMoneyByPayer(uint256 _bankID) external payable 
    {
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(instance_SC_Customer_Registration.isCustomerRegisteredToBank(msg.sender, _bankID) == true, "The payer is not registered with this bank!!");
        
        uint256 _latestTokenApplID = latestTokenApplID[msg.sender][_bankID];
        require(tokenApplUnderProcess[_latestTokenApplID] == false, "Previous token application between the payer and the bank is not yet terminated!!");

        require(msg.value == lockingAmount, "Incorrect locking amount!!");

        tokenApplIDGenerator ++;
        _latestTokenApplID = tokenApplIDGenerator;
        latestTokenApplID[msg.sender][_bankID] = _latestTokenApplID;

        TokenAppl memory new_token_appl = tokenIssuanceAppl[_latestTokenApplID];
        new_token_appl.tokenApplID = _latestTokenApplID;
        new_token_appl.payer = msg.sender;
        new_token_appl.issuer_bankID = _bankID;
        new_token_appl.timestamp_lock_security_money_by_payer = block.timestamp;
        tokenIssuanceAppl[_latestTokenApplID] = new_token_appl;

        tokenApplUnderProcess[_latestTokenApplID] = true;
    }

    /**
    Caller: Bank
    When: Once payer locked the money, next the bank also needs to lock the money.
    Previous Function: lockSecurityMoneyByPayer() by payer
    **/
    function lockSecurityMoneyByBank(address _cAddr) external payable 
    {
        uint256 _bankID = instance_SC_Bank_Registration.getBankID(msg.sender);
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(instance_SC_Customer_Registration.isCustomerRegisteredToBank(_cAddr, _bankID) == true, "The customer is not registered with this bank!!");

        uint256 _latestTokenApplID = latestTokenApplID[_cAddr][_bankID];
        require(tokenApplUnderProcess[_latestTokenApplID] == true, "No token application is running at present between the payer and the bank!!");

        require(msg.value == lockingAmount, "Incorrect locking amount!!");
        
        TokenAppl memory new_token_appl = tokenIssuanceAppl[_latestTokenApplID];
        require(new_token_appl.payer == _cAddr, "Intended payer address is not given!!");
        require(new_token_appl.issuer_bankID == _bankID, "You are not holding the intended bankID!!");
        require(new_token_appl.timestamp_lock_security_money_by_payer != 0, "The payer not yet locked its money!!");
        require(new_token_appl.timestamp_lock_security_money_by_issuer_bank == 0, "The issuer bank already locked its money!!");
        //require(tokenApplAborted[_latestTokenApplID] == false, "The current application process is aborted!");
        require((block.timestamp - new_token_appl.timestamp_lock_security_money_by_payer) < timeLimit, "Timelimit exceeded!!");

        new_token_appl.timestamp_lock_security_money_by_issuer_bank = block.timestamp;
        tokenIssuanceAppl[_latestTokenApplID] = new_token_appl;

    }

    /**
    Caller: Payer
    When: Payer shares its card information to the bank offline and puts the commitment of card info onchain.
    Previous Function: lockSecurityMoneyBybank() by bank
    **/
    function commitCardDetails(uint256 _bankID, bytes32 _commitment) external
    {
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(instance_SC_Customer_Registration.isCustomerRegisteredToBank(msg.sender, _bankID) == true, "The payer is not registered with this bank!!");
        
        uint256 _latestTokenApplID = latestTokenApplID[msg.sender][_bankID];
        require(tokenApplUnderProcess[_latestTokenApplID] == true, "Previous token application between the payer and the bank is terminated!!");

        TokenAppl memory new_token_appl = tokenIssuanceAppl[_latestTokenApplID];
        require(new_token_appl.payer == msg.sender, "You are not holding the intended payer address!!");
        require(new_token_appl.issuer_bankID == _bankID, "The given BankID is not the intended one!!");
        require(new_token_appl.timestamp_lock_security_money_by_issuer_bank != 0, "Issuer bank not yet locked the money!!");
        require(new_token_appl.timestamp_card_commitment == 0, "Commitment is already done!");
        //require(tokenApplAborted[_latestTokenApplID] == false, "The current application process is aborted!");
        require((block.timestamp - new_token_appl.timestamp_lock_security_money_by_issuer_bank) < timeLimit, "Timelimit exceeded!!");

        new_token_appl.card_commitment = _commitment;
        new_token_appl.timestamp_card_commitment = block.timestamp;

        tokenIssuanceAppl[_latestTokenApplID] = new_token_appl;
    }

    /**
    Caller: Bank
    When: Once payer committed card info, next the bank provides its first response if the offline received data matches with the commitment.
    Previous Function: commitCardDetails() by payer
    **/
    function checkIfCommitmentMatches(address _cAddr, bool _response1) external
    {
        uint256 _bankID = instance_SC_Bank_Registration.getBankID(msg.sender);
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(instance_SC_Customer_Registration.isCustomerRegisteredToBank(_cAddr, _bankID) == true, "The customer is not registered with this bank!!");

        uint256 _latestTokenApplID = latestTokenApplID[_cAddr][_bankID];
        require(tokenApplUnderProcess[_latestTokenApplID] == true, "No token application is running at present between the payer and the bank!!");

        TokenAppl memory new_token_appl = tokenIssuanceAppl[_latestTokenApplID];
        require(new_token_appl.payer == _cAddr, "Intended payer address is not given!!");
        require(new_token_appl.issuer_bankID == _bankID, "You are not holding the intended bankID!!");
        require(new_token_appl.timestamp_card_commitment != 0, "The payer not yet committed!!");
        require(new_token_appl.timestamp_response1 == 0, "The issuer bank already sent the response1!!");
        //require(tokenApplAborted[_latestTokenApplID] == false, "The current application process is aborted!");
        require((block.timestamp - new_token_appl.timestamp_card_commitment) < timeLimit, "Timelimit exceeded!!");

        new_token_appl.response1 = _response1;
        new_token_appl.timestamp_response1 = block.timestamp;

        if(_response1 == false)
        {
            tokenApplAborted[_latestTokenApplID] = true;
            tokenApplUnderProcess[_latestTokenApplID] = false;

            payable(msg.sender).transfer(lockingAmount);
            payable(_cAddr).transfer(lockingAmount);

            new_token_appl.security_money_received_by_payer = lockingAmount;
            new_token_appl.security_money_received_by_issuer_bank = lockingAmount;
            new_token_appl.timestamp_get_security_money_by_payer = block.timestamp;
            new_token_appl.timestamp_get_security_money_by_issuer_bank = block.timestamp;
        }

        tokenIssuanceAppl[_latestTokenApplID] = new_token_appl;
    }

    /**
    Caller: Bank
    When: Sending response1, the bank checks if the card information is valid and accordingly provides its second response.
    Previous Function: checkIfCommitmentMatches() by bank
    **/
    function checkIfCardValid(address _cAddr, bool _response2) external
    {
        uint256 _bankID = instance_SC_Bank_Registration.getBankID(msg.sender);
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(instance_SC_Customer_Registration.isCustomerRegisteredToBank(_cAddr, _bankID) == true, "The customer is not registered with this bank!!");

        uint256 _latestTokenApplID = latestTokenApplID[_cAddr][_bankID];
        require(tokenApplUnderProcess[_latestTokenApplID] == true, "No token application is running at present between the payer and the bank!!");

        TokenAppl memory new_token_appl = tokenIssuanceAppl[_latestTokenApplID];
        
        require(new_token_appl.payer == _cAddr, "Intended payer address is not given!!");
        require(new_token_appl.issuer_bankID == _bankID, "You are not holding the intended bankID!!");
        require(new_token_appl.timestamp_response1 != 0, "The issuer bank not yet sent the response1!!");
        require(new_token_appl.response1 == true, "You can't call this function as the previous response1 was false!!"); // Missing

        require(new_token_appl.timestamp_response2 == 0, "The issuer bank already sent the response2!!");
        //require(tokenApplAborted[_latestTokenApplID] == false, "The current application process is aborted!"); // Not required
        require((block.timestamp - new_token_appl.timestamp_response1) < timeLimit, "Timelimit exceeded!!");

        new_token_appl.response2 = _response2;
        new_token_appl.timestamp_response2 = block.timestamp;

        if(_response2 == false)
        {
            tokenApplAborted[_latestTokenApplID] = true;
            tokenApplUnderProcess[_latestTokenApplID] = false;

            payable(msg.sender).transfer(lockingAmount);
            payable(_cAddr).transfer(lockingAmount);

            new_token_appl.security_money_received_by_payer = lockingAmount;
            new_token_appl.security_money_received_by_issuer_bank = lockingAmount;
            new_token_appl.timestamp_get_security_money_by_payer = block.timestamp;
            new_token_appl.timestamp_get_security_money_by_issuer_bank = block.timestamp;
        }
        
        tokenIssuanceAppl[_latestTokenApplID] = new_token_appl;
    }

    /**
    Caller: Bank
    When: Sending response2, the bank checks if the card is active at present and accordingly provides its third response.
    Previous Function: checkIfCardValid() by bank
    **/
    function checkIfCardActive(address _cAddr, bool _response3) external
    {
        uint256 _bankID = instance_SC_Bank_Registration.getBankID(msg.sender);
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(instance_SC_Customer_Registration.isCustomerRegisteredToBank(_cAddr, _bankID) == true, "The customer is not registered with this bank!!");

        uint256 _latestTokenApplID = latestTokenApplID[_cAddr][_bankID];
        require(tokenApplUnderProcess[_latestTokenApplID] == true, "No token application is running at present between the payer and the bank!!");

        TokenAppl memory new_token_appl = tokenIssuanceAppl[_latestTokenApplID];
        
        require(new_token_appl.payer == _cAddr, "Intended payer address is not given!!");
        require(new_token_appl.issuer_bankID == _bankID, "You are not holding the intended bankID!!");
        require(new_token_appl.timestamp_response2 != 0, "The issuer bank not yet sent the response2!!");
        require(new_token_appl.response2 == true, "The bank mentioned that the card is invalid!!"); //Missing

        require(new_token_appl.timestamp_response3 == 0, "The issuer bank already sent the response3!!");
        //require(tokenApplAborted[_latestTokenApplID] == false, "The current application process is aborted!"); //Not required
        require((block.timestamp - new_token_appl.timestamp_response2) < timeLimit, "Timelimit exceeded!!");

        new_token_appl.response3 = _response3;
        new_token_appl.timestamp_response3 = block.timestamp;

        if(_response3 == false)
        {
            tokenApplAborted[_latestTokenApplID] = true;
            tokenApplUnderProcess[_latestTokenApplID] = false;

            payable(msg.sender).transfer(lockingAmount);
            payable(_cAddr).transfer(lockingAmount);

            new_token_appl.security_money_received_by_payer = lockingAmount;
            new_token_appl.security_money_received_by_issuer_bank = lockingAmount;
            new_token_appl.timestamp_get_security_money_by_payer = block.timestamp;
            new_token_appl.timestamp_get_security_money_by_issuer_bank = block.timestamp;
        }
        else
        {
            emit event_payerCanRequestToken(_cAddr, _latestTokenApplID);
        }

        tokenIssuanceAppl[_latestTokenApplID] = new_token_appl;
    }

    /**
    Caller: Payer
    When: If response3 is true (i.e. positive), the payer can request to issue a token specifying payee's address and amount
    Previous Function: checkIfCardActive() by bank
    **/
    function requestToken(uint256 _bankID, address _receiver, uint256 _amount) external
    {
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(instance_SC_Customer_Registration.isCustomerRegisteredToBank(msg.sender, _bankID) == true, "The payer is not registered with this bank!!");
        
        uint256 _latestTokenApplID = latestTokenApplID[msg.sender][_bankID];
        require(tokenApplUnderProcess[_latestTokenApplID] == true, "Previous token application between the payer and the bank is terminated!!");

        TokenAppl memory new_token_appl = tokenIssuanceAppl[_latestTokenApplID];

        require(new_token_appl.payer == msg.sender, "You are not holding the intended payer address!!");
        require(new_token_appl.issuer_bankID == _bankID, "The given BankID is not the intended one!!");
        require(new_token_appl.timestamp_response3 != 0, "Issuer bank not yet sent response3!!");
        require(new_token_appl.response3 == true, "The Bank mentioned that the Card is currently inactive!!"); 
        require(new_token_appl.timestamp_requesting_token == 0, "The payer has already requested a token!!");
        require((block.timestamp - new_token_appl.timestamp_response3) < timeLimit, "Timelimit exceeded!!");

        new_token_appl.payee = _receiver;
        new_token_appl.token_amount = _amount;
        new_token_appl.timestamp_requesting_token = block.timestamp;

        tokenIssuanceAppl[_latestTokenApplID] = new_token_appl;
    }

    /**
    Caller: Bank
    When: Next the bank will check the payer's unreserved account balance against the token amount and provides its fourth response.
          If _response4 is true, generate a token with the specified payee's address and amount and notify the same to payer. 
          Also release the locked money to individual parties. 
    Previous Function: requestToken() by payer
    **/
    function checkBalanceAndIssueToken(address _cAddr, bool _response4) external 
    {
        uint256 _bankID = instance_SC_Bank_Registration.getBankID(msg.sender);
        require(instance_SC_Bank_Registration.isBankIDValid(_bankID) == true, "Invalid BankID!!");
        require(instance_SC_Customer_Registration.isCustomerRegisteredToBank(_cAddr, _bankID) == true, "The customer is not registered with this bank!!");

        uint256 _latestTokenApplID = latestTokenApplID[_cAddr][_bankID];
        require(tokenApplUnderProcess[_latestTokenApplID] == true, "No token application is running at present between the payer and the bank!!");

        TokenAppl memory new_token_appl = tokenIssuanceAppl[_latestTokenApplID];
        
        
        require(new_token_appl.payer == _cAddr, "Intended payer address is not given!!");
        require(new_token_appl.issuer_bankID == _bankID, "You are not holding the intended bankID!!");
        require(new_token_appl.timestamp_requesting_token != 0, "The payer not yet requested for token!!");
        require(new_token_appl.timestamp_response4 == 0, "The issuer bank already sent the response4!!");
        require((block.timestamp - new_token_appl.timestamp_requesting_token) < timeLimit, "Timelimit exceeded!!");

        new_token_appl.response4 = _response4;
        new_token_appl.timestamp_response4 = block.timestamp;

        payable(_cAddr).transfer(lockingAmount);
        payable(msg.sender).transfer(lockingAmount);

        new_token_appl.security_money_received_by_payer = lockingAmount;
        new_token_appl.security_money_received_by_issuer_bank = lockingAmount;
        new_token_appl.timestamp_get_security_money_by_payer = block.timestamp;
        new_token_appl.timestamp_get_security_money_by_issuer_bank = block.timestamp;
        
        if(_response4 == true) 
        {
            tokenIDGenerator++;
            uint256 _tokenID = tokenIDGenerator;
            Token memory new_token = token[_tokenID];
            new_token.tokenID = _tokenID;
            new_token.payer = new_token_appl.payer;
            new_token.payee = new_token_appl.payee;
            new_token.issuer_bankID = _bankID;
            new_token.timestamp_issuance_token = block.timestamp;
            token[_tokenID] = new_token;

            emit event_tokenIssued(_cAddr, _tokenID);
        }
        else
        {
            tokenApplAborted[_latestTokenApplID] = true;
        }

        tokenApplUnderProcess[_latestTokenApplID] = false;
        tokenIssuanceAppl[_latestTokenApplID] = new_token_appl;
        
    }

    /*****************************************************************************
    Part 2: Token Execution Sender Side
    *****************************************************************************/

    function initiateTokenExecutionByPayer(uint256 _tokenID, uint256 _issuerBankID) external payable
    {
        require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");
        require(tokenExecutionForPayerUnderProcess[_tokenID] == false, "Token excution for payer corresponding to this tokenID is already under process!!");
        require(msg.value == lockingAmount, "Enter a valid locking amount!!");

        Token memory _token = token[_tokenID];
        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payer == msg.sender, "Mismatched payer address!!");
        require(_token.issuer_bankID == _issuerBankID, "Mismatched Issuer BankID!!");
        require(_token.timestamp_issuance_token != 0, "Token was not issued!!");
        require((block.timestamp - _token.timestamp_issuance_token) <= timeLimit, "Timelimit Exceeded!!");

        tokenExecutionForPayer[_tokenID] = TokenExecutionForPayer(_tokenID,block.timestamp,0,0,0,false,0,0,0,0);

        tokenExecutionForPayerUnderProcess[_tokenID] = true;
        
    }

    function lockSecurityMoneyByIssuerBank(uint256 _tokenID, address _payerAddr) external payable
    {
        require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");
        require(tokenExecutionForPayerUnderProcess[_tokenID] == true, "Token excution for payer corresponding to this tokenID is not under process!!");
        require(msg.value == lockingAmount, "Enter a valid locking amount!!");

        uint256 _issuerBankID = instance_SC_Bank_Registration.getBankID(msg.sender);

        Token memory _token = token[_tokenID];
        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payer == _payerAddr, "Mismatched payer address!!");
        require(_token.issuer_bankID == _issuerBankID, "Mismatched Issuer BankID!!");

        TokenExecutionForPayer memory _tokenExecutionForPayer = tokenExecutionForPayer[_tokenID];

        require(_tokenExecutionForPayer.tokenID == _tokenID, "Mismatched TokenID!!");
        require(_tokenExecutionForPayer.timestamp_lock_security_money_by_payer != 0, "The payer not yet locked the money!!");
        require(_tokenExecutionForPayer.timestamp_lock_security_money_by_issuer_bank == 0, "The issuer bank already locked the money!!");
        require((block.timestamp - _tokenExecutionForPayer.timestamp_lock_security_money_by_payer) <= timeLimit, "Timelimit Exceeded!!");

        _tokenExecutionForPayer.timestamp_lock_security_money_by_issuer_bank = block.timestamp;

        tokenExecutionForPayer[_tokenID] = _tokenExecutionForPayer;
    }

    function askToExecuteTokenByPayer(uint256 _tokenID, uint256 _issuerBankID) external
    {
        require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");
        require(tokenExecutionForPayerUnderProcess[_tokenID] == true, "Token excution for payer corresponding to this tokenID is not under process!!");

        Token memory _token = token[_tokenID];
        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payer == msg.sender, "Mismatched payer address!!");
        require(_token.issuer_bankID == _issuerBankID, "Mismatched Issuer BankID!!");

        TokenExecutionForPayer memory _tokenExecutionForPayer = tokenExecutionForPayer[_tokenID];

        require(_tokenExecutionForPayer.tokenID == _tokenID, "Mismatched TokenID!!");
        require(_tokenExecutionForPayer.timestamp_lock_security_money_by_issuer_bank != 0, "The issuer bank not yet locked the money!!");
        require(_tokenExecutionForPayer.timestamp_execute_token_by_payer == 0, "The payer alreday executed the token.");
        require((block.timestamp - _tokenExecutionForPayer.timestamp_lock_security_money_by_issuer_bank) <= timeLimit, "Timelimit Exceeded!!");

        _tokenExecutionForPayer.timestamp_execute_token_by_payer = block.timestamp;
        
        tokenExecutionForPayer[_tokenID] = _tokenExecutionForPayer;
    }

    function sendConfirmationMessageByIssuerBank(uint256 _tokenID, address _payerAddr, bool _status) external
    {
        require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");
        require(tokenExecutionForPayerUnderProcess[_tokenID] == true, "Token excution for payer corresponding to this tokenID is not under process!!");

        uint256 _issuerBankID = instance_SC_Bank_Registration.getBankID(msg.sender);

        Token memory _token = token[_tokenID];
        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payer == _payerAddr, "Mismatched payer address!!");
        require(_token.issuer_bankID == _issuerBankID, "Mismatched Issuer BankID!!");

        TokenExecutionForPayer memory _tokenExecutionForPayer = tokenExecutionForPayer[_tokenID];

        require(_tokenExecutionForPayer.tokenID == _tokenID, "Mismatched TokenID!!");
        require(_tokenExecutionForPayer.timestamp_execute_token_by_payer != 0, "The payer does not execute the token.");
        require(_tokenExecutionForPayer.timestamp_debit_token_amount == 0, "The issuer bank already confirmed that the token amount was debited from payer's account!!");
        require((block.timestamp - _tokenExecutionForPayer.timestamp_execute_token_by_payer) <= timeLimit, "Timelimit Exceeded!!");

        payable(_payerAddr).transfer(lockingAmount);
        payable(msg.sender).transfer(lockingAmount);

        _tokenExecutionForPayer.timestamp_get_security_money_by_payer = block.timestamp;
        _tokenExecutionForPayer.timestamp_get_security_money_by_issuer_bank = block.timestamp;
        _tokenExecutionForPayer.security_money_received_by_payer = lockingAmount;
        _tokenExecutionForPayer.security_money_received_by_issuer_bank = lockingAmount;
        _tokenExecutionForPayer.transaction_debit_status = _status;

        if(_status == true)
        {
            _tokenExecutionForPayer.timestamp_debit_token_amount = block.timestamp;
            _token.timestamp_debit_token_amount_from_payer = block.timestamp;
            emit event_notifyPayerAboutDebitStatus(_payerAddr, _tokenID);
            emit event_notifyPayeeToUtilizeToken(_token.payee, _tokenID); 
            token[_tokenID] = _token;
        }
        tokenExecutionForPayer[_tokenID] = _tokenExecutionForPayer;

        tokenExecutionForPayerUnderProcess[_tokenID] = false;
    }

    /*****************************************************************************
    Part 3: Token Execution Receiver ide
    *****************************************************************************/

    function initiateTokenExecutionByPayee(uint256 _tokenID, uint256 _acquirerBankID) external payable 
    {
    	require(instance_SC_Bank_Registration.isBankIDValid(_acquirerBankID) == true, "Invalid BankID!!");
        require(instance_SC_Customer_Registration.isCustomerRegisteredToBank(msg.sender, _acquirerBankID) == true, "The payee is not registered with this bank!!");
        
        require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");
        require(tokenExecutionForPayeeUnderProcess[_tokenID] == false, "Token excution for payee corresponding to this tokenID is already under process!!");
        require(msg.value == lockingAmount, "Enter a valid locking amount!!");

        Token memory _token = token[_tokenID];

        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payee == msg.sender, "Mismatched payee address!!");
        require(_token.timestamp_debit_token_amount_from_payer != 0, "Token amount is not yet debited!!");
        require((block.timestamp - _token.timestamp_debit_token_amount_from_payer) <= timeLimit, "Timelimit Exceeded!!");
        
        _token.acquirer_bankID = _acquirerBankID; //Missing!
	    token[_tokenID] = _token; //Missing!
	
        tokenExecutionForPayee[_tokenID] = TokenExecutionForPayee(_tokenID,block.timestamp,0,0,0,false,0,0,0,0); 
        
        tokenExecutionForPayeeUnderProcess[_tokenID] = true;
    }

    function lockSecurityMoneyByAcquirerBank(uint256 _tokenID, address _payeeAddr) external payable 
    {
        require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");
        require(tokenExecutionForPayeeUnderProcess[_tokenID] == true, "Token excution for payee corresponding to this tokenID is not under process!!");
        require(msg.value == lockingAmount, "Enter a valid locking amount!!");

        uint256 _acquirerBankID = instance_SC_Bank_Registration.getBankID(msg.sender);

        Token memory _token = token[_tokenID];
        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payee == _payeeAddr, "Mismatched payee address!!");
        require(_token.acquirer_bankID == _acquirerBankID, "Mismatched Acquirer BankID!!");

        TokenExecutionForPayee memory _tokenExecutionForPayee = tokenExecutionForPayee[_tokenID];

        require(_tokenExecutionForPayee.tokenID == _tokenID, "Mismatched TokenID!!");
        require(_tokenExecutionForPayee.timestamp_lock_security_money_by_payee != 0, "The payee not yet locked the security money!!");
        require(_tokenExecutionForPayee.timestamp_lock_security_money_by_acquirer_bank == 0, "The acquirer bank has already locked the security money!!");
        require((block.timestamp - _tokenExecutionForPayee.timestamp_lock_security_money_by_payee) <= timeLimit, "Timelimit Exceeded!!");

        _tokenExecutionForPayee.timestamp_lock_security_money_by_acquirer_bank = block.timestamp;

        tokenExecutionForPayee[_tokenID] = _tokenExecutionForPayee;   
    }

    function askToExecuteTokenByPayee(uint256 _tokenID, uint256 _acquirerBankID) external 
    {
       require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");
        require(tokenExecutionForPayeeUnderProcess[_tokenID] == true, "Token excution for payee corresponding to this tokenID is not under process!!");

        Token memory _token = token[_tokenID];
        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payee == msg.sender, "Mismatched payee address!!");
        require(_token.acquirer_bankID == _acquirerBankID, "Mismatched Acquirer BankID!!");

        TokenExecutionForPayee memory _tokenExecutionForPayee = tokenExecutionForPayee[_tokenID];

        require(_tokenExecutionForPayee.tokenID == _tokenID, "Mismatched TokenID!!");
        require(_tokenExecutionForPayee.timestamp_lock_security_money_by_acquirer_bank != 0, "The acquirer bank not yet locked the money!!");
        require(_tokenExecutionForPayee.timestamp_execute_token_by_payee == 0, "The payee has already requested to execute the token.");
        require((block.timestamp - _tokenExecutionForPayee.timestamp_lock_security_money_by_acquirer_bank) <= timeLimit, "Timelimit Exceeded!!");

        _tokenExecutionForPayee.timestamp_execute_token_by_payee = block.timestamp;

        tokenExecutionForPayee[_tokenID] = _tokenExecutionForPayee; 
    }

    function sendConfirmationMessageByAcquirerrBank(uint256 _tokenID, address _payeeAddr, bool _status) external
    {
        require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");
        require(tokenExecutionForPayeeUnderProcess[_tokenID] == true, "Token excution for payee corresponding to this tokenID is not under process!!");

        uint256 _acquirerBankID = instance_SC_Bank_Registration.getBankID(msg.sender);

        Token memory _token = token[_tokenID];
        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payee == _payeeAddr, "Mismatched payee address!!");
        require(_token.acquirer_bankID == _acquirerBankID, "Mismatched Issuer BankID!!");

        TokenExecutionForPayee memory _tokenExecutionForPayee = tokenExecutionForPayee[_tokenID];

        require(_tokenExecutionForPayee.tokenID == _tokenID, "Mismatched TokenID!!");
        require(_tokenExecutionForPayee.timestamp_execute_token_by_payee != 0, "The payee not yet requested to execute the token!!");
        require(_tokenExecutionForPayee.timestamp_credit_token_amount == 0, "The acquirer bank already confirmed that the token amount was credited to payee's account!!");
        require((block.timestamp - _tokenExecutionForPayee.timestamp_execute_token_by_payee) <= timeLimit,"Timelimit Exceeds!");
        
        payable(_payeeAddr).transfer(lockingAmount);
        payable(msg.sender).transfer(lockingAmount);

        _tokenExecutionForPayee.timestamp_get_security_money_by_payee = block.timestamp;
        _tokenExecutionForPayee.timestamp_get_security_money_by_acquirer_bank = block.timestamp;
        _tokenExecutionForPayee.security_money_received_by_payee = lockingAmount;
        _tokenExecutionForPayee.security_money_received_by_acquirer_bank = lockingAmount;
        _tokenExecutionForPayee.transaction_credit_status = _status;

        if(_status == true)
        {
            _tokenExecutionForPayee.timestamp_credit_token_amount = block.timestamp;
            _token.timestamp_credit_token_amount_to_payee = block.timestamp;
            emit event_notifyPayeeAboutCreditStatus(_payeeAddr, _tokenID); 
            token[_tokenID] = _token;
        }

        tokenExecutionForPayee[_tokenID] = _tokenExecutionForPayee;

        tokenExecutionForPayeeUnderProcess[_tokenID] = false;  
         
    }

    /**
    If the token amount has been debited from payer's account, but same is not credited to payee's account within timelimit,
    the  payer can claim for refunding/re-credited the token amount to it's account.
    */
    function refundTokenAmountToPayer(uint256 _tokenID, uint256 _issuerBankID) external 
    {
        require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");

        Token memory _token = token[_tokenID];
        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payer == msg.sender, "Mismatched payer address!!");
        require(_token.issuer_bankID == _issuerBankID, "Mismatched Issuer BankID!!");
        require(_token.timestamp_debit_token_amount_from_payer != 0, "Token amount was not debited from payer's account!!");
        require(_token.timestamp_credit_token_amount_to_payee == 0, "Token amount was already credited to payee's account!!");
        require((block.timestamp - _token.timestamp_debit_token_amount_from_payer) > 4*timeLimit, "Time limit not yet exceeded. You have to wait!!");
        require(_token.timestamp_ask_to_refund_token_amount_to_payer == 0, "You have already placed a request to refund the token amount!!");

        _token.timestamp_ask_to_refund_token_amount_to_payer = block.timestamp;
        token[_tokenID] = _token;

        emit event_requestToRefundTokenAmount(msg.sender, _token.issuer_bankID, _tokenID);
    }

    /**
    Issuer bank confirms the refund status onchain by calling this function.
    */
    function confirmRefundStatusByIssuerBank(uint256 _tokenID, address _payerAddr) external
    {
        require(_tokenID > 0 && _tokenID <= tokenIDGenerator, "Invalid TokenID!!");

        uint256 _issuerBankID = instance_SC_Bank_Registration.getBankID(msg.sender);

        Token memory _token = token[_tokenID];
        require(_token.tokenID == _tokenID, "The given tokenID is not the intended one!!");
        require(_token.payer == _payerAddr, "Mismatched payer address!!");
        require(_token.issuer_bankID == _issuerBankID, "Mismatched Issuer BankID!!");
        require(_token.timestamp_ask_to_refund_token_amount_to_payer != 0, "The payer not yet placed refund request!!");
        require(_token.timestamp_refund_token_amount_to_payer == 0, "The issuer bank has already responded regarding the refun amount!!");
        require((block.timestamp - _token.timestamp_ask_to_refund_token_amount_to_payer) <= timeLimit, "Time limit not yet exceeded!!");

        _token.timestamp_refund_token_amount_to_payer = block.timestamp;
        _token.refund_token_amount_to_payer = true;

        token[_tokenID] = _token;

        emit event_notifyPayerAboutRefundStatus(_token.payer, _tokenID);
    }
}

