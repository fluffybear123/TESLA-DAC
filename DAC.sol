/*
This file is part of TESLA-DAC® 



TESLA-DAC® is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

TESLA-DAC® is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with TESLA-DAC®.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
Standard smart contract for a Decentralized Autonomous Corporation (DAC)
to automate organizational governance and decision-making.
*/

import "./TokenCreation.sol";
import "./ManagedAccount.sol";

contract DACInterface {

    // The amount of days for which people who try to participate in the
    // creation by calling the fallback function will still get their ether back
    uint constant creationGracePeriod = 40 days;
    // The minimum debate period that a generic proposal can have
    uint constant minProposalDebatePeriod = 2 weeks;
    // The minimum debate period that a split proposal can have
    uint constant minSplitDebatePeriod = 1 weeks;
    // Period of days inside which it's possible to execute a DAC split
    uint constant splitExecutionPeriod = 27 days;
    // Period of time after which the minimum Quorum is halved
    uint constant quorumHalvingPeriod = 25 weeks;
    // Period after which a proposal is closed
    // (used in the case `executeProposal` fails because it throws)
    uint constant executeProposalPeriod = 10 days;
    // Denotes the maximum proposal deposit that can be given. It is given as
    // a fraction of total Ether spent plus balance of TESLA-DAC®
    uint constant maxDepositDivisor = 100;

    // Proposals to spend TESLA-DAC®'s ether or to choose a new Curator
    Proposal[] public proposals;
    // The quorum needed for each proposal is partially calculated by
    // totalSupply / minQuorumDivisor
    uint public minQuorumDivisor;
    // The unix time of the last time quorum was reached on a proposal
    uint public lastTimeMinQuorumMet;

    // Address of the curator
    address public curator;
    // The whitelist: List of addresses TESLA-DAC® is allowed to send ether to
    mapping (address => bool) public allowedRecipients;

    // Tracks the addresses that own Reward Tokens. Those addresses can only be
    // DACs that have split from the original TESLA-DAC®. Conceptually, Reward Tokens
    // represent the proportion of the rewards that TESLA-DAC® has the right to
    // receive. These Reward Tokens are generated when TESLA-DAC® spends ether.
    mapping (address => uint) public rewardToken;
    // Total supply of rewardToken
    uint public totalRewardToken;

    // The account used to manage the rewards which are to be distributed to the
    // DAC Token Holders of TESLA-DAC®
    ManagedAccount public rewardAccount;

    // The account used to manage the rewards which are to be distributed to
    // any DAC that holds Reward Tokens
    ManagedAccount public DACrewardAccount;

    // Amount of rewards (in wei) already paid out to a certain DAC
    mapping (address => uint) public DACpaidOut;

    // Amount of rewards (in wei) already paid out to a certain address
    mapping (address => uint) public paidOut;
    // Map of addresses blocked during a vote (not allowed to transfer DAC
    // tokens). The address points to the proposal ID.
    mapping (address => uint) public blocked;

    // The minimum deposit (in wei) required to submit any proposal that is not
    // requesting a new Curator (no deposit is required for splits)
    uint public proposalDeposit;

    // the accumulated sum of all current proposal deposits
    uint sumOfProposalDeposits;

    // Contract that is able to create a new DAC (with the same code as
    // this one), used for splits
    DAC_Creator public dacCreator;

    // A proposal with `newCurator == false` represents a transaction
    // to be issued by this DAC
    // A proposal with `newCurator == true` represents a DAC split
    struct Proposal {
        // The address where the `amount` will go to if the proposal is accepted
        // or if `newCurator` is true, the proposed Curator of
        // the new DAC).
        address recipient;
        // The amount to transfer to `recipient` if the proposal is accepted.
        uint amount;
        // A plain text description of the proposal
        string description;
        // A unix timestamp, denoting the end of the voting period
        uint votingDeadline;
        // True if the proposal's votes have yet to be counted, otherwise False
        bool open;
        // True if quorum has been reached, the votes have been counted, and
        // the majority said yes
        bool proposalPassed;
        // A hash to check validity of a proposal
        bytes32 proposalHash;
        // Deposit in wei the creator added when submitting their proposal. It
        // is taken from the msg.value of a newProposal call.
        uint proposalDeposit;
        // True if this proposal is to assign a new Curator
        bool newCurator;
        // Data needed for splitting TESLA-DAC®
        SplitData[] splitData;
        // Number of Tokens in favor of the proposal
        uint yea;
        // Number of Tokens opposed to the proposal
        uint nay;
        // Simple mapping to check if a shareholder has voted for it
        mapping (address => bool) votedYes;
        // Simple mapping to check if a shareholder has voted against it
        mapping (address => bool) votedNo;
        // Address of the shareholder who created the proposal
        address creator;
    }

    // Used only in the case of a newCurator proposal.
    struct SplitData {
        // The balance of the current DAC minus the deposit at the time of split
        uint splitBalance;
        // The total amount of DAC Tokens in existence at the time of split.
        uint totalSupply;
        // Amount of Reward Tokens owned by TESLA-DAC® at the time of split.
        uint rewardToken;
        // The new DAC contract created at the time of split.
        DAC newDAC;
    }

    // Used to restrict access to certain functions to only DAC Token Holders
    modifier onlyTokenholders {}

    /// @dev Constructor setting the Curator and the address
    /// for the contract able to create another DAC as well as the parameters
    /// for TESLA-DAC® Token Creation
    /// @param _curator The Curator
    /// @param _dacCreator The contract able to (re)create this DAC
    /// @param _proposalDeposit The deposit to be paid for a regular proposal
    /// @param _minTokensToCreate Minimum required wei-equivalent tokens
    ///        to be created for a successful DAC Token Creation
    /// @param _closingTime Date (in Unix time) of the end of TESLA-DAC® Token Creation
    /// @param _privateCreation If zero TESLA-DAC® Token Creation is open to public, a
    /// non-zero address means that the DAC Token Creation is only for the address
    /// @param _tokenName The name that the DAC's token will have
    /// @param _tokenSymbol The ticker symbol that this DAC token should have
    /// @param _decimalPlaces The number of decimal places that the token is
    ///        counted from.
    // This is the constructor: it can not be overloaded so it is commented out
    //  function DAC(
        //  address _curator,
        //  DAC_Creator _dacCreator,
        //  uint _proposalDeposit,
        //  uint _minTokensToCreate,
        //  uint _closingTime,
        //  address _privateCreation
        //  string _tokenName,
        //  string _tokenSymbol,
        //  uint8 _decimalPlaces
    //  );

    /// @notice Create Token with `msg.sender` as the beneficiary
    /// @return Whether the token creation was successful
    function () returns (bool success);


    /// @dev This function is used to send ether back
    /// to TESLA-DAC®, it can also be used to receive payments that should not be
    /// counted as rewards (donations, grants, etc.)
    /// @return Whether TESLA-DAC® received the ether successfully
    function receiveEther() returns(bool);

    /// @notice `msg.sender` creates a proposal to send `_amount` Wei to
    /// `_recipient` with the transaction data `_transactionData`. If
    /// `_newCurator` is true, then this is a proposal that splits the
    ///  and sets `_recipient` as the new DAC's Curator.
    /// @param _recipient Address of the recipient of the proposed transaction
    /// @param _amount Amount of wei to be sent with the proposed transaction
    /// @param _description String describing the proposal
    /// @param _transactionData Data of the proposed transaction
    /// @param _debatingPeriod Time used for debating a proposal, at least 2
    /// weeks for a regular proposal, 10 days for new Curator proposal
    /// @param _newCurator Bool defining whether this proposal is about
    /// a new Curator or not
    /// @return The proposal ID. Needed for voting on the proposal
    function newProposal(
        address _recipient,
        uint _amount,
        string _description,
        bytes _transactionData,
        uint _debatingPeriod,
        bool _newCurator
    ) onlyTokenholders returns (uint _proposalID);

    /// @notice Check that the proposal with the ID `_proposalID` matches the
    /// transaction which sends `_amount` with data `_transactionData`
    /// to `_recipient`
    /// @param _proposalID The proposal ID
    /// @param _recipient The recipient of the proposed transaction
    /// @param _amount The amount of wei to be sent in the proposed transaction
    /// @param _transactionData The data of the proposed transaction
    /// @return Whether the proposal ID matches the transaction data or not
    function checkProposalCode(
        uint _proposalID,
        address _recipient,
        uint _amount,
        bytes _transactionData
    ) constant returns (bool _codeChecksOut);

    /// @notice Vote on proposal `_proposalID` with `_supportsProposal`
    /// @param _proposalID The proposal ID
    /// @param _supportsProposal Yes/No - support of the proposal
    function vote(uint _proposalID, bool _supportsProposal);

    /// @notice Checks whether proposal `_proposalID` with transaction data
    /// `_transactionData` has been voted for or rejected, and executes the
    /// transaction in the case it has been voted for.
    /// @param _proposalID The proposal ID
    /// @param _transactionData The data of the proposed transaction
    /// @return Whether the proposed transaction has been executed or not
    function executeProposal(
        uint _proposalID,
        bytes _transactionData
    ) returns (bool _success);

    /// @notice ATTENTION! I confirm to move my remaining ether to a new DAC
    /// with `_newCurator` as the new Curator, as has been
    /// proposed in proposal `_proposalID`. This will burn my tokens. This can
    /// not be undone and will split TESLA-DAC® into two DAC's, with two
    /// different underlying tokens.
    /// @param _proposalID The proposal ID
    /// @param _newCurator The new Curator of the new DAC
    /// @dev This function, when called for the first time for this proposal,
    /// will create a new DAC and send the sender's portion of the remaining
    /// ether and Reward Tokens to the new DAC. It will also burn TESLA-DAC® Tokens
    /// of the sender.
    function splitDAC(
        uint _proposalID,
        address _newCurator
    ) returns (bool _success);

    /// @dev can only be called by TESLA-DAC® itself through a proposal
    /// updates the contract of TESLA-DAC® by sending all ether and rewardTokens
    /// to the new DAC. The new DAC needs to be approved by the Curator
    /// @param _newContract the address of the new contract
    function newContract(address _newContract);


    /// @notice Add a new possible recipient `_recipient` to the whitelist so
    /// that TESLA-DAC® can send transactions to them (using proposals)
    /// @param _recipient New recipient address
    /// @dev Can only be called by the current Curator
    /// @return Whether successful or not
    function changeAllowedRecipients(address _recipient, bool _allowed) external returns (bool _success);


    /// @notice Change the minimum deposit required to submit a proposal
    /// @param _proposalDeposit The new proposal deposit
    /// @dev Can only be called by this DAC (through proposals with the
    /// recipient being this DAC itself)
    function changeProposalDeposit(uint _proposalDeposit) external;

    /// @notice Move rewards from the DACRewards managed account
    /// @param _toMembers If true rewards are moved to the actual reward account
    ///                   for TESLA-DAC®. If not then it's moved to the DAC itself
    /// @return Whether the call was successful
    function retrieveDACReward(bool _toMembers) external returns (bool _success);

    /// @notice Get my portion of the reward that was sent to `rewardAccount`
    /// @return Whether the call was successful
    function getMyReward() returns(bool _success);

    /// @notice Withdraw `_account`'s portion of the reward from `rewardAccount`
    /// to `_account`'s balance
    /// @return Whether the call was successful
    function withdrawRewardFor(address _account) internal returns (bool _success);

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`. Prior to this
    /// getMyReward() is called.
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transfered
    /// @return Whether the transfer was successful or not
    function transferWithoutReward(address _to, uint256 _amount) returns (bool success);

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    /// is approved by `_from`. Prior to this getMyReward() is called.
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transfered
    /// @return Whether the transfer was successful or not
    function transferFromWithoutReward(
        address _from,
        address _to,
        uint256 _amount
    ) returns (bool success);

    /// @notice Doubles the 'minQuorumDivisor' in the case quorum has not been
    /// achieved in 52 weeks
    /// @return Whether the change was successful or not
    function halveMinQuorum() returns (bool _success);

    /// @return total number of proposals ever created
    function numberOfProposals() constant returns (uint _numberOfProposals);

    /// @param _proposalID Id of the new curator proposal
    /// @return Address of the new DAC
    function getNewDACAddress(uint _proposalID) constant returns (address _newDAC);

    /// @param _account The address of the account which is checked.
    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.
    function isBlocked(address _account) internal returns (bool);

    /// @notice If the caller is blocked by a proposal whose voting deadline
    /// has exprired then unblock him.
    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.
    function unblockMe() returns (bool);

    event ProposalAdded(
        uint indexed proposalID,
        address recipient,
        uint amount,
        bool newCurator,
        string description
    );
    event Voted(uint indexed proposalID, bool position, address indexed voter);
    event ProposalTallied(uint indexed proposalID, bool result, uint quorum);
    event NewCurator(address indexed _newCurator);
    event AllowedRecipientChanged(address indexed _recipient, bool _allowed);
}

// TESLA-DAC® contract itself
contract DAC is DACInterface, Token, TokenCreation {

    // Modifier that allows only shareholders to vote and create new proposals
    modifier onlyTokenholders {
        if (balanceOf(msg.sender) == 0) throw;
            _
    }

    function DAC(
        address _curator,
        DAC_Creator _dacCreator,
        uint _proposalDeposit,
        uint _minTokensToCreate,
        uint _closingTime,
        address _privateCreation,
        string _tokenName, 
        string _tokenSymbol,
        uint8 _decimalPlaces
    ) TokenCreation(
        _minTokensToCreate, 
        _closingTime, 
        _privateCreation, 
        _tokenName, 
        _tokenSymbol,
        _decimalPlaces) {

        curator = _curator;
        dacCreator = _dacCreator;
        proposalDeposit = _proposalDeposit;
        rewardAccount = new ManagedAccount(address(this), false);
        DACrewardAccount = new ManagedAccount(address(this), false);
        if (address(rewardAccount) == 0)
            throw;
        if (address(DACrewardAccount) == 0)
            throw;
        lastTimeMinQuorumMet = now;
        minQuorumDivisor = 5; // sets the minimal quorum to 20%
        proposals.length = 1; // avoids a proposal with ID 0 because it is used

        allowedRecipients[address(this)] = true;
        allowedRecipients[curator] = true;
    }

    function () returns (bool success) {
        if (now < closingTime + creationGracePeriod && msg.sender != address(extraBalance))
            return createTokenProxy(msg.sender);
        else
            return receiveEther();
    }


    function receiveEther() returns (bool) {
        return true;
    }


    function newProposal(
        address _recipient,
        uint _amount,
        string _description,
        bytes _transactionData,
        uint _debatingPeriod,
        bool _newCurator
    ) onlyTokenholders returns (uint _proposalID) {

        // Sanity check
        if (_newCurator && (
            _amount != 0
            || _transactionData.length != 0
            || _recipient == curator
            || msg.value > 0
            || _debatingPeriod < minSplitDebatePeriod)) {
            throw;
        } else if (
            !_newCurator
            && (!isRecipientAllowed(_recipient) || (_debatingPeriod <  minProposalDebatePeriod))
        ) {
            throw;
        }

        if (_debatingPeriod > 8 weeks)
            throw;

        if (!isFueled
            || now < closingTime
            || (msg.value < proposalDeposit && !_newCurator)) {

            throw;
        }

        if (now + _debatingPeriod < now) // prevents overflow
            throw;

        // to prevent a 51% attacker to convert the ether into deposit
        if (msg.sender == address(this))
            throw;

        // to prevent curator from halving quorum before first proposal
        if (proposals.length == 1) // initial length is 1 (see constructor)
            lastTimeMinQuorumMet = now;

        _proposalID = proposals.length++;
        Proposal p = proposals[_proposalID];
        p.recipient = _recipient;
        p.amount = _amount;
        p.description = _description;
        p.proposalHash = sha3(_recipient, _amount, _transactionData);
        p.votingDeadline = now + _debatingPeriod;
        p.open = true;
        //p.proposalPassed = False; // that's default
        p.newCurator = _newCurator;
        if (_newCurator)
            p.splitData.length++;
        p.creator = msg.sender;
        p.proposalDeposit = msg.value;

        sumOfProposalDeposits += msg.value;

        ProposalAdded(
            _proposalID,
            _recipient,
            _amount,
            _newCurator,
            _description
        );
    }


    function checkProposalCode(
        uint _proposalID,
        address _recipient,
        uint _amount,
        bytes _transactionData
    ) noEther constant returns (bool _codeChecksOut) {
        Proposal p = proposals[_proposalID];
        return p.proposalHash == sha3(_recipient, _amount, _transactionData);
    }


    function vote(uint _proposalID, bool _supportsProposal) onlyTokenholders noEther {

        Proposal p = proposals[_proposalID];
        if (p.votedYes[msg.sender]
            || p.votedNo[msg.sender]
            || now >= p.votingDeadline) {

            throw;
        }

        if (_supportsProposal) {
            p.yea += balances[msg.sender];
            p.votedYes[msg.sender] = true;
        } else {
            p.nay += balances[msg.sender];
            p.votedNo[msg.sender] = true;
        }

        if (blocked[msg.sender] == 0) {
            blocked[msg.sender] = _proposalID;
        } else if (p.votingDeadline > proposals[blocked[msg.sender]].votingDeadline) {
            // this proposal's voting deadline is further into the future than
            // the proposal that blocks the sender so make it the blocker
            blocked[msg.sender] = _proposalID;
        }

        Voted(_proposalID, _supportsProposal, msg.sender);
    }


    function executeProposal(
        uint _proposalID,
        bytes _transactionData
    ) noEther returns (bool _success) {

        Proposal p = proposals[_proposalID];

        uint waitPeriod = p.newCurator
            ? splitExecutionPeriod
            : executeProposalPeriod;
        // If we are over deadline and waiting period, assert proposal is closed
        if (p.open && now > p.votingDeadline + waitPeriod) {
            closeProposal(_proposalID);
            return;
        }

        // Check if the proposal can be executed
        if (now < p.votingDeadline  // has the voting deadline arrived?
            // Have the votes been counted?
            || !p.open
            || p.proposalPassed // anyone trying to call us recursively?
            // Does the transaction code match the proposal?
            || p.proposalHash != sha3(p.recipient, p.amount, _transactionData)) {

            throw;
        }

        // If the curator removed the recipient from the whitelist, close the proposal
        // in order to free the deposit and allow unblocking of voters
        if (!isRecipientAllowed(p.recipient)) {
            closeProposal(_proposalID);
            p.creator.send(p.proposalDeposit);
            return;
        }

        bool proposalCheck = true;

        if (p.amount > actualBalance())
            proposalCheck = false;

        uint quorum = p.yea + p.nay;

        // require 53% for calling newContract()
        if (_transactionData.length >= 4 && _transactionData[0] == 0x68
            && _transactionData[1] == 0x37 && _transactionData[2] == 0xff
            && _transactionData[3] == 0x1e
            && quorum < minQuorum(actualBalance() + rewardToken[address(this)])) {

                proposalCheck = false;
        }

        if (quorum >= minQuorum(p.amount)) {
            if (!p.creator.send(p.proposalDeposit))
                throw;

            lastTimeMinQuorumMet = now;
            // set the minQuorum to 20% again, in the case it has been reached
            if (quorum > totalSupply / 5)
                minQuorumDivisor = 5;
        }

        // Execute result
        if (quorum >= minQuorum(p.amount) && p.yea > p.nay && proposalCheck) {
            // we are setting this here before the CALL() value transfer to
            // assure that in the case of a malicious recipient contract trying
            // to call executeProposal() recursively money can't be transferred
            // multiple times out of TESLA-DAC®
            p.proposalPassed = true;

            if (!p.recipient.call.value(p.amount)(_transactionData))
                throw;

            _success = true;

            // only create reward tokens when ether is not sent to TESLA-DAC® itself and
            // related addresses. Proxy addresses should be forbidden by the curator.
            if (p.recipient != address(this) && p.recipient != address(rewardAccount)
                && p.recipient != address(DACrewardAccount)
                && p.recipient != address(extraBalance)
                && p.recipient != address(curator)) {

                rewardToken[address(this)] += p.amount;
                totalRewardToken += p.amount;
            }
        }

        closeProposal(_proposalID);

        // Initiate event
        ProposalTallied(_proposalID, _success, quorum);
    }


    function closeProposal(uint _proposalID) internal {
        Proposal p = proposals[_proposalID];
        if (p.open)
            sumOfProposalDeposits -= p.proposalDeposit;
        p.open = false;
    }

    function splitDAC(
        uint _proposalID,
        address _newCurator
    ) noEther onlyTokenholders returns (bool _success) {

        Proposal p = proposals[_proposalID];

        // Sanity check

        if (now < p.votingDeadline  // has the voting deadline arrived?
            //The request for a split expires XX days after the voting deadline
            || now > p.votingDeadline + splitExecutionPeriod
            // Does the new Curator address match?
            || p.recipient != _newCurator
            // Is it a new curator proposal?
            || !p.newCurator
            // Have you voted for this split?
            || !p.votedYes[msg.sender]
            // Did you already vote on another proposal?
            || (blocked[msg.sender] != _proposalID && blocked[msg.sender] != 0) )  {

            throw;
        }

        // If the new DAC doesn't exist yet, create the new DAC and store the
        // current split data
        if (address(p.splitData[0].newDAC) == 0) {
            p.splitData[0].newDAC = createNewDAC(_newCurator);
            // Call depth limit reached, etc.
            if (address(p.splitData[0].newDAC) == 0)
                throw;
            // should never happen
            if (this.balance < sumOfProposalDeposits)
                throw;
            p.splitData[0].splitBalance = actualBalance();
            p.splitData[0].rewardToken = rewardToken[address(this)];
            p.splitData[0].totalSupply = totalSupply;
            p.proposalPassed = true;
        }

        // Move ether and assign new Tokens
        uint fundsToBeMoved =
            (balances[msg.sender] * p.splitData[0].splitBalance) /
            p.splitData[0].totalSupply;
        if (p.splitData[0].newDAC.createTokenProxy.value(fundsToBeMoved)(msg.sender) == false)
            throw;


        // Assign reward rights to new DAC
        uint rewardTokenToBeMoved =
            (balances[msg.sender] * p.splitData[0].rewardToken) /
            p.splitData[0].totalSupply;

        uint paidOutToBeMoved = DACpaidOut[address(this)] * rewardTokenToBeMoved /
            rewardToken[address(this)];

        rewardToken[address(p.splitData[0].newDAC)] += rewardTokenToBeMoved;
        if (rewardToken[address(this)] < rewardTokenToBeMoved)
            throw;
        rewardToken[address(this)] -= rewardTokenToBeMoved;

        DACpaidOut[address(p.splitData[0].newDAC)] += paidOutToBeMoved;
        if (DACpaidOut[address(this)] < paidOutToBeMoved)
            throw;
        DACpaidOut[address(this)] -= paidOutToBeMoved;

        // Burn DAC Tokens
        Transfer(msg.sender, 0, balances[msg.sender]);
        withdrawRewardFor(msg.sender); // be nice, and get his rewards
        totalSupply -= balances[msg.sender];
        balances[msg.sender] = 0;
        paidOut[msg.sender] = 0;
        return true;
    }

    function newContract(address _newContract){
        if (msg.sender != address(this) || !allowedRecipients[_newContract]) return;
        // move all ether
        if (!_newContract.call.value(address(this).balance)()) {
            throw;
        }

        //move all reward tokens
        rewardToken[_newContract] += rewardToken[address(this)];
        rewardToken[address(this)] = 0;
        DACpaidOut[_newContract] += DACpaidOut[address(this)];
        DACpaidOut[address(this)] = 0;
    }


    function retrieveDACReward(bool _toMembers) external noEther returns (bool _success) {
        DAC dac = DAC(msg.sender);

        if ((rewardToken[msg.sender] * DACrewardAccount.accumulatedInput()) /
            totalRewardToken < DACpaidOut[msg.sender])
            throw;

        uint reward =
            (rewardToken[msg.sender] * DACrewardAccount.accumulatedInput()) /
            totalRewardToken - DACpaidOut[msg.sender];

        reward = DACrewardAccount.balance < reward ? DACrewardAccount.balance : reward;

        if(_toMembers) {
            if (!DACrewardAccount.payOut(dac.rewardAccount(), reward))
                throw;
            }
        else {
            if (!DACrewardAccount.payOut(dac, reward))
                throw;
        }
        DACpaidOut[msg.sender] += reward;
        return true;
    }

    function getMyReward() noEther returns (bool _success) {
        return withdrawRewardFor(msg.sender);
    }


    function withdrawRewardFor(address _account) noEther internal returns (bool _success) {
        if ((balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply < paidOut[_account])
            throw;

        uint reward =
            (balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply - paidOut[_account];

        reward = rewardAccount.balance < reward ? rewardAccount.balance : reward;

        paidOut[_account] += reward;
        if (!rewardAccount.payOut(_account, reward))
            throw;

        return true;
    }


    function transfer(address _to, uint256 _value) returns (bool success) {
        if (isFueled
            && now > closingTime
            && !isBlocked(msg.sender)
            && !isBlocked(_to)
            && _to != address(this)
            && transferPaidOut(msg.sender, _to, _value)
            && super.transfer(_to, _value)) {

            return true;
        } else {
            throw;
        }
    }


    function transferWithoutReward(address _to, uint256 _value) returns (bool success) {
        if (!getMyReward())
            throw;
        return transfer(_to, _value);
    }


    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (isFueled
            && now > closingTime
            && !isBlocked(_from)
            && !isBlocked(_to)
            && _to != address(this)
            && transferPaidOut(_from, _to, _value)
            && super.transferFrom(_from, _to, _value)) {

            return true;
        } else {
            throw;
        }
    }


    function transferFromWithoutReward(
        address _from,
        address _to,
        uint256 _value
    ) returns (bool success) {

        if (!withdrawRewardFor(_from))
            throw;
        return transferFrom(_from, _to, _value);
    }


    function transferPaidOut(
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool success) {

        uint transferPaidOut = paidOut[_from] * _value / balanceOf(_from);
        if (transferPaidOut > paidOut[_from])
            throw;
        paidOut[_from] -= transferPaidOut;
        paidOut[_to] += transferPaidOut;
        return true;
    }


    function changeProposalDeposit(uint _proposalDeposit) noEther external {
        if (msg.sender != address(this) || _proposalDeposit > (actualBalance() + rewardToken[address(this)])
            / maxDepositDivisor) {

            throw;
        }
        proposalDeposit = _proposalDeposit;
    }


    function changeAllowedRecipients(address _recipient, bool _allowed) noEther external returns (bool _success) {
        if (msg.sender != curator)
            throw;
        allowedRecipients[_recipient] = _allowed;
        AllowedRecipientChanged(_recipient, _allowed);
        return true;
    }


    function isRecipientAllowed(address _recipient) internal returns (bool _isAllowed) {
        if (allowedRecipients[_recipient]
            || (_recipient == address(extraBalance)
                // only allowed when at least the amount held in the
                // extraBalance account has been spent from TESLA-DAC®
                && totalRewardToken > extraBalance.accumulatedInput()))
            return true;
        else
            return false;
    }

    function actualBalance() constant returns (uint _actualBalance) {
        return this.balance - sumOfProposalDeposits;
    }


    function minQuorum(uint _value) internal constant returns (uint _minQuorum) {
        // minimum of 20% and maximum of 53.33%
        return totalSupply / minQuorumDivisor +
            (_value * totalSupply) / (3 * (actualBalance() + rewardToken[address(this)]));
    }


    function halveMinQuorum() returns (bool _success) {
        // this can only be called after `quorumHalvingPeriod` has passed or at anytime after
        // fueling by the curator with a delay of at least `minProposalDebatePeriod`
        // between the calls
        if ((lastTimeMinQuorumMet < (now - quorumHalvingPeriod) || msg.sender == curator)
            && lastTimeMinQuorumMet < (now - minProposalDebatePeriod)
            && now >= closingTime
            && proposals.length > 1) {
            lastTimeMinQuorumMet = now;
            minQuorumDivisor *= 2;
            return true;
        } else {
            return false;
        }
    }

    function createNewDAC(address _newCurator) internal returns (DAC _newDAC) {
        NewCurator(_newCurator);
        return dacCreator.createDAC(
            _newCurator,
            0,
            0,
            now + splitExecutionPeriod,
            name,
            symbol,
            decimals
        );
    }

    function numberOfProposals() constant returns (uint _numberOfProposals) {
        // Don't count index 0. It's used by isBlocked() and exists from start
        return proposals.length - 1;
    }

    function getNewDACAddress(uint _proposalID) constant returns (address _newDAC) {
        return proposals[_proposalID].splitData[0].newDAC;
    }

    function isBlocked(address _account) internal returns (bool) {
        if (blocked[_account] == 0)
            return false;
        Proposal p = proposals[blocked[_account]];
        if (now > p.votingDeadline) {
            blocked[_account] = 0;
            return false;
        } else {
            return true;
        }
    }

    function unblockMe() returns (bool) {
        return isBlocked(msg.sender);
    }
}

contract DAC_Creator {
    function createDAC(
        address _curator,
        uint _proposalDeposit,
        uint _minTokensToCreate,
        uint _closingTime,
        string _tokenName, 
        string _tokenSymbol,
        uint8 _decimalPlaces
    ) returns (DAC _newDAC) {

        return new DAC(
            _curator,
            DAC_Creator(this),
            _proposalDeposit,
            _minTokensToCreate,
            _closingTime,
            msg.sender,
            _tokenName, 
            _tokenSymbol,
            _decimalPlaces
        );
    }
}
