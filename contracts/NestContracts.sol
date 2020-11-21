pragma solidity 0.6.0;

import "./Lib/Address.sol";
import "./Lib/SafeMath.sol";
import "./Lib/AddressPayable.sol";
import "./Lib/SafeERC20.sol";

/**
 * @title NToken contract 
 * @dev Include standard erc20 method, mining method, and mining data 
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

//  Executable contract
interface Nest_3_Implement {
    //  Execute
    function doit() external;
}

// NestNode assignment contract
interface Nest_NodeAssignment {
    function bookKeeping(uint256 amount) external;
}

/**
 * @title Voting factory + mapping
 * @dev Vote creating method
 */
contract Nest_3_VoteFactory {
    using SafeMath for uint256;
    
    uint256 _limitTime = 7 days;                                    //  Vote duration
    uint256 _NNLimitTime = 1 days;                                  //  NestNode raising time
    uint256 _circulationProportion = 51;                            //  Proportion of votes to pass
    uint256 _NNUsedCreate = 10;                                     //  The minimum number of NNs to create a voting contract
    uint256 _NNCreateLimit = 100;                                   //  The minimum number of NNs needed to start voting
    uint256 _emergencyTime = 0;                                     //  The emergency state start time
    uint256 _emergencyTimeLimit = 3 days;                           //  The emergency state duration
    uint256 _emergencyNNAmount = 1000;                              //  The number of NNs required to switch the emergency state
    ERC20 _NNToken;                                                 //  NestNode Token
    ERC20 _nestToken;                                               //  NestToken
    mapping(string => address) _contractAddress;                    //  Voting contract mapping
    mapping(address => bool) _modifyAuthority;                      //  Modify permissions
    mapping(address => address) _myVote;                            //  Personal voting address
    mapping(address => uint256) _emergencyPerson;                   //  Emergency state personal voting number
    mapping(address => bool) _contractData;                         //  Voting contract data
    bool _stateOfEmergency = false;                                 //  Emergency state
    address _destructionAddress;                                    //  Destroy contract address

    event ContractAddress(address contractAddress);
    
    /**
    * @dev Initialization method
    */
    constructor () public {
        _modifyAuthority[address(msg.sender)] = true;
    }
    
    /**
    * @dev Reset contract
    */
    function changeMapping() public onlyOwner {
        _NNToken = ERC20(checkAddress("nestNode"));
        _destructionAddress = address(checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(checkAddress("nest")));
    }
    
    /**
    * @dev Create voting contract
    * @param implementContract The executable contract address for voting
    * @param nestNodeAmount Number of NNs to pledge
    */
    function createVote(address implementContract, uint256 nestNodeAmount) public {
        require(address(tx.origin) == address(msg.sender), "It can't be a contract");
        require(nestNodeAmount >= _NNUsedCreate);
        Nest_3_VoteContract newContract = new Nest_3_VoteContract(implementContract, _stateOfEmergency, nestNodeAmount);
        require(_NNToken.transferFrom(address(tx.origin), address(newContract), nestNodeAmount), "Authorization transfer failed");
        _contractData[address(newContract)] = true;
        emit ContractAddress(address(newContract));
    }
    
    /**
    * @dev Use NEST to vote
    * @param contractAddress Vote contract address
    */
    function nestVote(address contractAddress) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(_contractData[contractAddress], "It's not a voting contract");
        require(!checkVoteNow(address(msg.sender)));
        Nest_3_VoteContract newContract = Nest_3_VoteContract(contractAddress);
        newContract.nestVote();
        _myVote[address(tx.origin)] = contractAddress;
    }
    
    /**
    * @dev Vote using NestNode Token
    * @param contractAddress Vote contract address
    * @param NNAmount Amount of NNs to pledge
    */
    function nestNodeVote(address contractAddress, uint256 NNAmount) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(_contractData[contractAddress], "It's not a voting contract");
        Nest_3_VoteContract newContract = Nest_3_VoteContract(contractAddress);
        require(_NNToken.transferFrom(address(tx.origin), address(newContract), NNAmount), "Authorization transfer failed");
        newContract.nestNodeVote(NNAmount);
    }
    
    /**
    * @dev Excecute contract
    * @param contractAddress Vote contract address
    */
    function startChange(address contractAddress) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(_contractData[contractAddress], "It's not a voting contract");
        Nest_3_VoteContract newContract = Nest_3_VoteContract(contractAddress);
        require(_stateOfEmergency == newContract.checkStateOfEmergency());
        addSuperManPrivate(address(newContract));
        newContract.startChange();
        deleteSuperManPrivate(address(newContract));
    }
    
    /**
    * @dev Switch emergency state-transfer in NestNode Token
    * @param amount Amount of NNs to transfer
    */
    function sendNestNodeForStateOfEmergency(uint256 amount) public {
        require(_NNToken.transferFrom(address(tx.origin), address(this), amount));
        _emergencyPerson[address(tx.origin)] = _emergencyPerson[address(tx.origin)].add(amount);
    }
    
    /**
    * @dev Switch emergency state-transfer out NestNode Token
    */
    function turnOutNestNodeForStateOfEmergency() public {
        require(_emergencyPerson[address(tx.origin)] > 0);
        require(_NNToken.transfer(address(tx.origin), _emergencyPerson[address(tx.origin)]));
        _emergencyPerson[address(tx.origin)] = 0;
        uint256 nestAmount = _nestToken.balanceOf(address(this));
        require(_nestToken.transfer(address(_destructionAddress), nestAmount));
    }
    
    /**
    * @dev Modify emergency state
    */
    function changeStateOfEmergency() public {
        if (_stateOfEmergency) {
            require(now > _emergencyTime.add(_emergencyTimeLimit));
            _stateOfEmergency = false;
            _emergencyTime = 0;
        } else {
            require(_emergencyPerson[address(msg.sender)] > 0);
            require(_NNToken.balanceOf(address(this)) >= _emergencyNNAmount);
            _stateOfEmergency = true;
            _emergencyTime = now;
        }
    }
    
    /**
    * @dev Check whether participating in the voting
    * @param user Address to check
    * @return bool Whether voting
    */
    function checkVoteNow(address user) public view returns (bool) {
        if (_myVote[user] == address(0x0)) {
            return false;
        } else {
            Nest_3_VoteContract vote = Nest_3_VoteContract(_myVote[user]);
            if (vote.checkContractEffective() || vote.checkPersonalAmount(user) == 0) {
                return false;
            }
            return true;
        }
    }
    
    /**
    * @dev Check my voting
    * @param user Address to check
    * @return address Address recently participated in the voting contract address
    */
    function checkMyVote(address user) public view returns (address) {
        return _myVote[user];
    }
    
    //  Check the voting time
    function checkLimitTime() public view returns (uint256) {
        return _limitTime;
    }
    
    //  Check the NestNode raising time
    function checkNNLimitTime() public view returns (uint256) {
        return _NNLimitTime;
    }
    
    //  Check the voting proportion to pass
    function checkCirculationProportion() public view returns (uint256) {
        return _circulationProportion;
    }
    
    //  Check the minimum number of NNs to create a voting contract
    function checkNNUsedCreate() public view returns (uint256) {
        return _NNUsedCreate;
    }
    
    //  Check the minimum number of NNs raised to start a vote
    function checkNNCreateLimit() public view returns (uint256) {
        return _NNCreateLimit;
    }
    
    //  Check whether in emergency state
    function checkStateOfEmergency() public view returns (bool) {
        return _stateOfEmergency;
    }
    
    //  Check the start time of the emergency state
    function checkEmergencyTime() public view returns (uint256) {
        return _emergencyTime;
    }
    
    //  Check the duration of the emergency state
    function checkEmergencyTimeLimit() public view returns (uint256) {
        return _emergencyTimeLimit;
    }
    
    //  Check the amount of personal pledged NNs
    function checkEmergencyPerson(address user) public view returns (uint256) {
        return _emergencyPerson[user];
    }
    
    //  Check the number of NNs required for the emergency
    function checkEmergencyNNAmount() public view returns (uint256) {
        return _emergencyNNAmount;
    }
    
    //  Verify voting contract data
    function checkContractData(address contractAddress) public view returns (bool) {
        return _contractData[contractAddress];
    }
    
    //  Modify voting time
    function changeLimitTime(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _limitTime = num;
    }
    
    //  Modify the NestNode raising time
    function changeNNLimitTime(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _NNLimitTime = num;
    }
    
    //  Modify the voting proportion
    function changeCirculationProportion(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _circulationProportion = num;
    }
    
    //  Modify the minimum number of NNs to create a voting contract
    function changeNNUsedCreate(uint256 num) public onlyOwner {
        _NNUsedCreate = num;
    }
    
    //  Modify the minimum number of NNs to raised to start a voting
    function checkNNCreateLimit(uint256 num) public onlyOwner {
        _NNCreateLimit = num;
    }
    
    //  Modify the emergency state duration
    function changeEmergencyTimeLimit(uint256 num) public onlyOwner {
        require(num > 0);
        _emergencyTimeLimit = num.mul(1 days);
    }
    
    //  Modify the number of NNs required for emergency state
    function changeEmergencyNNAmount(uint256 num) public onlyOwner {
        require(num > 0);
        _emergencyNNAmount = num;
    }
    
    //  Check address
    function checkAddress(string memory name) public view returns (address contractAddress) {
        return _contractAddress[name];
    }
    
    //  Add contract mapping address
    function addContractAddress(string memory name, address contractAddress) public onlyOwner {
        _contractAddress[name] = contractAddress;
    }
    
    //  Add administrator address 
    function addSuperMan(address superMan) public onlyOwner {
        _modifyAuthority[superMan] = true;
    }
    function addSuperManPrivate(address superMan) private {
        _modifyAuthority[superMan] = true;
    }
    
    //  Delete administrator address
    function deleteSuperMan(address superMan) public onlyOwner {
        _modifyAuthority[superMan] = false;
    }
    function deleteSuperManPrivate(address superMan) private {
        _modifyAuthority[superMan] = false;
    }
    
    //  Delete voting contract data
    function deleteContractData(address contractAddress) public onlyOwner {
        _contractData[contractAddress] = false;
    }
    
    //  Check whether the administrator
    function checkOwners(address man) public view returns (bool) {
        return _modifyAuthority[man];
    }
    
    //  Administrator only
    modifier onlyOwner() {
        require(checkOwners(msg.sender), "No authority");
        _;
    }
}

/**
 * @title Voting contract
 */
contract Nest_3_VoteContract {
    using SafeMath for uint256;
    
    Nest_3_Implement _implementContract;                //  Executable contract
    Nest_3_TokenSave _tokenSave;                        //  Lock-up contract
    Nest_3_VoteFactory _voteFactory;                    //  Voting factory contract
    Nest_3_TokenAbonus _tokenAbonus;                    //  Bonus logic contract
    ERC20 _nestToken;                                   //  NestToken
    ERC20 _NNToken;                                     //  NestNode Token
    address _miningSave;                                //  Mining pool contract
    address _implementAddress;                          //  Executable contract address
    address _destructionAddress;                        //  Destruction contract address
    uint256 _createTime;                                //  Creation time
    uint256 _endTime;                                   //  End time
    uint256 _totalAmount;                               //  Total votes
    uint256 _circulation;                               //  Passed votes
    uint256 _destroyedNest;                             //  Destroyed NEST
    uint256 _NNLimitTime;                               //  NestNode raising time
    uint256 _NNCreateLimit;                             //  Minimum number of NNs to create votes
    uint256 _abonusTimes;                               //  Period number of used snapshot in emergency state
    uint256 _allNNAmount;                               //  Total number of NNs
    bool _effective = false;                            //  Whether vote is effective
    bool _nestVote = false;                             //  Whether NEST vote can be performed
    bool _isChange = false;                             //  Whether NEST vote is executed
    bool _stateOfEmergency;                             //  Whether the contract is in emergency state
    mapping(address => uint256) _personalAmount;        //  Number of personal votes
    mapping(address => uint256) _personalNNAmount;      //  Number of NN personal votes
    
    /**
    * @dev Initialization method
    * @param contractAddress Executable contract address
    * @param stateOfEmergency Whether in emergency state
    * @param NNAmount Amount of NNs
    */
    constructor (address contractAddress, bool stateOfEmergency, uint256 NNAmount) public {
        Nest_3_VoteFactory voteFactory = Nest_3_VoteFactory(address(msg.sender));
        _voteFactory = voteFactory;
        _nestToken = ERC20(voteFactory.checkAddress("nest"));
        _NNToken = ERC20(voteFactory.checkAddress("nestNode"));
        _implementContract = Nest_3_Implement(address(contractAddress));
        _implementAddress = address(contractAddress);
        _destructionAddress = address(voteFactory.checkAddress("nest.v3.destruction"));
        _personalNNAmount[address(tx.origin)] = NNAmount;
        _allNNAmount = NNAmount;
        _createTime = now;                                    
        _endTime = _createTime.add(voteFactory.checkLimitTime());
        _NNLimitTime = voteFactory.checkNNLimitTime();
        _NNCreateLimit = voteFactory.checkNNCreateLimit();
        _stateOfEmergency = stateOfEmergency;
        if (stateOfEmergency) {
            //  If in emergency state, read the last two periods of bonus lock-up and total circulation data
            _tokenAbonus = Nest_3_TokenAbonus(payable(voteFactory.checkAddress("nest.v3.tokenAbonus")));
            _abonusTimes = _tokenAbonus.checkTimes().sub(2);
            require(_abonusTimes > 0);
            _circulation = _tokenAbonus.checkTokenAllValueHistory(address(_nestToken),_abonusTimes).mul(voteFactory.checkCirculationProportion()).div(100);
        } else {
            _miningSave = address(voteFactory.checkAddress("nest.v3.miningSave"));
            _tokenSave = Nest_3_TokenSave(voteFactory.checkAddress("nest.v3.tokenSave"));
            _circulation = (uint256(10000000000 ether).sub(_nestToken.balanceOf(address(_miningSave))).sub(_nestToken.balanceOf(address(_destructionAddress)))).mul(voteFactory.checkCirculationProportion()).div(100);
        }
        if (_allNNAmount >= _NNCreateLimit) {
            _nestVote = true;
        }
    }
    
    /**
    * @dev NEST voting
    */
    function nestVote() public onlyFactory {
        require(now <= _endTime, "Voting time exceeded");
        require(!_effective, "Vote in force");
        require(_nestVote);
        require(_personalAmount[address(tx.origin)] == 0, "Have voted");
        uint256 amount;
        if (_stateOfEmergency) {
            //  If in emergency state, read the last two periods of bonus lock-up and total circulation data
            amount = _tokenAbonus.checkTokenSelfHistory(address(_nestToken),_abonusTimes, address(tx.origin));
        } else {
            amount = _tokenSave.checkAmount(address(tx.origin), address(_nestToken));
        }
        _personalAmount[address(tx.origin)] = amount;
        _totalAmount = _totalAmount.add(amount);
        ifEffective();
    }
    
    /**
    * @dev NEST voting cancellation
    */
    function nestVoteCancel() public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(now <= _endTime, "Voting time exceeded");
        require(!_effective, "Vote in force");
        require(_personalAmount[address(tx.origin)] > 0, "No vote");                     
        _totalAmount = _totalAmount.sub(_personalAmount[address(tx.origin)]);
        _personalAmount[address(tx.origin)] = 0;
    }
    
    /**
    * @dev  NestNode voting
    * @param NNAmount Amount of NNs
    */
    function nestNodeVote(uint256 NNAmount) public onlyFactory {
        require(now <= _createTime.add(_NNLimitTime), "Voting time exceeded");
        require(!_nestVote);
        _personalNNAmount[address(tx.origin)] = _personalNNAmount[address(tx.origin)].add(NNAmount);
        _allNNAmount = _allNNAmount.add(NNAmount);
        if (_allNNAmount >= _NNCreateLimit) {
            _nestVote = true;
        }
    }
    
    /**
    * @dev Withdrawing lock-up NNs
    */
    function turnOutNestNode() public {
        if (_nestVote) {
            //  Normal NEST voting
            if (!_stateOfEmergency || !_effective) {
                //  Non-emergency state
                require(now > _endTime, "Vote unenforceable");
            }
        } else {
            //  NN voting
            require(now > _createTime.add(_NNLimitTime));
        }
        require(_personalNNAmount[address(tx.origin)] > 0);
        //  Reverting back the NNs
        require(_NNToken.transfer(address(tx.origin), _personalNNAmount[address(tx.origin)]));
        _personalNNAmount[address(tx.origin)] = 0;
        //  Destroying NEST Tokens 
        uint256 nestAmount = _nestToken.balanceOf(address(this));
        _destroyedNest = _destroyedNest.add(nestAmount);
        require(_nestToken.transfer(address(_destructionAddress), nestAmount));
    }
    
    /**
    * @dev Execute the contract
    */
    function startChange() public onlyFactory {
        require(!_isChange);
        _isChange = true;
        if (_stateOfEmergency) {
            require(_effective, "Vote unenforceable");
        } else {
            require(_effective && now > _endTime, "Vote unenforceable");
        }
        //  Add the executable contract to the administrator list
        _voteFactory.addSuperMan(address(_implementContract));
        //  Execute
        _implementContract.doit();
        //  Delete the authorization
        _voteFactory.deleteSuperMan(address(_implementContract));
    }
    
    /**
    * @dev check whether the vote is effective
    */
    function ifEffective() private {
        if (_totalAmount >= _circulation) {
            _effective = true;
        }
    }
    
    /**
    * @dev Check whether the vote is over
    */
    function checkContractEffective() public view returns (bool) {
        if (_effective || now > _endTime) {
            return true;
        } 
        return false;
    }
    
    //  Check the executable implement contract address
    function checkImplementAddress() public view returns (address) {
        return _implementAddress;
    }
    
    //  Check the voting start time
    function checkCreateTime() public view returns (uint256) {
        return _createTime;
    }
    
    //  Check the voting end time
    function checkEndTime() public view returns (uint256) {
        return _endTime;
    }
    
    //  Check the current total number of votes
    function checkTotalAmount() public view returns (uint256) {
        return _totalAmount;
    }
    
    //  Check the number of votes to pass
    function checkCirculation() public view returns (uint256) {
        return _circulation;
    }
    
    //  Check the number of personal votes
    function checkPersonalAmount(address user) public view returns (uint256) {
        return _personalAmount[user];
    }
    
    //  Check the destroyed NEST
    function checkDestroyedNest() public view returns (uint256) {
        return _destroyedNest;
    }
    
    //  Check whether the contract is effective
    function checkEffective() public view returns (bool) {
        return _effective;
    }
    
    //  Check whether in emergency state
    function checkStateOfEmergency() public view returns (bool) {
        return _stateOfEmergency;
    }
    
    //  Check NestNode raising time
    function checkNNLimitTime() public view returns (uint256) {
        return _NNLimitTime;
    }
    
    //  Check the minimum number of NNs to create a vote
    function checkNNCreateLimit() public view returns (uint256) {
        return _NNCreateLimit;
    }
    
    //  Check the period number of snapshot used in the emergency state
    function checkAbonusTimes() public view returns (uint256) {
        return _abonusTimes;
    }
    
    //  Check number of personal votes
    function checkPersonalNNAmount(address user) public view returns (uint256) {
        return _personalNNAmount[address(user)];
    }
    
    //  Check the total number of NNs
    function checkAllNNAmount() public view returns (uint256) {
        return _allNNAmount;
    }
    
    //  Check whether NEST voting is available
    function checkNestVote() public view returns (bool) {
        return _nestVote;
    }
    
    //  Check whether it has been excecuted
    function checkIsChange() public view returns (bool) {
        return _isChange;
    }
    
    //  Vote Factory contract only
    modifier onlyFactory() {
        require(address(_voteFactory) == address(msg.sender), "No authority");
        _;
    }
}

/**
 * @title Mining contract
 * @dev Mining pool + mining logic
 */
contract Nest_3_MiningContract {
    
    using address_make_payable for address;
    using SafeMath for uint256;
    
    uint256 _blockAttenuation = 2400000;                 //  Block decay time interval
    uint256[10] _attenuationAmount;                      //  Mining decay amount
    uint256 _afterMiningAmount = 40 ether;               //  Stable period mining amount
    uint256 _firstBlockNum;                              //  Starting mining block
    uint256 _latestMining;                               //  Latest offering block
    Nest_3_VoteFactory _voteFactory;                     //  Voting contract
    ERC20 _nestContract;                                 //  NEST contract address
    address _offerFactoryAddress;                        //  Offering contract address
    
    // Current block, current block mining amount
    event OreDrawingLog(uint256 nowBlock, uint256 blockAmount);
    
    /**
    * @dev Initialization method
    * @param voteFactory  voting contract address
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));                  
        _offerFactoryAddress = address(_voteFactory.checkAddress("nest.v3.offerMain"));
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
        // Initiate mining parameters
        _firstBlockNum = 6236588;
        _latestMining = block.number;
        uint256 blockAmount = 400 ether;
        for (uint256 i = 0; i < 10; i ++) {
            _attenuationAmount[i] = blockAmount;
            blockAmount = blockAmount.mul(8).div(10);
        }
    }
    
    /**
    * @dev Reset voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));                  
        _offerFactoryAddress = address(_voteFactory.checkAddress("nest.v3.offerMain"));
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
    }
    
    /**
    * @dev Offering mining
    * @return Current block mining amount
    */
    function oreDrawing() public returns (uint256) {
        require(address(msg.sender) == _offerFactoryAddress, "No authority");
        //  Update mining amount list
        uint256 miningAmount = changeBlockAmountList();
        //  Transfer NEST
        if (_nestContract.balanceOf(address(this)) < miningAmount){
            miningAmount = _nestContract.balanceOf(address(this));
        }
        if (miningAmount > 0) {
            _nestContract.transfer(address(msg.sender), miningAmount);
            emit OreDrawingLog(block.number,miningAmount);
        }
        return miningAmount;
    }
    
    /**
    * @dev Update mining amount list
    */
    function changeBlockAmountList() private returns (uint256) {
        uint256 createBlock = _firstBlockNum;
        uint256 recentlyUsedBlock = _latestMining;
        uint256 attenuationPointNow = block.number.sub(createBlock).div(_blockAttenuation);
        uint256 miningAmount = 0;
        uint256 attenuation;
        if (attenuationPointNow > 9) {
            attenuation = _afterMiningAmount;
        } else {
            attenuation = _attenuationAmount[attenuationPointNow];
        }
        miningAmount = attenuation.mul(block.number.sub(recentlyUsedBlock));
        _latestMining = block.number;
        return miningAmount;
    }
    
    /**
    * @dev Transfer all NEST
    * @param target Transfer target address
    */
    function takeOutNest(address target) public onlyOwner {
        _nestContract.transfer(address(target),_nestContract.balanceOf(address(this)));
    }

    // Check block decay time interval
    function checkBlockAttenuation() public view returns(uint256) {
        return _blockAttenuation;
    }
    
    // Check latest offering block
    function checkLatestMining() public view returns(uint256) {
        return _latestMining;
    }
    
    // Check mining amount decay
    function checkAttenuationAmount(uint256 num) public view returns(uint256) {
        return _attenuationAmount[num];
    }
    
    // Check NEST balance
    function checkNestBalance() public view returns(uint256) {
        return _nestContract.balanceOf(address(this));
    }
    
    // Modify block decay time interval
    function changeBlockAttenuation(uint256 blockNum) public onlyOwner {
        require(blockNum > 0);
        _blockAttenuation = blockNum;
    }
    
    // Modify mining amount decay
    function changeAttenuationAmount(uint256 firstAmount, uint256 top, uint256 bottom) public onlyOwner {
        uint256 blockAmount = firstAmount;
        for (uint256 i = 0; i < 10; i ++) {
            _attenuationAmount[i] = blockAmount;
            blockAmount = blockAmount.mul(top).div(bottom);
        }
    }
    
    // Administrator only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender), "No authority");
        _;
    }
}

/**
 * @title Offering contract
 * @dev Offering + take order + NEST allocation
 */
contract Nest_3_OfferMain {
    using SafeMath for uint256;
    using address_make_payable for address;
    using SafeERC20 for ERC20;
    
    struct Nest_3_OfferPriceData {
        // The unique identifier is determined by the position of the offer in the array, and is converted to each other through a fixed algorithm (toindex(), toaddress())
        
        address owner;                                  //  Offering owner
        bool deviate;                                   //  Whether it deviates 
        address tokenAddress;                           //  The erc20 contract address of the target offer token
        
        uint256 ethAmount;                              //  The ETH amount in the offer list
        uint256 tokenAmount;                            //  The token amount in the offer list
        
        uint256 dealEthAmount;                          //  The remaining number of tradable ETH
        uint256 dealTokenAmount;                        //  The remaining number of tradable tokens
        
        uint256 blockNum;                               //  The block number where the offer is located
        uint256 serviceCharge;                          //  The fee for mining
        
        // Determine whether the asset has been collected by judging that ethamount, tokenamount, and servicecharge are all 0
    }
    
    Nest_3_OfferPriceData [] _prices;                   //  Array used to save offers

    mapping(address => bool) _tokenAllow;               //  List of allowed mining token
    Nest_3_VoteFactory _voteFactory;                    //  Vote contract
    Nest_3_OfferPrice _offerPrice;                      //  Price contract
    Nest_3_MiningContract _miningContract;              //  Mining contract
    Nest_NodeAssignment _NNcontract;                    //  NestNode contract
    ERC20 _nestToken;                                   //  NestToken
    Nest_3_Abonus _abonus;                              //  Bonus pool
    address _coderAddress;                              //  Developer address
    uint256 _miningETH = 10;                            //  Offering mining fee ratio
    uint256 _tranEth = 1;                               //  Taker fee ratio
    uint256 _tranAddition = 2;                          //  Additional transaction multiple
    uint256 _coderAmount = 5;                           //  Developer ratio
    uint256 _NNAmount = 15;                             //  NestNode ratio
    uint256 _leastEth = 10 ether;                       //  Minimum offer of ETH
    uint256 _offerSpan = 10 ether;                      //  ETH Offering span
    uint256 _deviate = 10;                              //  Price deviation - 10%
    uint256 _deviationFromScale = 10;                   //  Deviation from asset scale
    uint32 _blockLimit = 25;                            //  Block interval upper limit
    mapping(uint256 => uint256) _offerBlockEth;         //  Block offer fee
    mapping(uint256 => uint256) _offerBlockMining;      //  Block mining amount
    
    //  Log offering contract, token address, number of eth, number of erc20, number of continuous blocks, number of fees
    event OfferContractAddress(address contractAddress, address tokenAddress, uint256 ethAmount, uint256 erc20Amount, uint256 continued, uint256 serviceCharge);
    //  Log transaction, transaction initiator, transaction token address, number of transaction token, token address, number of token, traded offering contract address, traded user address
    event OfferTran(address tranSender, address tranToken, uint256 tranAmount,address otherToken, uint256 otherAmount, address tradedContract, address tradedOwner);        
    
     /**
    * @dev Initialization method
    * @param voteFactory Voting contract address
    */
    constructor (address voteFactory) public {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap; 
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));            
        _miningContract = Nest_3_MiningContract(address(voteFactoryMap.checkAddress("nest.v3.miningSave")));
        _abonus = Nest_3_Abonus(voteFactoryMap.checkAddress("nest.v3.abonus"));
        _nestToken = ERC20(voteFactoryMap.checkAddress("nest"));                                         
        _NNcontract = Nest_NodeAssignment(address(voteFactoryMap.checkAddress("nodeAssignment")));      
        _coderAddress = voteFactoryMap.checkAddress("nest.v3.coder");
        require(_nestToken.approve(address(_NNcontract), uint256(10000000000 ether)), "Authorization failed");
    }
    
     /**
    * @dev Reset voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap; 
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));            
        _miningContract = Nest_3_MiningContract(address(voteFactoryMap.checkAddress("nest.v3.miningSave")));
        _abonus = Nest_3_Abonus(voteFactoryMap.checkAddress("nest.v3.abonus"));
        _nestToken = ERC20(voteFactoryMap.checkAddress("nest"));                                           
        _NNcontract = Nest_NodeAssignment(address(voteFactoryMap.checkAddress("nodeAssignment")));      
        _coderAddress = voteFactoryMap.checkAddress("nest.v3.coder");
        require(_nestToken.approve(address(_NNcontract), uint256(10000000000 ether)), "Authorization failed");
    }
    
    /**
    * @dev Offering mining
    * @param ethAmount Offering ETH amount 
    * @param erc20Amount Offering erc20 token amount
    * @param erc20Address Offering erc20 token address
    */
    function offer(uint256 ethAmount, uint256 erc20Amount, address erc20Address) public payable {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(_tokenAllow[erc20Address], "Token not allow");
        //  Judge whether the price deviates
        uint256 ethMining;
        bool isDeviate = comparativePrice(ethAmount,erc20Amount,erc20Address);
        if (isDeviate) {
            require(ethAmount >= _leastEth.mul(_deviationFromScale), "EthAmount needs to be no less than 10 times of the minimum scale");
            ethMining = _leastEth.mul(_miningETH).div(1000);
        } else {
            ethMining = ethAmount.mul(_miningETH).div(1000);
        }
        require(msg.value >= ethAmount.add(ethMining), "msg.value needs to be equal to the quoted eth quantity plus Mining handling fee");
        uint256 subValue = msg.value.sub(ethAmount.add(ethMining));
        if (subValue > 0) {
            repayEth(address(msg.sender), subValue);
        }
        //  Create an offer
        createOffer(ethAmount, erc20Amount, erc20Address, ethMining, isDeviate);
        //  Transfer in offer asset - erc20 to this contract
        ERC20(erc20Address).safeTransferFrom(address(msg.sender), address(this), erc20Amount);
        //  Mining
        uint256 miningAmount = _miningContract.oreDrawing();
        _abonus.switchToEth.value(ethMining)(address(_nestToken));
        if (miningAmount > 0) {
            uint256 coder = miningAmount.mul(_coderAmount).div(100);
            uint256 NN = miningAmount.mul(_NNAmount).div(100);
            uint256 other = miningAmount.sub(coder).sub(NN);
            _offerBlockMining[block.number] = other;
            _NNcontract.bookKeeping(NN);   
            if (coder > 0) {
                _nestToken.safeTransfer(_coderAddress, coder);  
            }
        }
        _offerBlockEth[block.number] = _offerBlockEth[block.number].add(ethMining);
    }
    
    /**
    * @dev Create offer
    * @param ethAmount Offering ETH amount
    * @param erc20Amount Offering erc20 amount
    * @param erc20Address Offering erc20 address
    * @param mining Offering mining fee (0 for takers)
    * @param isDeviate Whether the current price chain deviates
    */
    function createOffer(uint256 ethAmount, uint256 erc20Amount, address erc20Address, uint256 mining, bool isDeviate) private {
        // Check offer conditions
        require(ethAmount >= _leastEth, "Eth scale is smaller than the minimum scale");
        require(ethAmount % _offerSpan == 0, "Non compliant asset span");
        require(erc20Amount % (ethAmount.div(_offerSpan)) == 0, "Asset quantity is not divided");
        require(erc20Amount > 0);
        // Create offering contract
        emit OfferContractAddress(toAddress(_prices.length), address(erc20Address), ethAmount, erc20Amount,_blockLimit,mining);
        _prices.push(Nest_3_OfferPriceData(
            
            msg.sender,
            isDeviate,
            erc20Address,
            
            ethAmount,
            erc20Amount,
                           
            ethAmount, 
            erc20Amount, 
              
            block.number, 
            mining
            
        )); 
        // Record price
        _offerPrice.addPrice(ethAmount, erc20Amount, block.number.add(_blockLimit), erc20Address, address(msg.sender));
    }
    
    /**
    * @dev Taker order - pay ETH and buy erc20
    * @param ethAmount The amount of ETH of this offer
    * @param tokenAmount The amount of erc20 of this offer
    * @param contractAddress The target offer address
    * @param tranEthAmount The amount of ETH of taker order
    * @param tranTokenAmount The amount of erc20 of taker order
    * @param tranTokenAddress The erc20 address of taker order
    */
    function sendEthBuyErc(uint256 ethAmount, uint256 tokenAmount, address contractAddress, uint256 tranEthAmount, uint256 tranTokenAmount, address tranTokenAddress) public payable {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        // Get the offer data structure
        uint256 index = toIndex(contractAddress);
        Nest_3_OfferPriceData memory offerPriceData = _prices[index]; 
        //  Check the price, compare the current offer to the last effective price
        bool thisDeviate = comparativePrice(ethAmount,tokenAmount,tranTokenAddress);
        bool isDeviate;
        if (offerPriceData.deviate == true) {
            isDeviate = true;
        } else {
            isDeviate = thisDeviate;
        }
        // Limit the taker order only be twice the amount of the offer to prevent large-amount attacks
        if (offerPriceData.deviate) {
            //  The taker order deviates  x2
            require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
        } else {
            if (isDeviate) {
                //  If the taken offer is normal and the taker order deviates x10
                require(ethAmount >= tranEthAmount.mul(_deviationFromScale), "EthAmount needs to be no less than 10 times of transaction scale");
            } else {
                //  If the taken offer is normal and the taker order is normal x2
                require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
            }
        }
        
        uint256 serviceCharge = tranEthAmount.mul(_tranEth).div(1000);
        require(msg.value == ethAmount.add(tranEthAmount).add(serviceCharge), "msg.value needs to be equal to the quotation eth quantity plus transaction eth plus transaction handling fee");
        require(tranEthAmount % _offerSpan == 0, "Transaction size does not meet asset span");
        
        // Check whether the conditions for taker order are satisfied
        require(checkContractState(offerPriceData.blockNum) == 0, "Offer status error");
        require(offerPriceData.dealEthAmount >= tranEthAmount, "Insufficient trading eth");
        require(offerPriceData.dealTokenAmount >= tranTokenAmount, "Insufficient trading token");
        require(offerPriceData.tokenAddress == tranTokenAddress, "Wrong token address");
        require(tranTokenAmount == offerPriceData.dealTokenAmount * tranEthAmount / offerPriceData.dealEthAmount, "Wrong token amount");
        
        // Update the offer information
        offerPriceData.ethAmount = offerPriceData.ethAmount.add(tranEthAmount);
        offerPriceData.tokenAmount = offerPriceData.tokenAmount.sub(tranTokenAmount);
        offerPriceData.dealEthAmount = offerPriceData.dealEthAmount.sub(tranEthAmount);
        offerPriceData.dealTokenAmount = offerPriceData.dealTokenAmount.sub(tranTokenAmount);
        _prices[index] = offerPriceData;
        // Create a new offer
        createOffer(ethAmount, tokenAmount, tranTokenAddress, 0, isDeviate);
        // Transfer in erc20 + offer asset to this contract
        if (tokenAmount > tranTokenAmount) {
            ERC20(tranTokenAddress).safeTransferFrom(address(msg.sender), address(this), tokenAmount.sub(tranTokenAmount));
        } else {
            ERC20(tranTokenAddress).safeTransfer(address(msg.sender), tranTokenAmount.sub(tokenAmount));
        }
        // Modify price
        _offerPrice.changePrice(tranEthAmount, tranTokenAmount, tranTokenAddress, offerPriceData.blockNum.add(_blockLimit));
        emit OfferTran(address(msg.sender), address(0x0), tranEthAmount, address(tranTokenAddress), tranTokenAmount, contractAddress, offerPriceData.owner);
        // Transfer fee
        if (serviceCharge > 0) {
            _abonus.switchToEth.value(serviceCharge)(address(_nestToken));
        }
    }
    
    /**
    * @dev Taker order - pay erc20 and buy ETH
    * @param ethAmount The amount of ETH of this offer
    * @param tokenAmount The amount of erc20 of this offer
    * @param contractAddress The target offer address
    * @param tranEthAmount The amount of ETH of taker order
    * @param tranTokenAmount The amount of erc20 of taker order
    * @param tranTokenAddress The erc20 address of taker order
    */
    function sendErcBuyEth(uint256 ethAmount, uint256 tokenAmount, address contractAddress, uint256 tranEthAmount, uint256 tranTokenAmount, address tranTokenAddress) public payable {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        // Get the offer data structure
        uint256 index = toIndex(contractAddress);
        Nest_3_OfferPriceData memory offerPriceData = _prices[index]; 
        // Check the price, compare the current offer to the last effective price
        bool thisDeviate = comparativePrice(ethAmount,tokenAmount,tranTokenAddress);
        bool isDeviate;
        if (offerPriceData.deviate == true) {
            isDeviate = true;
        } else {
            isDeviate = thisDeviate;
        }
        // Limit the taker order only be twice the amount of the offer to prevent large-amount attacks
        if (offerPriceData.deviate) {
            //  The taker order deviates  x2
            require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
        } else {
            if (isDeviate) {
                //  If the taken offer is normal and the taker order deviates x10
                require(ethAmount >= tranEthAmount.mul(_deviationFromScale), "EthAmount needs to be no less than 10 times of transaction scale");
            } else {
                //  If the taken offer is normal and the taker order is normal x2 
                require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
            }
        }
        uint256 serviceCharge = tranEthAmount.mul(_tranEth).div(1000);
        require(msg.value == ethAmount.sub(tranEthAmount).add(serviceCharge), "msg.value needs to be equal to the quoted eth quantity plus transaction handling fee");
        require(tranEthAmount % _offerSpan == 0, "Transaction size does not meet asset span");
        
        // Check whether the conditions for taker order are satisfied
        require(checkContractState(offerPriceData.blockNum) == 0, "Offer status error");
        require(offerPriceData.dealEthAmount >= tranEthAmount, "Insufficient trading eth");
        require(offerPriceData.dealTokenAmount >= tranTokenAmount, "Insufficient trading token");
        require(offerPriceData.tokenAddress == tranTokenAddress, "Wrong token address");
        require(tranTokenAmount == offerPriceData.dealTokenAmount * tranEthAmount / offerPriceData.dealEthAmount, "Wrong token amount");
        
        // Update the offer information
        offerPriceData.ethAmount = offerPriceData.ethAmount.sub(tranEthAmount);
        offerPriceData.tokenAmount = offerPriceData.tokenAmount.add(tranTokenAmount);
        offerPriceData.dealEthAmount = offerPriceData.dealEthAmount.sub(tranEthAmount);
        offerPriceData.dealTokenAmount = offerPriceData.dealTokenAmount.sub(tranTokenAmount);
        _prices[index] = offerPriceData;
        // Create a new offer
        createOffer(ethAmount, tokenAmount, tranTokenAddress, 0, isDeviate);
        // Transfer in erc20 + offer asset to this contract
        ERC20(tranTokenAddress).safeTransferFrom(address(msg.sender), address(this), tranTokenAmount.add(tokenAmount));
        // Modify price
        _offerPrice.changePrice(tranEthAmount, tranTokenAmount, tranTokenAddress, offerPriceData.blockNum.add(_blockLimit));
        emit OfferTran(address(msg.sender), address(tranTokenAddress), tranTokenAmount, address(0x0), tranEthAmount, contractAddress, offerPriceData.owner);
        // Transfer fee
        if (serviceCharge > 0) {
            _abonus.switchToEth.value(serviceCharge)(address(_nestToken));
        }
    }
    
    /**
    * @dev Withdraw the assets, and settle the mining
    * @param contractAddress The offer address to withdraw
    */
    function turnOut(address contractAddress) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        uint256 index = toIndex(contractAddress);
        Nest_3_OfferPriceData storage offerPriceData = _prices[index]; 
        require(checkContractState(offerPriceData.blockNum) == 1, "Offer status error");
        
        // Withdraw ETH
        if (offerPriceData.ethAmount > 0) {
            uint256 payEth = offerPriceData.ethAmount;
            offerPriceData.ethAmount = 0;
            repayEth(offerPriceData.owner, payEth);
        }
        
        // Withdraw erc20
        if (offerPriceData.tokenAmount > 0) {
            uint256 payErc = offerPriceData.tokenAmount;
            offerPriceData.tokenAmount = 0;
            ERC20(address(offerPriceData.tokenAddress)).safeTransfer(offerPriceData.owner, payErc);
            
        }
        // Mining settlement
        if (offerPriceData.serviceCharge > 0) {
            uint256 myMiningAmount = offerPriceData.serviceCharge.mul(_offerBlockMining[offerPriceData.blockNum]).div(_offerBlockEth[offerPriceData.blockNum]);
            _nestToken.safeTransfer(offerPriceData.owner, myMiningAmount);
            offerPriceData.serviceCharge = 0;
        }
        
    }
    
    // Convert offer address into index in offer array
    function toIndex(address contractAddress) public pure returns(uint256) {
        return uint256(contractAddress);
    }
    
    // Convert index in offer array into offer address 
    function toAddress(uint256 index) public pure returns(address) {
        return address(index);
    }
    
    // View contract state
    function checkContractState(uint256 createBlock) public view returns (uint256) {
        if (block.number.sub(createBlock) > _blockLimit) {
            return 1;
        }
        return 0;
    }

    // Compare the order price
    function comparativePrice(uint256 myEthValue, uint256 myTokenValue, address token) private view returns(bool) {
        (uint256 frontEthValue, uint256 frontTokenValue) = _offerPrice.updateAndCheckPricePrivate(token);
        if (frontEthValue == 0 || frontTokenValue == 0) {
            return false;
        }
        uint256 maxTokenAmount = myEthValue.mul(frontTokenValue).mul(uint256(100).add(_deviate)).div(frontEthValue.mul(100));
        if (myTokenValue <= maxTokenAmount) {
            uint256 minTokenAmount = myEthValue.mul(frontTokenValue).mul(uint256(100).sub(_deviate)).div(frontEthValue.mul(100));
            if (myTokenValue >= minTokenAmount) {
                return false;
            }
        }
        return true;
    }
    
    // Transfer ETH
    function repayEth(address accountAddress, uint256 asset) private {
        address payable addr = accountAddress.make_payable();
        addr.transfer(asset);
    }
    
    // View the upper limit of the block interval
    function checkBlockLimit() public view returns(uint32) {
        return _blockLimit;
    }
    
    // View offering mining fee ratio
    function checkMiningETH() public view returns (uint256) {
        return _miningETH;
    }
    
    // View whether the token is allowed to mine
    function checkTokenAllow(address token) public view returns(bool) {
        return _tokenAllow[token];
    }
    
    // View additional transaction multiple
    function checkTranAddition() public view returns(uint256) {
        return _tranAddition;
    }
    
    // View the development allocation ratio
    function checkCoderAmount() public view returns(uint256) {
        return _coderAmount;
    }
    
    // View the NestNode allocation ratio
    function checkNNAmount() public view returns(uint256) {
        return _NNAmount;
    }
    
    // View the least offering ETH 
    function checkleastEth() public view returns(uint256) {
        return _leastEth;
    }
    
    // View offering ETH span
    function checkOfferSpan() public view returns(uint256) {
        return _offerSpan;
    }
    
    // View the price deviation
    function checkDeviate() public view returns(uint256){
        return _deviate;
    }
    
    // View deviation from scale
    function checkDeviationFromScale() public view returns(uint256) {
        return _deviationFromScale;
    }
    
    // View block offer fee
    function checkOfferBlockEth(uint256 blockNum) public view returns(uint256) {
        return _offerBlockEth[blockNum];
    }
    
    // View taker order fee ratio
    function checkTranEth() public view returns (uint256) {
        return _tranEth;
    }
    
    // View block mining amount of user
    function checkOfferBlockMining(uint256 blockNum) public view returns(uint256) {
        return _offerBlockMining[blockNum];
    }

    // View offer mining amount
    function checkOfferMining(uint256 blockNum, uint256 serviceCharge) public view returns (uint256) {
        if (serviceCharge == 0) {
            return 0;
        } else {
            return _offerBlockMining[blockNum].mul(serviceCharge).div(_offerBlockEth[blockNum]);
        }
    }
    
    // Change offering mining fee ratio
    function changeMiningETH(uint256 num) public onlyOwner {
        _miningETH = num;
    }
    
    // Modify taker fee ratio
    function changeTranEth(uint256 num) public onlyOwner {
        _tranEth = num;
    }
    
    // Modify the upper limit of the block interval
    function changeBlockLimit(uint32 num) public onlyOwner {
        _blockLimit = num;
    }
    
    // Modify whether the token allows mining
    function changeTokenAllow(address token, bool allow) public onlyOwner {
        _tokenAllow[token] = allow;
    }
    
    // Modify additional transaction multiple
    function changeTranAddition(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _tranAddition = num;
    }
    
    // Modify the initial allocation ratio
    function changeInitialRatio(uint256 coderNum, uint256 NNNum) public onlyOwner {
        require(coderNum.add(NNNum) <= 100, "User allocation ratio error");
        _coderAmount = coderNum;
        _NNAmount = NNNum;
    }
    
    // Modify the minimum offering ETH
    function changeLeastEth(uint256 num) public onlyOwner {
        require(num > 0);
        _leastEth = num;
    }
    
    //  Modify the offering ETH span
    function changeOfferSpan(uint256 num) public onlyOwner {
        require(num > 0);
        _offerSpan = num;
    }
    
    // Modify the price deviation
    function changekDeviate(uint256 num) public onlyOwner {
        _deviate = num;
    }
    
    // Modify the deviation from scale 
    function changeDeviationFromScale(uint256 num) public onlyOwner {
        _deviationFromScale = num;
    }
    
    /**
     * Get the number of offers stored in the offer array
     * @return The number of offers stored in the offer array
     **/
    function getPriceCount() view public returns (uint256) {
        return _prices.length;
    }
    
    /**
     * Get offer information according to the index
     * @param priceIndex Offer index
     * @return Offer information
     **/
    function getPrice(uint256 priceIndex) view public returns (string memory) {
        // The buffer array used to generate the result string
        bytes memory buf = new bytes(500000);
        uint256 index = 0;
        
        index = writeOfferPriceData(priceIndex, _prices[priceIndex], buf, index);
        
        //  Generate the result string and return
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }
    
    /**
     * Search the contract address list of the target account (reverse order)
     * @param start Search forward from the index corresponding to the given contract address (not including the record corresponding to start address)
     * @param count Maximum number of records to return
     * @param maxFindCount The max index to search
     * @param owner Target account address
     * @return Separate the offer records with symbols. use , to divide fields: 
     * uuid,owner,tokenAddress,ethAmount,tokenAmount,dealEthAmount,dealTokenAmount,blockNum,serviceCharge
     **/
    function find(address start, uint256 count, uint256 maxFindCount, address owner) view public returns (string memory) {
        
        // Buffer array used to generate result string
        bytes memory buf = new bytes(500000);
        uint256 index = 0;
        
        // Calculate search interval i and end
        uint256 i = _prices.length;
        uint256 end = 0;
        if (start != address(0)) {
            i = toIndex(start);
        }
        if (i > maxFindCount) {
            end = i - maxFindCount;
        }
        
        // Loop search, write qualified records into buffer
        while (count > 0 && i-- > end) {
            Nest_3_OfferPriceData memory price = _prices[i];
            if (price.owner == owner) {
                --count;
                index = writeOfferPriceData(i, price, buf, index);
            }
        }
        
        // Generate result string and return
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }
    
    /**
     * Get the list of offers by page
     * @param offset Skip the first offset records
     * @param count Maximum number of records to return
     * @param order Sort rules. 0 means reverse order, non-zero means positive order
     * @return Separate the offer records with symbols. use , to divide fields: 
     * uuid,owner,tokenAddress,ethAmount,tokenAmount,dealEthAmount,dealTokenAmount,blockNum,serviceCharge
     **/
    function list(uint256 offset, uint256 count, uint256 order) view public returns (string memory) {
        
        // Buffer array used to generate result string
        bytes memory buf = new bytes(500000);
        uint256 index = 0;
        
        // Find search interval i and end
        uint256 i = 0;
        uint256 end = 0;
        
        if (order == 0) {
            // Reverse order, in default 
            // Calculate search interval i and end
            if (offset < _prices.length) {
                i = _prices.length - offset;
            } 
            if (count < i) {
                end = i - count;
            }
            
            // Write records in the target interval into the buffer
            while (i-- > end) {
                index = writeOfferPriceData(i, _prices[i], buf, index);
            }
        } else {
            // Ascending order
            // Calculate the search interval i and end
            if (offset < _prices.length) {
                i = offset;
            } else {
                i = _prices.length;
            }
            end = i + count;
            if(end > _prices.length) {
                end = _prices.length;
            }
            
            // Write the records in the target interval into the buffer
            while (i < end) {
                index = writeOfferPriceData(i, _prices[i], buf, index);
                ++i;
            }
        }
        
        // Generate the result string and return
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }   
     
    // Write the offer data into the buffer and return the buffer index
    function writeOfferPriceData(uint256 priceIndex, Nest_3_OfferPriceData memory price, bytes memory buf, uint256 index) pure private returns (uint256) {
        index = writeAddress(toAddress(priceIndex), buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeAddress(price.owner, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeAddress(price.tokenAddress, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.ethAmount, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.tokenAmount, buf, index);
        buf[index++] = byte(uint8(44));
       
        index = writeUInt(price.dealEthAmount, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.dealTokenAmount, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.blockNum, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.serviceCharge, buf, index);
        buf[index++] = byte(uint8(44));
        
        return index;
    }
     
    // Convert integer to string in decimal form and write it into the buffer, and return the buffer index
    function writeUInt(uint256 iv, bytes memory buf, uint256 index) pure public returns (uint256) {
        uint256 i = index;
        do {
            buf[index++] = byte(uint8(iv % 10 +48));
            iv /= 10;
        } while (iv > 0);
        
        for (uint256 j = index; j > i; ++i) {
            byte t = buf[i];
            buf[i] = buf[--j];
            buf[j] = t;
        }
        
        return index;
    }

    // Convert the address to a hexadecimal string and write it into the buffer, and return the buffer index
    function writeAddress(address addr, bytes memory buf, uint256 index) pure private returns (uint256) {
        
        uint256 iv = uint256(addr);
        uint256 i = index + 40;
        do {
            uint256 w = iv % 16;
            if(w < 10) {
                buf[index++] = byte(uint8(w +48));
            } else {
                buf[index++] = byte(uint8(w +87));
            }
            
            iv /= 16;
        } while (index < i);
        
        i -= 40;
        for (uint256 j = index; j > i; ++i) {
            byte t = buf[i];
            buf[i] = buf[--j];
            buf[j] = t;
        }
        
        return index;
    }
    
    // Vote administrator only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender), "No authority");
        _;
    }
}

/**
 * @title Price contract
 * @dev Price check and call
 */
contract Nest_3_OfferPrice{
    using SafeMath for uint256;
    using address_make_payable for address;
    using SafeERC20 for ERC20;
    
    Nest_3_VoteFactory _voteFactory;                                //  Voting contract
    ERC20 _nestToken;                                               //  NestToken
    Nest_NToken_TokenMapping _tokenMapping;                         //  NToken mapping
    Nest_3_OfferMain _offerMain;                                    //  Offering main contract
    Nest_3_Abonus _abonus;                                          //  Bonus pool
    address _nTokeOfferMain;                                        //  NToken offering main contract
    address _destructionAddress;                                    //  Destruction contract address
    address _nTokenAuction;                                         //  NToken auction contract address
    struct PriceInfo {                                              //  Block price
        uint256 ethAmount;                                          //  ETH amount
        uint256 erc20Amount;                                        //  Erc20 amount
        uint256 frontBlock;                                         //  Last effective block
        address offerOwner;                                         //  Offering address
    }
    struct TokenInfo {                                              //  Token offer information
        mapping(uint256 => PriceInfo) priceInfoList;                //  Block price list, block number => block price
        uint256 latestOffer;                                        //  Latest effective block
    }
    uint256 destructionAmount = 0 ether;                            //  Amount of NEST to destroy to call prices
    uint256 effectTime = 0 days;                                    //  Waiting time to start calling prices
    mapping(address => TokenInfo) _tokenInfo;                       //  Token offer information
    mapping(address => bool) _blocklist;                            //  Block list
    mapping(address => uint256) _addressEffect;                     //  Effective time of address to call prices 
    mapping(address => bool) _offerMainMapping;                     //  Offering contract mapping
    uint256 _priceCost = 0.01 ether;                                //  Call price fee

    //  Real-time price  token, ETH amount, erc20 amount
    event NowTokenPrice(address a, uint256 b, uint256 c);
    
    /**
    * @dev Initialization method
    * @param voteFactory Voting contract address
    */
    constructor (address voteFactory) public {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;
        _offerMain = Nest_3_OfferMain(address(voteFactoryMap.checkAddress("nest.v3.offerMain")));
        _nTokeOfferMain = address(voteFactoryMap.checkAddress("nest.nToken.offerMain"));
        _abonus = Nest_3_Abonus(address(voteFactoryMap.checkAddress("nest.v3.abonus")));
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        _nTokenAuction = address(voteFactoryMap.checkAddress("nest.nToken.tokenAuction"));
        _offerMainMapping[address(_offerMain)] = true;
        _offerMainMapping[address(_nTokeOfferMain)] = true;
    }
    
    /**
    * @dev Modify voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;                                   
        _offerMain = Nest_3_OfferMain(address(voteFactoryMap.checkAddress("nest.v3.offerMain")));
        _nTokeOfferMain = address(voteFactoryMap.checkAddress("nest.nToken.offerMain"));
        _abonus = Nest_3_Abonus(address(voteFactoryMap.checkAddress("nest.v3.abonus")));
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        _nTokenAuction = address(voteFactoryMap.checkAddress("nest.nToken.tokenAuction"));
        _offerMainMapping[address(_offerMain)] = true;
        _offerMainMapping[address(_nTokeOfferMain)] = true;
    }
    
    /**
    * @dev Initialize token price charge parameters
    * @param tokenAddress Token address
    */
    function addPriceCost(address tokenAddress) public {
       
    }
    
    /**
    * @dev Add price
    * @param ethAmount ETH amount
    * @param tokenAmount Erc20 amount
    * @param endBlock Effective price block
    * @param tokenAddress Erc20 address
    * @param offerOwner Offering address
    */
    function addPrice(uint256 ethAmount, uint256 tokenAmount, uint256 endBlock, address tokenAddress, address offerOwner) public onlyOfferMain{
        // Add effective block price information
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        PriceInfo storage priceInfo = tokenInfo.priceInfoList[endBlock];
        priceInfo.ethAmount = priceInfo.ethAmount.add(ethAmount);
        priceInfo.erc20Amount = priceInfo.erc20Amount.add(tokenAmount);
        if (endBlock != tokenInfo.latestOffer) {
            // If different block offer
            priceInfo.frontBlock = tokenInfo.latestOffer;
            tokenInfo.latestOffer = endBlock;
        }
    }
    
    /**
    * @dev Price modification in taker orders
    * @param ethAmount ETH amount
    * @param tokenAmount Erc20 amount
    * @param tokenAddress Token address 
    * @param endBlock Block of effective price
    */
    function changePrice(uint256 ethAmount, uint256 tokenAmount, address tokenAddress, uint256 endBlock) public onlyOfferMain {
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        PriceInfo storage priceInfo = tokenInfo.priceInfoList[endBlock];
        priceInfo.ethAmount = priceInfo.ethAmount.sub(ethAmount);
        priceInfo.erc20Amount = priceInfo.erc20Amount.sub(tokenAmount);
    }
    
    /**
    * @dev Update and check the latest price
    * @param tokenAddress Token address
    * @return ethAmount ETH amount
    * @return erc20Amount Erc20 amount
    * @return blockNum Price block
    */
    function updateAndCheckPriceNow(address tokenAddress) public payable returns(uint256 ethAmount, uint256 erc20Amount, uint256 blockNum) {
        require(checkUseNestPrice(address(msg.sender)));
        mapping(uint256 => PriceInfo) storage priceInfoList = _tokenInfo[tokenAddress].priceInfoList;
        uint256 checkBlock = _tokenInfo[tokenAddress].latestOffer;
        while(checkBlock > 0 && (checkBlock >= block.number || priceInfoList[checkBlock].ethAmount == 0)) {
            checkBlock = priceInfoList[checkBlock].frontBlock;
        }
        require(checkBlock != 0);
        PriceInfo memory priceInfo = priceInfoList[checkBlock];
        address nToken = _tokenMapping.checkTokenMapping(tokenAddress);
        if (nToken == address(0x0)) {
            _abonus.switchToEth.value(_priceCost)(address(_nestToken));
        } else {
            _abonus.switchToEth.value(_priceCost)(address(nToken));
        }
        if (msg.value > _priceCost) {
            repayEth(address(msg.sender), msg.value.sub(_priceCost));
        }
        emit NowTokenPrice(tokenAddress,priceInfo.ethAmount, priceInfo.erc20Amount);
        return (priceInfo.ethAmount,priceInfo.erc20Amount, checkBlock);
    }
    
    /**
    * @dev Update and check the latest price-internal use
    * @param tokenAddress Token address
    * @return ethAmount ETH amount
    * @return erc20Amount Erc20 amount
    */
    function updateAndCheckPricePrivate(address tokenAddress) public view onlyOfferMain returns(uint256 ethAmount, uint256 erc20Amount) {
        mapping(uint256 => PriceInfo) storage priceInfoList = _tokenInfo[tokenAddress].priceInfoList;
        uint256 checkBlock = _tokenInfo[tokenAddress].latestOffer;
        while(checkBlock > 0 && (checkBlock >= block.number || priceInfoList[checkBlock].ethAmount == 0)) {
            checkBlock = priceInfoList[checkBlock].frontBlock;
        }
        if (checkBlock == 0) {
            return (0,0);
        }
        PriceInfo memory priceInfo = priceInfoList[checkBlock];
        return (priceInfo.ethAmount,priceInfo.erc20Amount);
    }
    
    /**
    * @dev Update and check the effective price list
    * @param tokenAddress Token address
    * @param num Number of prices to check
    * @return uint256[] price list
    */
    function updateAndCheckPriceList(address tokenAddress, uint256 num) public payable returns (uint256[] memory) {
        require(checkUseNestPrice(address(msg.sender)));
        mapping(uint256 => PriceInfo) storage priceInfoList = _tokenInfo[tokenAddress].priceInfoList;
        // Extract data
        uint256 length = num.mul(3);
        uint256 index = 0;
        uint256[] memory data = new uint256[](length);
        uint256 checkBlock = _tokenInfo[tokenAddress].latestOffer;
        while(index < length && checkBlock > 0){
            if (checkBlock < block.number && priceInfoList[checkBlock].ethAmount != 0) {
                // Add return data
                data[index++] = priceInfoList[checkBlock].ethAmount;
                data[index++] = priceInfoList[checkBlock].erc20Amount;
                data[index++] = checkBlock;
            }
            checkBlock = priceInfoList[checkBlock].frontBlock;
        }
        require(length == data.length);
        // Allocation
        address nToken = _tokenMapping.checkTokenMapping(tokenAddress);
        if (nToken == address(0x0)) {
            _abonus.switchToEth.value(_priceCost)(address(_nestToken));
        } else {
            _abonus.switchToEth.value(_priceCost)(address(nToken));
        }
        if (msg.value > _priceCost) {
            repayEth(address(msg.sender), msg.value.sub(_priceCost));
        }
        return data;
    }
    
    // Activate the price checking function
    function activation() public {
        _nestToken.safeTransferFrom(address(msg.sender), _destructionAddress, destructionAmount);
        _addressEffect[address(msg.sender)] = now.add(effectTime);
    }
    
    // Transfer ETH
    function repayEth(address accountAddress, uint256 asset) private {
        address payable addr = accountAddress.make_payable();
        addr.transfer(asset);
    }
    
    // Check block price - user account only
    function checkPriceForBlock(address tokenAddress, uint256 blockNum) public view returns (uint256 ethAmount, uint256 erc20Amount) {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        return (tokenInfo.priceInfoList[blockNum].ethAmount, tokenInfo.priceInfoList[blockNum].erc20Amount);
    }    
    
    // Check real-time price - user account only
    function checkPriceNow(address tokenAddress) public view returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum) {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        mapping(uint256 => PriceInfo) storage priceInfoList = _tokenInfo[tokenAddress].priceInfoList;
        uint256 checkBlock = _tokenInfo[tokenAddress].latestOffer;
        while(checkBlock > 0 && (checkBlock >= block.number || priceInfoList[checkBlock].ethAmount == 0)) {
            checkBlock = priceInfoList[checkBlock].frontBlock;
        }
        if (checkBlock == 0) {
            return (0,0,0);
        }
        PriceInfo storage priceInfo = priceInfoList[checkBlock];
        return (priceInfo.ethAmount,priceInfo.erc20Amount, checkBlock);
    }
    
    // Check whether the price-checking functions can be called
    function checkUseNestPrice(address target) public view returns (bool) {
        if (!_blocklist[target] && _addressEffect[target] < now && _addressEffect[target] != 0) {
            return true;
        } else {
            return false;
        }
    }
    
    // Check whether the address is in the blocklist
    function checkBlocklist(address add) public view returns(bool) {
        return _blocklist[add];
    }
    
    // Check the amount of NEST to destroy to call prices
    function checkDestructionAmount() public view returns(uint256) {
        return destructionAmount;
    }
    
    // Check the waiting time to start calling prices
    function checkEffectTime() public view returns (uint256) {
        return effectTime;
    }
    
    // Check call price fee
    function checkPriceCost() public view returns (uint256) {
        return _priceCost;
    }
    
    // Modify the blocklist 
    function changeBlocklist(address add, bool isBlock) public onlyOwner {
        _blocklist[add] = isBlock;
    }
    
    // Amount of NEST to destroy to call price-checking functions
    function changeDestructionAmount(uint256 amount) public onlyOwner {
        destructionAmount = amount;
    }
    
    // Modify the waiting time to start calling prices
    function changeEffectTime(uint256 num) public onlyOwner {
        effectTime = num;
    }
    
    // Modify call price fee
    function changePriceCost(uint256 num) public onlyOwner {
        _priceCost = num;
    }

    // Offering contract only
    modifier onlyOfferMain(){
        require(_offerMainMapping[address(msg.sender)], "No authority");
        _;
    }
    
    // Vote administrators only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender), "No authority");
        _;
    }
}

/**
 * @title NEST and NToken lock-up contract
 * @dev NEST and NToken deposit and withdrawal
 */
contract Nest_3_TokenSave {
    using SafeMath for uint256;
    
    Nest_3_VoteFactory _voteFactory;                                 //  Voting contract
    mapping(address => mapping(address => uint256))  _baseMapping;   //  Ledger token=>user=>amount
    
    /**
    * @dev initialization method
    * @param voteFactory Voting contract address
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev Reset voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev Withdrawing
    * @param num Withdrawing amount
    * @param token Lock-up token address
    * @param target Transfer target
    */
    function takeOut(uint256 num, address token, address target) public onlyContract {
        require(num <= _baseMapping[token][address(target)], "Insufficient storage balance");
        _baseMapping[token][address(target)] = _baseMapping[token][address(target)].sub(num);
        ERC20(token).transfer(address(target), num);
    }
    
    /**
    * @dev Depositing
    * @param num Depositing amount
    * @param token Lock-up token address
    * @param target Depositing target
    */
    function depositIn(uint256 num, address token, address target) public onlyContract {
        require(ERC20(token).transferFrom(address(target),address(this),num), "Authorization transfer failed");  
        _baseMapping[token][address(target)] = _baseMapping[token][address(target)].add(num);
    }
    
    /**
    * @dev Check the amount
    * @param sender Check address
    * @param token Lock-up token address
    * @return uint256 Check address corresponding lock-up limit 
    */
    function checkAmount(address sender, address token) public view returns(uint256) {
        return _baseMapping[token][address(sender)];
    }
    
    // Administrators only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
    
    // Only for bonus logic contract
    modifier onlyContract(){
        require(_voteFactory.checkAddress("nest.v3.tokenAbonus") == address(msg.sender), "No authority");
        _;
    }
}

/**
 * @title Dividend logic
 * @dev Some operations about dividend,logic and asset separation
 */
contract Nest_3_TokenAbonus {
    using address_make_payable for address;
    using SafeMath for uint256;
    
    ERC20 _nestContract;
    Nest_3_TokenSave _tokenSave;                                                                //  Lock-up contract
    Nest_3_Abonus _abonusContract;                                                              //  ETH bonus pool
    Nest_3_VoteFactory _voteFactory;                                                            //  Voting contract
    Nest_3_Leveling _nestLeveling;                                                              //  Leveling contract
    address _destructionAddress;                                                                //  Destroy contract address
    
    uint256 _timeLimit = 168 hours;                                                             //  Bonus period
    uint256 _nextTime = 1596168000;                                                             //  Next bonus time
    uint256 _getAbonusTimeLimit = 60 hours;                                                     //  During of triggering calculation of bonus
    uint256 _times = 0;                                                                         //  Bonus ledger
    uint256 _expectedIncrement = 3;                                                             //  Expected bonus increment ratio
    uint256 _expectedSpanForNest = 100000000 ether;                                             //  NEST expected bonus increment threshold
    uint256 _expectedSpanForNToken = 1000000 ether;                                             //  NToken expected bonus increment threshold
    uint256 _expectedMinimum = 100 ether;                                                       //  Expected minimum bonus
    uint256 _savingLevelOne = 10;                                                               //  Saving threshold level 1
    uint256 _savingLevelTwo = 20;                                                               //  Saving threshold level 2 
    uint256 _savingLevelTwoSub = 100 ether;                                                     //  Function parameters of savings threshold level 2  
    uint256 _savingLevelThree = 30;                                                             //  Function parameters of savings threshold level 3
    uint256 _savingLevelThreeSub = 600 ether;                                                   //  Function parameters of savings threshold level 3
    
    mapping(address => uint256) _abonusMapping;                                                 //  Bonus pool snapshot - token address (NEST or NToken) => number of ETH in the bonus pool 
    mapping(address => uint256) _tokenAllValueMapping;                                          //  Number of tokens (circulation) - token address (NEST or NToken) ) => total circulation 
    mapping(address => mapping(uint256 => uint256)) _tokenAllValueHistory;                      //  NEST or NToken circulation snapshot - token address (NEST or NToken) => number of periods => total circulation 
    mapping(address => mapping(uint256 => mapping(address => uint256))) _tokenSelfHistory;      //  Personal lockup - NEST or NToken snapshot token address (NEST or NToken) => period => user address => total circulation
    mapping(address => mapping(uint256 => bool)) _snapshot;                                     //  Whether snapshot - token address (NEST or NToken) => number of periods => whether to take a snapshot
    mapping(uint256 => mapping(address => mapping(address => bool))) _getMapping;               //  Receiving records - period => token address (NEST or NToken) => user address => whether received
    
    //  Log token address, amount
    event GetTokenLog(address tokenAddress, uint256 tokenAmount);
    
   /**
    * @dev Initialization method
    * @param voteFactory Voting contract address
    */
    constructor (address voteFactory) public {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap; 
        _nestContract = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _tokenSave = Nest_3_TokenSave(address(voteFactoryMap.checkAddress("nest.v3.tokenSave")));
        address payable addr = address(voteFactoryMap.checkAddress("nest.v3.abonus")).make_payable();
        _abonusContract = Nest_3_Abonus(addr);
        address payable levelingAddr = address(voteFactoryMap.checkAddress("nest.v3.leveling")).make_payable();
        _nestLeveling = Nest_3_Leveling(levelingAddr);
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
    }
    
    /**
    * @dev Modify voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap; 
        _nestContract = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _tokenSave = Nest_3_TokenSave(address(voteFactoryMap.checkAddress("nest.v3.tokenSave")));
        address payable addr = address(voteFactoryMap.checkAddress("nest.v3.abonus")).make_payable();
        _abonusContract = Nest_3_Abonus(addr);
        address payable levelingAddr = address(voteFactoryMap.checkAddress("nest.v3.leveling")).make_payable();
        _nestLeveling = Nest_3_Leveling(levelingAddr);
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
    }
    
    /**
    * @dev Deposit 
    * @param amount Deposited amount
    * @param token Locked token address
    */
    function depositIn(uint256 amount, address token) public {
        uint256 nowTime = now;
        uint256 nextTime = _nextTime;
        uint256 timeLimit = _timeLimit;
        if (nowTime < nextTime) {
            //  Bonus triggered
            require(!(nowTime >= nextTime.sub(timeLimit) && nowTime <= nextTime.sub(timeLimit).add(_getAbonusTimeLimit)));
        } else {
            //  Bonus not triggered
            uint256 times = (nowTime.sub(_nextTime)).div(_timeLimit);
            //  Calculate the time when bonus should be started
            uint256 startTime = _nextTime.add((times).mul(_timeLimit));  
            //  Calculate the time when bonus should be stopped
            uint256 endTime = startTime.add(_getAbonusTimeLimit);                                                                    
            require(!(nowTime >= startTime && nowTime <= endTime));
        }
        _tokenSave.depositIn(amount, token, address(msg.sender));                 
    }
    
    /**
    * @dev Withdrawing
    * @param amount Withdrawing amount
    * @param token Token address
    */
    function takeOut(uint256 amount, address token) public {
        require(amount > 0, "Parameter needs to be greater than 0");                                                                
        require(amount <= _tokenSave.checkAmount(address(msg.sender), token), "Insufficient storage balance");
        if (token == address(_nestContract)) {
            require(!_voteFactory.checkVoteNow(address(tx.origin)), "Voting");
        }
        _tokenSave.takeOut(amount, token, address(msg.sender));                                                             
    }                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
    
    /**
    * @dev Receiving
    * @param token Receiving token address
    */
    function getAbonus(address token) public {
        uint256 tokenAmount = _tokenSave.checkAmount(address(msg.sender), token);
        require(tokenAmount > 0, "Insufficient storage balance");
        reloadTime();
        reloadToken(token);                                                                                                      
        uint256 nowTime = now;
        require(nowTime >= _nextTime.sub(_timeLimit) && nowTime <= _nextTime.sub(_timeLimit).add(_getAbonusTimeLimit), "Not time to draw");
        require(!_getMapping[_times.sub(1)][token][address(msg.sender)], "Have received");                                     
        _tokenSelfHistory[token][_times.sub(1)][address(msg.sender)] = tokenAmount;                                         
        require(_tokenAllValueMapping[token] > 0, "Total flux error");
        uint256 selfNum = tokenAmount.mul(_abonusMapping[token]).div(_tokenAllValueMapping[token]);
        require(selfNum > 0, "No limit available");
        _getMapping[_times.sub(1)][token][address(msg.sender)] = true;
        _abonusContract.getETH(selfNum, token,address(msg.sender)); 
        emit GetTokenLog(token, selfNum);
    }
    
    /**
    * @dev Update bonus time and stage ledger
    */
    function reloadTime() private {
        uint256 nowTime = now;
        //  The current time must exceed the bonus time
        if (nowTime >= _nextTime) {                                                                                                 
            uint256 time = (nowTime.sub(_nextTime)).div(_timeLimit);
            uint256 startTime = _nextTime.add((time).mul(_timeLimit));                                                              
            uint256 endTime = startTime.add(_getAbonusTimeLimit);                                                                   
            if (nowTime >= startTime && nowTime <= endTime) {
                _nextTime = getNextTime();                                                                                      
                _times = _times.add(1);                                                                                       
            }
        }
    }
    
    /**
    * @dev Snapshot of the amount of tokens
    * @param token Receiving token address
    */
    function reloadToken(address token) private {
        if (!_snapshot[token][_times.sub(1)]) {
            levelingResult(token);                                                                                          
            _abonusMapping[token] = _abonusContract.getETHNum(token); 
            _tokenAllValueMapping[token] = allValue(token);
            _tokenAllValueHistory[token][_times.sub(1)] = allValue(token);
            _snapshot[token][_times.sub(1)] = true;
        }
    }
    
    /**
    * @dev Leveling settlement
    * @param token Receiving token address
    */
    function levelingResult(address token) private {
        uint256 steps;
        if (token == address(_nestContract)) {
            steps = allValue(token).div(_expectedSpanForNest);
        } else {
            steps = allValue(token).div(_expectedSpanForNToken);
        }
        uint256 minimumAbonus = _expectedMinimum;
        for (uint256 i = 0; i < steps; i++) {
            minimumAbonus = minimumAbonus.add(minimumAbonus.mul(_expectedIncrement).div(100));
        }
        uint256 thisAbonus = _abonusContract.getETHNum(token);
        if (thisAbonus > minimumAbonus) {
            uint256 levelAmount = 0;
            if (thisAbonus > 5000 ether) {
                levelAmount = thisAbonus.mul(_savingLevelThree).div(100).sub(_savingLevelThreeSub);
            } else if (thisAbonus > 1000 ether) {
                levelAmount = thisAbonus.mul(_savingLevelTwo).div(100).sub(_savingLevelTwoSub);
            } else {
                levelAmount = thisAbonus.mul(_savingLevelOne).div(100);
            }
            if (thisAbonus.sub(levelAmount) < minimumAbonus) {
                _abonusContract.getETH(thisAbonus.sub(minimumAbonus), token, address(this));
                _nestLeveling.switchToEth.value(thisAbonus.sub(minimumAbonus))(token);
            } else {
                _abonusContract.getETH(levelAmount, token, address(this));
                _nestLeveling.switchToEth.value(levelAmount)(token);
            }
        } else {
            uint256 ethValue = _nestLeveling.tranEth(minimumAbonus.sub(thisAbonus), token, address(this));
            _abonusContract.switchToEth.value(ethValue)(token);
        }
    }
    
     // Next bonus time, current bonus deadline, ETH number, NEST number, NEST participating in bonus, bonus to receive, approved amount, balance, whether bonus can be paid 
    function getInfo(address token) public view returns (uint256 nextTime, uint256 getAbonusTime, uint256 ethNum, uint256 tokenValue, uint256 myJoinToken, uint256 getEth, uint256 allowNum, uint256 leftNum, bool allowAbonus)  {
        uint256 nowTime = now;
        if (nowTime >= _nextTime.sub(_timeLimit) && nowTime <= _nextTime.sub(_timeLimit).add(_getAbonusTimeLimit) && _times > 0 && _snapshot[token][_times.sub(1)]) {
            //  Bonus have been triggered, and during the time of this bonus, display snapshot data 
            allowAbonus = _getMapping[_times.sub(1)][token][address(msg.sender)];
            ethNum = _abonusMapping[token];
            tokenValue = _tokenAllValueMapping[token];
        } else {
            //  Display real-time data 
            ethNum = _abonusContract.getETHNum(token);
            tokenValue = allValue(token);
            allowAbonus = _getMapping[_times][token][address(msg.sender)];
        }
        myJoinToken = _tokenSave.checkAmount(address(msg.sender), token);
        if (allowAbonus == true) {
            getEth = 0; 
        } else {
            getEth = myJoinToken.mul(ethNum).div(tokenValue);
        }
        nextTime = getNextTime();
        getAbonusTime = nextTime.sub(_timeLimit).add(_getAbonusTimeLimit);
        allowNum = ERC20(token).allowance(address(msg.sender), address(_tokenSave));
        leftNum = ERC20(token).balanceOf(address(msg.sender));
    }
    
    /**
    * @dev View next bonus time 
    * @return Next bonus time 
    */
    function getNextTime() public view returns (uint256) {
        uint256 nowTime = now;
        if (_nextTime > nowTime) { 
            return _nextTime; 
        } else {
            uint256 time = (nowTime.sub(_nextTime)).div(_timeLimit);
            return _nextTime.add(_timeLimit.mul(time.add(1)));
        }
    }
    
    /**
    * @dev View total circulation 
    * @return Total circulation
    */
    function allValue(address token) public view returns (uint256) {
        if (token == address(_nestContract)) {
            uint256 all = 10000000000 ether;
            uint256 leftNum = all.sub(_nestContract.balanceOf(address(_voteFactory.checkAddress("nest.v3.miningSave")))).sub(_nestContract.balanceOf(address(_destructionAddress)));
            return leftNum;
        } else {
            return ERC20(token).totalSupply();
        }
    }
    
    /**
    * @dev View bonus period
    * @return Bonus period
    */
    function checkTimeLimit() public view returns (uint256) {
        return _timeLimit;
    }
    
    /**
    * @dev View duration of triggering calculation of bonus
    * @return Bonus period
    */
    function checkGetAbonusTimeLimit() public view returns (uint256) {
        return _getAbonusTimeLimit;
    }
    
    /**
    * @dev View current lowest expected bonus
    * @return Current lowest expected bonus
    */
    function checkMinimumAbonus(address token) public view returns (uint256) {
        uint256 miningAmount;
        if (token == address(_nestContract)) {
            miningAmount = allValue(token).div(_expectedSpanForNest);
        } else {
            miningAmount = allValue(token).div(_expectedSpanForNToken);
        }
        uint256 minimumAbonus = _expectedMinimum;
        for (uint256 i = 0; i < miningAmount; i++) {
            minimumAbonus = minimumAbonus.add(minimumAbonus.mul(_expectedIncrement).div(100));
        }
        return minimumAbonus;
    }
    
    /**
    * @dev Check whether the bonus token is snapshoted
    * @param token Token address
    * @return Whether snapshoted
    */
    function checkSnapshot(address token) public view returns (bool) {
        return _snapshot[token][_times.sub(1)];
    }
    
    /**
    * @dev Check the expected bonus incremental ratio
    * @return Expected bonus increment ratio
    */
    function checkeExpectedIncrement() public view returns (uint256) {
        return _expectedIncrement;
    }
    
    /**
    * @dev View expected minimum bonus
    * @return Expected minimum bonus
    */
    function checkExpectedMinimum() public view returns (uint256) {
        return _expectedMinimum;
    }
    
    /**
    * @dev View savings threshold
    * @return Save threshold
    */
    function checkSavingLevelOne() public view returns (uint256) {
        return _savingLevelOne;
    }
    function checkSavingLevelTwo() public view returns (uint256) {
        return _savingLevelTwo;
    }
    function checkSavingLevelThree() public view returns (uint256) {
        return _savingLevelThree;
    }
    
    /**
    * @dev View NEST liquidity snapshot
    * @param token Locked token address
    * @param times Bonus snapshot period
    */
    function checkTokenAllValueHistory(address token, uint256 times) public view returns (uint256) {
        return _tokenAllValueHistory[token][times];
    }
    
    /**
    * @dev View personal lock-up NEST snapshot
    * @param times Bonus snapshot period
    * @param user User address
    * @return The number of personal locked NEST snapshots
    */
    function checkTokenSelfHistory(address token, uint256 times, address user) public view returns (uint256) {
        return _tokenSelfHistory[token][times][user];
    }
    
    // View the period number of bonus
    function checkTimes() public view returns (uint256) {
        return _times;
    }
    
    // NEST expected bonus increment threshold
    function checkExpectedSpanForNest() public view returns (uint256) {
        return _expectedSpanForNest;
    }
    
    // NToken expected bonus increment threshold
    function checkExpectedSpanForNToken() public view returns (uint256) {
        return _expectedSpanForNToken;
    }
    
    // View the function parameters of savings threshold level 3
    function checkSavingLevelTwoSub() public view returns (uint256) {
        return _savingLevelTwoSub;
    }
    
    // View the function parameters of savings threshold level 3
    function checkSavingLevelThreeSub() public view returns (uint256) {
        return _savingLevelThreeSub;
    }
    
    /**
    * @dev Update bonus period
    * @param hour Bonus period (hours)
    */
    function changeTimeLimit(uint256 hour) public onlyOwner {
        require(hour > 0, "Parameter needs to be greater than 0");
        _timeLimit = hour.mul(1 hours);
    }
    
    /**
    * @dev Update collection period
    * @param hour Collection period (hours)
    */
    function changeGetAbonusTimeLimit(uint256 hour) public onlyOwner {
        require(hour > 0, "Parameter needs to be greater than 0");
        _getAbonusTimeLimit = hour;
    }
    
    /**
    * @dev Update expected bonus increment ratio
    * @param num Expected bonus increment ratio
    */
    function changeExpectedIncrement(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _expectedIncrement = num;
    }
    
    /**
    * @dev Update expected minimum bonus
    * @param num Expected minimum bonus
    */
    function changeExpectedMinimum(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _expectedMinimum = num;
    }
    
    /**
    * @dev  Update saving threshold
    * @param threshold Saving threshold
    */
    function changeSavingLevelOne(uint256 threshold) public onlyOwner {
        _savingLevelOne = threshold;
    }
    function changeSavingLevelTwo(uint256 threshold) public onlyOwner {
        _savingLevelTwo = threshold;
    }
    function changeSavingLevelThree(uint256 threshold) public onlyOwner {
        _savingLevelThree = threshold;
    }
    
    /**
    * @dev Update the function parameters of savings threshold level 2
    */
    function changeSavingLevelTwoSub(uint256 num) public onlyOwner {
        _savingLevelTwoSub = num;
    }
    
    /**
    * @dev Update the function parameters of savings threshold level 3
    */
    function changeSavingLevelThreeSub(uint256 num) public onlyOwner {
        _savingLevelThreeSub = num;
    }
    
    /**
    * @dev Update NEST expected bonus incremental threshold
    * @param num Threshold
    */
    function changeExpectedSpanForNest(uint256 num) public onlyOwner {
        _expectedSpanForNest = num;
    }
    
    /**
    * @dev Update NToken expected bonus incremental threshold
    * @param num Threshold
    */
    function changeExpectedSpanForNToken(uint256 num) public onlyOwner {
        _expectedSpanForNToken = num;
    }
    
    receive() external payable {
        
    }
    
    // Administrator only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
}

/**
 * @title ETH bonus pool
 * @dev ETH collection and inquiry
 */
contract Nest_3_Abonus {
    using address_make_payable for address;
    using SafeMath for uint256;
    
    Nest_3_VoteFactory _voteFactory;                                //  Voting contract
    address _nestAddress;                                           //  NEST contract address
    mapping (address => uint256) ethMapping;                        //  ETH bonus ledger of corresponding tokens
    uint256 _mostDistribution = 40;                                 //  The highest allocation ratio of NEST bonus pool
    uint256 _leastDistribution = 20;                                //  The lowest allocation ratio of NEST bonus pool
    uint256 _distributionTime = 1200000;                            //  The decay time interval of NEST bonus pool allocation ratio 
    uint256 _distributionSpan = 5;                                  //  The decay degree of NEST bonus pool allocation ratio
    
    /**
    * @dev Initialization method
    * @param voteFactory Voting contract address
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory);
        _nestAddress = address(_voteFactory.checkAddress("nest"));
    }
 
    /**
    * @dev Reset voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner{
        _voteFactory = Nest_3_VoteFactory(voteFactory);
        _nestAddress = address(_voteFactory.checkAddress("nest"));
    }
    
    /**
    * @dev Transfer in bonus
    * @param token Corresponding to lock-up Token
    */
    function switchToEth(address token) public payable {
        ethMapping[token] = ethMapping[token].add(msg.value);
    }
    
    /**
    * @dev Transferin bonus - NToken offering fee
    * @param token Corresponding to lock-up NToken
    */
    function switchToEthForNTokenOffer(address token) public payable {
        Nest_NToken nToken = Nest_NToken(token);
        (uint256 createBlock,) = nToken.checkBlockInfo();
        uint256 subBlock = block.number.sub(createBlock);
        uint256 times = subBlock.div(_distributionTime);
        uint256 distributionValue = times.mul(_distributionSpan);
        uint256 distribution = _mostDistribution;
        if (_leastDistribution.add(distributionValue) > _mostDistribution) {
            distribution = _leastDistribution;
        } else {
            distribution = _mostDistribution.sub(distributionValue);
        }
        uint256 nestEth = msg.value.mul(distribution).div(100);
        ethMapping[_nestAddress] = ethMapping[_nestAddress].add(nestEth);
        ethMapping[token] = ethMapping[token].add(msg.value.sub(nestEth));
    }
    
    /**
    * @dev Receive ETH
    * @param num Receive amount 
    * @param token Correspond to locked Token
    * @param target Transfer target
    */
    function getETH(uint256 num, address token, address target) public onlyContract {
        require(num <= ethMapping[token], "Insufficient storage balance");
        ethMapping[token] = ethMapping[token].sub(num);
        address payable addr = target.make_payable();
        addr.transfer(num);
    }
    
    /**
    * @dev Get bonus pool balance
    * @param token Corresponded locked Token
    * @return uint256 Bonus pool balance
    */
    function getETHNum(address token) public view returns (uint256) {
        return ethMapping[token];
    }
    
    // View NEST address
    function checkNestAddress() public view returns(address) {
        return _nestAddress;
    }
    
    // View the highest NEST bonus pool allocation ratio
    function checkMostDistribution() public view returns(uint256) {
        return _mostDistribution;
    }
    
    // View the lowest NEST bonus pool allocation ratio
    function checkLeastDistribution() public view returns(uint256) {
        return _leastDistribution;
    }
    
    // View the decay time interval of NEST bonus pool allocation ratio 
    function checkDistributionTime() public view returns(uint256) {
        return _distributionTime;
    }
    
    // View the decay degree of NEST bonus pool allocation ratio
    function checkDistributionSpan() public view returns(uint256) {
        return _distributionSpan;
    }
    
    // Modify the highest NEST bonus pool allocation ratio
    function changeMostDistribution(uint256 num) public onlyOwner  {
        _mostDistribution = num;
    }
    
    // Modify the lowest NEST bonus pool allocation ratio
    function changeLeastDistribution(uint256 num) public onlyOwner  {
        _leastDistribution = num;
    }
    
    // Modify the decay time interval of NEST bonus pool allocation ratio 
    function changeDistributionTime(uint256 num) public onlyOwner  {
        _distributionTime = num;
    }
    
    // Modify the decay degree of NEST bonus pool allocation ratio
    function changeDistributionSpan(uint256 num) public onlyOwner  {
        _distributionSpan = num;
    }
    
    // Withdraw ETH
    function turnOutAllEth(uint256 amount, address target) public onlyOwner {
        address payable addr = target.make_payable();
        addr.transfer(amount);  
    }
    
    // Only bonus logic contract
    modifier onlyContract(){
        require(_voteFactory.checkAddress("nest.v3.tokenAbonus") == address(msg.sender), "No authority");
        _;
    }
    
    // Administrator only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
}

/**
 * @title Leveling contract
 * @dev ETH transfer in and transfer out
 */
contract Nest_3_Leveling {
    using address_make_payable for address;
    using SafeMath for uint256;
    Nest_3_VoteFactory _voteFactory;                                //  Vote contract
    mapping (address => uint256) ethMapping;                        //  Corresponded ETH leveling ledger of token
    
    /**
    * @dev Initialization method
    * @param voteFactory Voting contract address
    */
    constructor (address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev Modifying voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev Transfer out leveling
    * @param amount Transfer-out amount
    * @param token Corresponding lock-up token
    * @param target Transfer-out target
    */
    function tranEth(uint256 amount, address token, address target) public returns (uint256) {
        require(address(msg.sender) == address(_voteFactory.checkAddress("nest.v3.tokenAbonus")), "No authority");
        uint256 tranAmount = amount;
        if (tranAmount > ethMapping[token]) {
            tranAmount = ethMapping[token];
        }
        ethMapping[token] = ethMapping[token].sub(tranAmount);
        address payable addr = target.make_payable();
        addr.transfer(tranAmount);
        return tranAmount;
    }
    
    /**
    * @dev Transfer in leveling 
    * @param token Corresponded locked token
    */
    function switchToEth(address token) public payable {
        ethMapping[token] = ethMapping[token].add(msg.value);
    }
    
    //  Check the leveled amount corresponding to the token
    function checkEthMapping(address token) public view returns (uint256) {
        return ethMapping[token];
    }
    
    //  Withdraw ETH
    function turnOutAllEth(uint256 amount, address target) public onlyOwner {
        address payable addr = target.make_payable();
        addr.transfer(amount);  
    }
    
    //  Administrator only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
}

/**
 * @title Offering contract
 * @dev Offering logic and mining logic
 */
contract Nest_NToken_OfferMain {
    
    using SafeMath for uint256;
    using address_make_payable for address;
    using SafeERC20 for ERC20;
    
    // Offering data structure
    struct Nest_NToken_OfferPriceData {
        // The unique identifier is determined by the position of the offer in the array, and is converted to each other through a fixed algorithm (toindex(), toaddress())
        address owner;                                  //  Offering owner
        bool deviate;                                   //  Whether it deviates 
        address tokenAddress;                           //  The erc20 contract address of the target offer token
        
        uint256 ethAmount;                              //  The ETH amount in the offer list
        uint256 tokenAmount;                            //  The token amount in the offer list
        
        uint256 dealEthAmount;                          //  The remaining number of tradable ETH
        uint256 dealTokenAmount;                        //  The remaining number of tradable tokens
        
        uint256 blockNum;                               //  The block number where the offer is located
        uint256 serviceCharge;                          //  The fee for mining
        // Determine whether the asset has been collected by judging that ethamount, tokenamount, and servicecharge are all 0
    }
    
    Nest_NToken_OfferPriceData [] _prices;                              //  Array used to save offers
    Nest_3_VoteFactory _voteFactory;                                    //  Voting contract
    Nest_3_OfferPrice _offerPrice;                                      //  Price contract
    Nest_NToken_TokenMapping _tokenMapping;                             //  NToken mapping contract
    ERC20 _nestToken;                                                   //  nestToken
    Nest_3_Abonus _abonus;                                              //  Bonus pool
    uint256 _miningETH = 10;                                            //  Offering mining fee ratio
    uint256 _tranEth = 1;                                               //  Taker fee ratio
    uint256 _tranAddition = 2;                                          //  Additional transaction multiple
    uint256 _leastEth = 10 ether;                                       //  Minimum offer of ETH
    uint256 _offerSpan = 10 ether;                                      //  ETH Offering span
    uint256 _deviate = 10;                                              //  Price deviation - 10%
    uint256 _deviationFromScale = 10;                                   //  Deviation from asset scale
    uint256 _ownerMining = 5;                                           //  Creator ratio
    uint256 _afterMiningAmount = 0.4 ether;                             //  Stable period mining amount
    uint32 _blockLimit = 25;                                            //  Block interval upper limit
    
    uint256 _blockAttenuation = 2400000;                                //  Block decay interval
    mapping(uint256 => mapping(address => uint256)) _blockOfferAmount;  //  Block offer times - block number=>token address=>offer fee
    mapping(uint256 => mapping(address => uint256)) _blockMining;       //  Offering block mining amount - block number=>token address=>mining amount
    uint256[10] _attenuationAmount;                                     //  Mining decay list
    
    //  Log token contract address
    event OfferTokenContractAddress(address contractAddress);           
    //  Log offering contract, token address, amount of ETH, amount of ERC20, delayed block, mining fee
    event OfferContractAddress(address contractAddress, address tokenAddress, uint256 ethAmount, uint256 erc20Amount, uint256 continued,uint256 mining);         
    //  Log transaction sender, transaction token, transaction amount, purchase token address, purchase token amount, transaction offering contract address, transaction user address
    event OfferTran(address tranSender, address tranToken, uint256 tranAmount,address otherToken, uint256 otherAmount, address tradedContract, address tradedOwner);        
    //  Log current block, current block mined amount, token address
    event OreDrawingLog(uint256 nowBlock, uint256 blockAmount, address tokenAddress);
    //  Log offering block, token address, token offered times
    event MiningLog(uint256 blockNum, address tokenAddress, uint256 offerTimes);
    
    /**
     * Initialization method
     * @param voteFactory Voting contract address
     **/
    constructor (address voteFactory) public {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;                                                                 
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));            
        _nestToken = ERC20(voteFactoryMap.checkAddress("nest"));                                                          
        _abonus = Nest_3_Abonus(voteFactoryMap.checkAddress("nest.v3.abonus"));
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        
        uint256 blockAmount = 4 ether;
        for (uint256 i = 0; i < 10; i ++) {
            _attenuationAmount[i] = blockAmount;
            blockAmount = blockAmount.mul(8).div(10);
        }
    }
    
    /**
     * Reset voting contract method
     * @param voteFactory Voting contract address
     **/
    function changeMapping(address voteFactory) public onlyOwner {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;                                                          
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));      
        _nestToken = ERC20(voteFactoryMap.checkAddress("nest"));                                                   
        _abonus = Nest_3_Abonus(voteFactoryMap.checkAddress("nest.v3.abonus"));
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
    }
    
    /**
     * Offering method
     * @param ethAmount ETH amount
     * @param erc20Amount Erc20 token amount
     * @param erc20Address Erc20 token address
     **/
    function offer(uint256 ethAmount, uint256 erc20Amount, address erc20Address) public payable {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        address nTokenAddress = _tokenMapping.checkTokenMapping(erc20Address);
        require(nTokenAddress != address(0x0));
        //  Judge whether the price deviates
        uint256 ethMining;
        bool isDeviate = comparativePrice(ethAmount,erc20Amount,erc20Address);
        if (isDeviate) {
            require(ethAmount >= _leastEth.mul(_deviationFromScale), "EthAmount needs to be no less than 10 times of the minimum scale");
            ethMining = _leastEth.mul(_miningETH).div(1000);
        } else {
            ethMining = ethAmount.mul(_miningETH).div(1000);
        }
        require(msg.value >= ethAmount.add(ethMining), "msg.value needs to be equal to the quoted eth quantity plus Mining handling fee");
        uint256 subValue = msg.value.sub(ethAmount.add(ethMining));
        if (subValue > 0) {
            repayEth(address(msg.sender), subValue);
        }
        //  Create an offer
        createOffer(ethAmount, erc20Amount, erc20Address,isDeviate, ethMining);
        //  Transfer in offer asset - erc20 to this contract
        ERC20(erc20Address).safeTransferFrom(address(msg.sender), address(this), erc20Amount);
        _abonus.switchToEthForNTokenOffer.value(ethMining)(nTokenAddress);
        //  Mining
        if (_blockOfferAmount[block.number][erc20Address] == 0) {
            uint256 miningAmount = oreDrawing(nTokenAddress);
            Nest_NToken nToken = Nest_NToken(nTokenAddress);
            nToken.transfer(nToken.checkBidder(), miningAmount.mul(_ownerMining).div(100));
            _blockMining[block.number][erc20Address] = miningAmount.sub(miningAmount.mul(_ownerMining).div(100));
        }
        _blockOfferAmount[block.number][erc20Address] = _blockOfferAmount[block.number][erc20Address].add(ethMining);
    }
    
    /**
     * @dev Create offer
     * @param ethAmount Offering ETH amount
     * @param erc20Amount Offering erc20 amount
     * @param erc20Address Offering erc20 address
     **/
    function createOffer(uint256 ethAmount, uint256 erc20Amount, address erc20Address, bool isDeviate, uint256 mining) private {
        // Check offer conditions
        require(ethAmount >= _leastEth, "Eth scale is smaller than the minimum scale");                                                 
        require(ethAmount % _offerSpan == 0, "Non compliant asset span");
        require(erc20Amount % (ethAmount.div(_offerSpan)) == 0, "Asset quantity is not divided");
        require(erc20Amount > 0);
        // Create offering contract
        emit OfferContractAddress(toAddress(_prices.length), address(erc20Address), ethAmount, erc20Amount,_blockLimit,mining);
        _prices.push(Nest_NToken_OfferPriceData(
            msg.sender,
            isDeviate,
            erc20Address,
            
            ethAmount,
            erc20Amount,
            
            ethAmount, 
            erc20Amount, 
            
            block.number,
            mining
        ));
        // Record price
        _offerPrice.addPrice(ethAmount, erc20Amount, block.number.add(_blockLimit), erc20Address, address(msg.sender));
    }
    
    // Convert offer address into index in offer array
    function toIndex(address contractAddress) public pure returns(uint256) {
        return uint256(contractAddress);
    }
    
    // Convert index in offer array into offer address 
    function toAddress(uint256 index) public pure returns(address) {
        return address(index);
    }
    
    /**
     * Withdraw offer assets
     * @param contractAddress Offer address
     **/
    function turnOut(address contractAddress) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        uint256 index = toIndex(contractAddress);
        Nest_NToken_OfferPriceData storage offerPriceData = _prices[index];
        require(checkContractState(offerPriceData.blockNum) == 1, "Offer status error");
        // Withdraw ETH
        if (offerPriceData.ethAmount > 0) {
            uint256 payEth = offerPriceData.ethAmount;
            offerPriceData.ethAmount = 0;
            repayEth(offerPriceData.owner, payEth);
        }
        // Withdraw erc20
        if (offerPriceData.tokenAmount > 0) {
            uint256 payErc = offerPriceData.tokenAmount;
            offerPriceData.tokenAmount = 0;
            ERC20(address(offerPriceData.tokenAddress)).safeTransfer(address(offerPriceData.owner), payErc);
            
        }
        // Mining settlement
        if (offerPriceData.serviceCharge > 0) {
            mining(offerPriceData.blockNum, offerPriceData.tokenAddress, offerPriceData.serviceCharge, offerPriceData.owner);
            offerPriceData.serviceCharge = 0;
        }
    }
    
    /**
    * @dev Taker order - pay ETH and buy erc20
    * @param ethAmount The amount of ETH of this offer
    * @param tokenAmount The amount of erc20 of this offer
    * @param contractAddress The target offer address
    * @param tranEthAmount The amount of ETH of taker order
    * @param tranTokenAmount The amount of erc20 of taker order
    * @param tranTokenAddress The erc20 address of taker order
    */
    function sendEthBuyErc(uint256 ethAmount, uint256 tokenAmount, address contractAddress, uint256 tranEthAmount, uint256 tranTokenAmount, address tranTokenAddress) public payable {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        uint256 serviceCharge = tranEthAmount.mul(_tranEth).div(1000);
        require(msg.value == ethAmount.add(tranEthAmount).add(serviceCharge), "msg.value needs to be equal to the quotation eth quantity plus transaction eth plus");
        require(tranEthAmount % _offerSpan == 0, "Transaction size does not meet asset span");
        
        //  Get the offer data structure
        uint256 index = toIndex(contractAddress);
        Nest_NToken_OfferPriceData memory offerPriceData = _prices[index]; 
        //  Check the price, compare the current offer to the last effective price
        bool thisDeviate = comparativePrice(ethAmount,tokenAmount,tranTokenAddress);
        bool isDeviate;
        if (offerPriceData.deviate == true) {
            isDeviate = true;
        } else {
            isDeviate = thisDeviate;
        }
        //  Limit the taker order only be twice the amount of the offer to prevent large-amount attacks
        if (offerPriceData.deviate) {
            //  The taker order deviates  x2
            require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
        } else {
            if (isDeviate) {
                //  If the taken offer is normal and the taker order deviates x10
                require(ethAmount >= tranEthAmount.mul(_deviationFromScale), "EthAmount needs to be no less than 10 times of transaction scale");
            } else {
                //  If the taken offer is normal and the taker order is normal x2
                require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
            }
        }
        
        // Check whether the conditions for taker order are satisfied
        require(checkContractState(offerPriceData.blockNum) == 0, "Offer status error");
        require(offerPriceData.dealEthAmount >= tranEthAmount, "Insufficient trading eth");
        require(offerPriceData.dealTokenAmount >= tranTokenAmount, "Insufficient trading token");
        require(offerPriceData.tokenAddress == tranTokenAddress, "Wrong token address");
        require(tranTokenAmount == offerPriceData.dealTokenAmount * tranEthAmount / offerPriceData.dealEthAmount, "Wrong token amount");
        
        // Update the offer information
        offerPriceData.ethAmount = offerPriceData.ethAmount.add(tranEthAmount);
        offerPriceData.tokenAmount = offerPriceData.tokenAmount.sub(tranTokenAmount);
        offerPriceData.dealEthAmount = offerPriceData.dealEthAmount.sub(tranEthAmount);
        offerPriceData.dealTokenAmount = offerPriceData.dealTokenAmount.sub(tranTokenAmount);
        _prices[index] = offerPriceData;
        // Create a new offer
        createOffer(ethAmount, tokenAmount, tranTokenAddress, isDeviate, 0);
        // Transfer in erc20 + offer asset to this contract
        if (tokenAmount > tranTokenAmount) {
            ERC20(tranTokenAddress).safeTransferFrom(address(msg.sender), address(this), tokenAmount.sub(tranTokenAmount));
        } else {
            ERC20(tranTokenAddress).safeTransfer(address(msg.sender), tranTokenAmount.sub(tokenAmount));
        }

        // Modify price
        _offerPrice.changePrice(tranEthAmount, tranTokenAmount, tranTokenAddress, offerPriceData.blockNum.add(_blockLimit));
        emit OfferTran(address(msg.sender), address(0x0), tranEthAmount, address(tranTokenAddress), tranTokenAmount, contractAddress, offerPriceData.owner);
        
        // Transfer fee
        if (serviceCharge > 0) {
            address nTokenAddress = _tokenMapping.checkTokenMapping(tranTokenAddress);
            _abonus.switchToEth.value(serviceCharge)(nTokenAddress);
        }
    }
    
    /**
    * @dev Taker order - pay erc20 and buy ETH
    * @param ethAmount The amount of ETH of this offer
    * @param tokenAmount The amount of erc20 of this offer
    * @param contractAddress The target offer address
    * @param tranEthAmount The amount of ETH of taker order
    * @param tranTokenAmount The amount of erc20 of taker order
    * @param tranTokenAddress The erc20 address of taker order
    */
    function sendErcBuyEth(uint256 ethAmount, uint256 tokenAmount, address contractAddress, uint256 tranEthAmount, uint256 tranTokenAmount, address tranTokenAddress) public payable {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        uint256 serviceCharge = tranEthAmount.mul(_tranEth).div(1000);
        require(msg.value == ethAmount.sub(tranEthAmount).add(serviceCharge), "msg.value needs to be equal to the quoted eth quantity plus transaction handling fee");
        require(tranEthAmount % _offerSpan == 0, "Transaction size does not meet asset span");
        //  Get the offer data structure
        uint256 index = toIndex(contractAddress);
        Nest_NToken_OfferPriceData memory offerPriceData = _prices[index]; 
        //  Check the price, compare the current offer to the last effective price
        bool thisDeviate = comparativePrice(ethAmount,tokenAmount,tranTokenAddress);
        bool isDeviate;
        if (offerPriceData.deviate == true) {
            isDeviate = true;
        } else {
            isDeviate = thisDeviate;
        }
        //  Limit the taker order only be twice the amount of the offer to prevent large-amount attacks
        if (offerPriceData.deviate) {
            //  The taker order deviates  x2
            require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
        } else {
            if (isDeviate) {
                //  If the taken offer is normal and the taker order deviates x10
                require(ethAmount >= tranEthAmount.mul(_deviationFromScale), "EthAmount needs to be no less than 10 times of transaction scale");
            } else {
                //  If the taken offer is normal and the taker order is normal x2
                require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
            }
        }
        // Check whether the conditions for taker order are satisfied
        require(checkContractState(offerPriceData.blockNum) == 0, "Offer status error");
        require(offerPriceData.dealEthAmount >= tranEthAmount, "Insufficient trading eth");
        require(offerPriceData.dealTokenAmount >= tranTokenAmount, "Insufficient trading token");
        require(offerPriceData.tokenAddress == tranTokenAddress, "Wrong token address");
        require(tranTokenAmount == offerPriceData.dealTokenAmount * tranEthAmount / offerPriceData.dealEthAmount, "Wrong token amount");
        // Update the offer information
        offerPriceData.ethAmount = offerPriceData.ethAmount.sub(tranEthAmount);
        offerPriceData.tokenAmount = offerPriceData.tokenAmount.add(tranTokenAmount);
        offerPriceData.dealEthAmount = offerPriceData.dealEthAmount.sub(tranEthAmount);
        offerPriceData.dealTokenAmount = offerPriceData.dealTokenAmount.sub(tranTokenAmount);
        _prices[index] = offerPriceData;
        // Create a new offer
        createOffer(ethAmount, tokenAmount, tranTokenAddress, isDeviate, 0);
        // Transfer in erc20 + offer asset to this contract
        ERC20(tranTokenAddress).safeTransferFrom(address(msg.sender), address(this), tranTokenAmount.add(tokenAmount));
        // Modify price
        _offerPrice.changePrice(tranEthAmount, tranTokenAmount, tranTokenAddress, offerPriceData.blockNum.add(_blockLimit));
        emit OfferTran(address(msg.sender), address(tranTokenAddress), tranTokenAmount, address(0x0), tranEthAmount, contractAddress, offerPriceData.owner);
        // Transfer fee
        if (serviceCharge > 0) {
            address nTokenAddress = _tokenMapping.checkTokenMapping(tranTokenAddress);
            _abonus.switchToEth.value(serviceCharge)(nTokenAddress);
        }
    }
    
    /**
     * Offering mining
     * @param ntoken NToken address
     **/
    function oreDrawing(address ntoken) private returns(uint256) {
        Nest_NToken miningToken = Nest_NToken(ntoken);
        (uint256 createBlock, uint256 recentlyUsedBlock) = miningToken.checkBlockInfo();
        uint256 attenuationPointNow = block.number.sub(createBlock).div(_blockAttenuation);
        uint256 miningAmount = 0;
        uint256 attenuation;
        if (attenuationPointNow > 9) {
            attenuation = _afterMiningAmount;
        } else {
            attenuation = _attenuationAmount[attenuationPointNow];
        }
        miningAmount = attenuation.mul(block.number.sub(recentlyUsedBlock));
        miningToken.increaseTotal(miningAmount);
        emit OreDrawingLog(block.number, miningAmount, ntoken);
        return miningAmount;
    }
    
    /**
     * Retrieve mining
     * @param token Token address
     **/
    function mining(uint256 blockNum, address token, uint256 serviceCharge, address owner) private returns(uint256) {
        //  Block mining amount*offer fee/block offer fee
        uint256 miningAmount = _blockMining[blockNum][token].mul(serviceCharge).div(_blockOfferAmount[blockNum][token]);        
        //  Transfer NToken 
        Nest_NToken nToken = Nest_NToken(address(_tokenMapping.checkTokenMapping(token)));
        require(nToken.transfer(address(owner), miningAmount), "Transfer failure");
        
        emit MiningLog(blockNum, token,_blockOfferAmount[blockNum][token]);
        return miningAmount;
    }
    
    // Compare order prices
    function comparativePrice(uint256 myEthValue, uint256 myTokenValue, address token) private view returns(bool) {
        (uint256 frontEthValue, uint256 frontTokenValue) = _offerPrice.updateAndCheckPricePrivate(token);
        if (frontEthValue == 0 || frontTokenValue == 0) {
            return false;
        }
        uint256 maxTokenAmount = myEthValue.mul(frontTokenValue).mul(uint256(100).add(_deviate)).div(frontEthValue.mul(100));
        if (myTokenValue <= maxTokenAmount) {
            uint256 minTokenAmount = myEthValue.mul(frontTokenValue).mul(uint256(100).sub(_deviate)).div(frontEthValue.mul(100));
            if (myTokenValue >= minTokenAmount) {
                return false;
            }
        }
        return true;
    }
    
    // Check contract status
    function checkContractState(uint256 createBlock) public view returns (uint256) {
        if (block.number.sub(createBlock) > _blockLimit) {
            return 1;
        }
        return 0;
    }
    
    // Transfer ETH
    function repayEth(address accountAddress, uint256 asset) private {
        address payable addr = accountAddress.make_payable();
        addr.transfer(asset);
    }
    
    // View the upper limit of the block interval
    function checkBlockLimit() public view returns(uint256) {
        return _blockLimit;
    }
    
    // View taker fee ratio
    function checkTranEth() public view returns (uint256) {
        return _tranEth;
    }
    
    // View additional transaction multiple
    function checkTranAddition() public view returns(uint256) {
        return _tranAddition;
    }
    
    // View minimum offering ETH
    function checkleastEth() public view returns(uint256) {
        return _leastEth;
    }
    
    // View offering ETH span
    function checkOfferSpan() public view returns(uint256) {
        return _offerSpan;
    }

    // View block offering amount
    function checkBlockOfferAmount(uint256 blockNum, address token) public view returns (uint256) {
        return _blockOfferAmount[blockNum][token];
    }
    
    // View offering block mining amount
    function checkBlockMining(uint256 blockNum, address token) public view returns (uint256) {
        return _blockMining[blockNum][token];
    }
    
    // View offering mining amount
    function checkOfferMining(uint256 blockNum, address token, uint256 serviceCharge) public view returns (uint256) {
        if (serviceCharge == 0) {
            return 0;
        } else {
            return _blockMining[blockNum][token].mul(serviceCharge).div(_blockOfferAmount[blockNum][token]);
        }
    }
    
    //  View the owner allocation ratio
    function checkOwnerMining() public view returns(uint256) {
        return _ownerMining;
    }
    
    // View the mining decay
    function checkAttenuationAmount(uint256 num) public view returns(uint256) {
        return _attenuationAmount[num];
    }
    
    // Modify taker order fee ratio
    function changeTranEth(uint256 num) public onlyOwner {
        _tranEth = num;
    }
    
    // Modify block interval upper limit
    function changeBlockLimit(uint32 num) public onlyOwner {
        _blockLimit = num;
    }
    
    // Modify additional transaction multiple
    function changeTranAddition(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _tranAddition = num;
    }
    
    // Modify minimum offering ETH
    function changeLeastEth(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _leastEth = num;
    }
    
    // Modify offering ETH span
    function changeOfferSpan(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _offerSpan = num;
    }
    
    // Modify price deviation
    function changekDeviate(uint256 num) public onlyOwner {
        _deviate = num;
    }
    
    // Modify the deviation from scale 
    function changeDeviationFromScale(uint256 num) public onlyOwner {
        _deviationFromScale = num;
    }
    
    // Modify the owner allocation ratio
    function changeOwnerMining(uint256 num) public onlyOwner {
        _ownerMining = num;
    }
    
    // Modify the mining decay
    function changeAttenuationAmount(uint256 firstAmount, uint256 top, uint256 bottom) public onlyOwner {
        uint256 blockAmount = firstAmount;
        for (uint256 i = 0; i < 10; i ++) {
            _attenuationAmount[i] = blockAmount;
            blockAmount = blockAmount.mul(top).div(bottom);
        }
    }
    
    // Vote administrators only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender), "No authority");
        _;
    }
    
    /**
     * Get the number of offers stored in the offer array
     * @return The number of offers stored in the offer array
     **/
    function getPriceCount() view public returns (uint256) {
        return _prices.length;
    }
    
    /**
     * Get offer information according to the index
     * @param priceIndex Offer index
     * @return Offer information
     **/
    function getPrice(uint256 priceIndex) view public returns (string memory) {
        //  The buffer array used to generate the result string
        bytes memory buf = new bytes(500000);
        uint256 index = 0;
        index = writeOfferPriceData(priceIndex, _prices[priceIndex], buf, index);
        // Generate the result string and return
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }
    
    /**
     * Search the contract address list of the target account (reverse order)
     * @param start Search forward from the index corresponding to the given contract address (not including the record corresponding to start address)
     * @param count Maximum number of records to return
     * @param maxFindCount The max index to search
     * @param owner Target account address
     * @return Separate the offer records with symbols. use , to divide fields:  
     * uuid,owner,tokenAddress,ethAmount,tokenAmount,dealEthAmount,dealTokenAmount,blockNum,serviceCharge
     **/
    function find(address start, uint256 count, uint256 maxFindCount, address owner) view public returns (string memory) {
        // Buffer array used to generate result string
        bytes memory buf = new bytes(500000);
        uint256 index = 0;
        // Calculate search interval i and end
        uint256 i = _prices.length;
        uint256 end = 0;
        if (start != address(0)) {
            i = toIndex(start);
        }
        if (i > maxFindCount) {
            end = i - maxFindCount;
        }
        // Loop search, write qualified records into buffer
        while (count > 0 && i-- > end) {
            Nest_NToken_OfferPriceData memory price = _prices[i];
            if (price.owner == owner) {
                --count;
                index = writeOfferPriceData(i, price, buf, index);
            }
        }
        // Generate result string and return
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }
    
    /**
     * Get the list of offers by page
     * @param offset Skip the first offset records
     * @param count Maximum number of records to return
     * @param order Sort rules. 0 means reverse order, non-zero means positive order
     * @return Separate the offer records with symbols. use , to divide fields: 
     * uuid,owner,tokenAddress,ethAmount,tokenAmount,dealEthAmount,dealTokenAmount,blockNum,serviceCharge
     **/
    function list(uint256 offset, uint256 count, uint256 order) view public returns (string memory) {
        
        // Buffer array used to generate result string 
        bytes memory buf = new bytes(500000);
        uint256 index = 0;
        
        // Find search interval i and end
        uint256 i = 0;
        uint256 end = 0;
        
        if (order == 0) {
            // Reverse order, in default 
            // Calculate search interval i and end
            if (offset < _prices.length) {
                i = _prices.length - offset;
            } 
            if (count < i) {
                end = i - count;
            }
            
            // Write records in the target interval into the buffer
            while (i-- > end) {
                index = writeOfferPriceData(i, _prices[i], buf, index);
            }
        } else {
            // Ascending order
            // Calculate the search interval i and end
            if (offset < _prices.length) {
                i = offset;
            } else {
                i = _prices.length;
            }
            end = i + count;
            if(end > _prices.length) {
                end = _prices.length;
            }
            
            // Write the records in the target interval into the buffer
            while (i < end) {
                index = writeOfferPriceData(i, _prices[i], buf, index);
                ++i;
            }
        }
        
        // Generate the result string and return
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }   
     
    // Write the offer data into the buffer and return the buffer index
    function writeOfferPriceData(uint256 priceIndex, Nest_NToken_OfferPriceData memory price, bytes memory buf, uint256 index) pure private returns (uint256) {
        
        index = writeAddress(toAddress(priceIndex), buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeAddress(price.owner, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeAddress(price.tokenAddress, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.ethAmount, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.tokenAmount, buf, index);
        buf[index++] = byte(uint8(44));
       
        index = writeUInt(price.dealEthAmount, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.dealTokenAmount, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.blockNum, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.serviceCharge, buf, index);
        buf[index++] = byte(uint8(44));
        
        return index;
    }
     
    // Convert integer to string in decimal form, write the string into the buffer, and return the buffer index
    function writeUInt(uint256 iv, bytes memory buf, uint256 index) pure public returns (uint256) {
        uint256 i = index;
        do {
            buf[index++] = byte(uint8(iv % 10 +48));
            iv /= 10;
        } while (iv > 0);
        
        for (uint256 j = index; j > i; ++i) {
            byte t = buf[i];
            buf[i] = buf[--j];
            buf[j] = t;
        }
        
        return index;
    }

    // Convert the address to a hexadecimal string and write it into the buffer, and return the buffer index
    function writeAddress(address addr, bytes memory buf, uint256 index) pure private returns (uint256) {
        
        uint256 iv = uint256(addr);
        uint256 i = index + 40;
        do {
            uint256 w = iv % 16;
            if(w < 10) {
                buf[index++] = byte(uint8(w +48));
            } else {
                buf[index++] = byte(uint8(w +87));
            }
            
            iv /= 16;
        } while (index < i);
        
        i -= 40;
        for (uint256 j = index; j > i; ++i) {
            byte t = buf[i];
            buf[i] = buf[--j];
            buf[j] = t;
        }
        
        return index;
    }
}

/**
 * @title Auction NToken contract 
 * @dev Auction for listing and generating NToken
 */
contract Nest_NToken_TokenAuction {
    using SafeMath for uint256;
    using address_make_payable for address;
    using SafeERC20 for ERC20;
    
    Nest_3_VoteFactory _voteFactory;                            //  Voting contract
    Nest_NToken_TokenMapping _tokenMapping;                     //  NToken mapping contract
    ERC20 _nestToken;                                           //  NestToken
    Nest_3_OfferPrice _offerPrice;                              //  Price contract
    address _destructionAddress;                                //  Destruction contract address
    uint256 _duration = 5 days;                                 //  Auction duration
    uint256 _minimumNest = 100000 ether;                        //  Minimum auction amount
    uint256 _tokenNum = 1;                                      //  Auction token number
    uint256 _incentiveRatio = 50;                               //  Incentive ratio
    uint256 _minimumInterval = 10000 ether;                     //  Minimum auction interval
    mapping(address => AuctionInfo) _auctionList;               //  Auction list
    mapping(address => bool) _tokenBlackList;                   //  Auction blacklist
    struct AuctionInfo {
        uint256 endTime;                                        //  End time 
        uint256 auctionValue;                                   //  Auction price
        address latestAddress;                                  //  Highest auctioneer
        uint256 latestAmount;                                   //  Lastest auction amount 
    }
    address[] _allAuction;                                      //  Auction list array
    
    /**
    * @dev Initialization method
    * @param voteFactory Voting contract address
    */
    constructor (address voteFactory) public {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        _nestToken = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));
    }
    
    /**
    * @dev Reset voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        _nestToken = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));
    }
    
    /**
    * @dev Initiating auction
    * @param token Auction token address
    * @param auctionAmount Initial auction amount
    */
    function startAnAuction(address token, uint256 auctionAmount) public {
        require(_tokenMapping.checkTokenMapping(token) == address(0x0), "Token already exists");
        require(_auctionList[token].endTime == 0, "Token is on sale");
        require(auctionAmount >= _minimumNest, "AuctionAmount less than the minimum auction amount");
        require(_nestToken.transferFrom(address(msg.sender), address(this), auctionAmount), "Authorization failed");
        require(!_tokenBlackList[token]);
        // Verification
        ERC20 tokenERC20 = ERC20(token);
        tokenERC20.safeTransferFrom(address(msg.sender), address(this), 1);
        require(tokenERC20.balanceOf(address(this)) >= 1);
        tokenERC20.safeTransfer(address(msg.sender), 1);
        AuctionInfo memory thisAuction = AuctionInfo(now.add(_duration), auctionAmount, address(msg.sender), auctionAmount);
        _auctionList[token] = thisAuction;
        _allAuction.push(token);
    }
    
    /**
    * @dev Auction
    * @param token Auction token address 
    * @param auctionAmount Auction amount
    */
    function continueAuction(address token, uint256 auctionAmount) public {
        require(now <= _auctionList[token].endTime && _auctionList[token].endTime != 0, "Auction closed");
        require(auctionAmount > _auctionList[token].auctionValue, "Insufficient auction amount");
        uint256 subAuctionAmount = auctionAmount.sub(_auctionList[token].auctionValue);
        require(subAuctionAmount >= _minimumInterval);
        uint256 excitation = subAuctionAmount.mul(_incentiveRatio).div(100);
        require(_nestToken.transferFrom(address(msg.sender), address(this), auctionAmount), "Authorization failed");
        require(_nestToken.transfer(_auctionList[token].latestAddress, _auctionList[token].auctionValue.add(excitation)), "Transfer failure");
        // Update auction information
        _auctionList[token].auctionValue = auctionAmount;
        _auctionList[token].latestAddress = address(msg.sender);
        _auctionList[token].latestAmount = _auctionList[token].latestAmount.add(subAuctionAmount.sub(excitation));
    }
    
    /**
    * @dev Listing
    * @param token Auction token address
    */
    function auctionSuccess(address token) public {
        Nest_3_TokenAbonus nestAbonus = Nest_3_TokenAbonus(payable(_voteFactory.checkAddress("nest.v3.tokenAbonus")));
        uint256 nowTime = now;
        uint256 nextTime = nestAbonus.getNextTime();
        uint256 timeLimit = nestAbonus.checkTimeLimit();
        uint256 getAbonusTimeLimit = nestAbonus.checkGetAbonusTimeLimit();
        require(!(nowTime >= nextTime.sub(timeLimit) && nowTime <= nextTime.sub(timeLimit).add(getAbonusTimeLimit)), "Not time to auctionSuccess");
        require(nowTime > _auctionList[token].endTime && _auctionList[token].endTime != 0, "Token is on sale");
        //  Initialize NToken
        Nest_NToken nToken = new Nest_NToken(strConcat("NToken", getAddressStr(_tokenNum)), strConcat("N", getAddressStr(_tokenNum)), address(_voteFactory), address(_auctionList[token].latestAddress));
        //  Auction NEST destruction
        require(_nestToken.transfer(_destructionAddress, _auctionList[token].latestAmount), "Transfer failure");
        //  Add NToken mapping
        _tokenMapping.addTokenMapping(token, address(nToken));
        //  Initialize charging parameters
        _offerPrice.addPriceCost(token);
        _tokenNum = _tokenNum.add(1);
    }
    
    function strConcat(string memory _a, string memory _b) public pure returns (string memory){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ret = new string(_ba.length + _bb.length);
        bytes memory bret = bytes(ret);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) {
            bret[k++] = _ba[i];
        } 
        for (uint i = 0; i < _bb.length; i++) {
            bret[k++] = _bb[i];
        } 
        return string(ret);
    } 
    
    // Convert to 4-digit string
    function getAddressStr(uint256 iv) public pure returns (string memory) {
        bytes memory buf = new bytes(64);
        uint256 index = 0;
        do {
            buf[index++] = byte(uint8(iv % 10 + 48));
            iv /= 10;
        } while (iv > 0 || index < 4);
        bytes memory str = new bytes(index);
        for(uint256 i = 0; i < index; ++i) {
            str[i] = buf[index - i - 1];
        }
        return string(str);
    }
    
    // Check auction duration
    function checkDuration() public view returns(uint256) {
        return _duration;
    }
    
    // Check minimum auction amount
    function checkMinimumNest() public view returns(uint256) {
        return _minimumNest;
    }
    
    // Check initiated number of auction tokens
    function checkAllAuctionLength() public view returns(uint256) {
        return _allAuction.length;
    }
    
    // View auctioned token addresses
    function checkAuctionTokenAddress(uint256 num) public view returns(address) {
        return _allAuction[num];
    }
    
    // View auction blacklist
    function checkTokenBlackList(address token) public view returns(bool) {
        return _tokenBlackList[token];
    }
    
    // View auction token information
    function checkAuctionInfo(address token) public view returns(uint256 endTime, uint256 auctionValue, address latestAddress) {
        AuctionInfo memory info = _auctionList[token];
        return (info.endTime, info.auctionValue, info.latestAddress);
    }
    
    // View token number
    function checkTokenNum() public view returns (uint256) {
        return _tokenNum;
    }
    
    // Modify auction duration
    function changeDuration(uint256 num) public onlyOwner {
        _duration = num.mul(1 days);
    }
    
    // Modify minimum auction amount
    function changeMinimumNest(uint256 num) public onlyOwner {
        _minimumNest = num;
    }
    
    // Modify auction blacklist
    function changeTokenBlackList(address token, bool isBlack) public onlyOwner {
        _tokenBlackList[token] = isBlack;
    }
    
    // Administrator only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender), "No authority");
        _;
    }
    
}

contract Nest_NToken is IERC20 {
    using SafeMath for uint256;
    
    mapping (address => uint256) private _balances;                                 //  Balance ledger 
    mapping (address => mapping (address => uint256)) private _allowed;             //  Approval ledger 
    uint256 private _totalSupply = 0 ether;                                         //  Total supply 
    string public name;                                                             //  Token name 
    string public symbol;                                                           //  Token symbol 
    uint8 public decimals = 18;                                                     //  Precision
    uint256 public _createBlock;                                                    //  Create block number
    uint256 public _recentlyUsedBlock;                                              //  Recently used block number
    Nest_3_VoteFactory _voteFactory;                                                //  Voting factory contract
    address _bidder;                                                                //  Owner
    
    /**
    * @dev Initialization method
    * @param _name Token name
    * @param _symbol Token symbol
    * @param voteFactory Voting factory contract address
    * @param bidder Successful bidder address
    */
    constructor (string memory _name, string memory _symbol, address voteFactory, address bidder) public {
        name = _name;                                                               
        symbol = _symbol;
        _createBlock = block.number;
        _recentlyUsedBlock = block.number;
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));
        _bidder = bidder;
    }
    
    /**
    * @dev Reset voting contract method
    * @param voteFactory Voting contract address
    */
    function changeMapping (address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));
    }
    
    /**
    * @dev Additional issuance
    * @param value Additional issuance amount
    */
    function increaseTotal(uint256 value) public {
        address offerMain = address(_voteFactory.checkAddress("nest.nToken.offerMain"));
        require(address(msg.sender) == offerMain, "No authority");
        _balances[offerMain] = _balances[offerMain].add(value);
        _totalSupply = _totalSupply.add(value);
        _recentlyUsedBlock = block.number;
    }

    /**
    * @dev Check the total amount of tokens
    * @return Total supply
    */
    function totalSupply() override public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Check address balance
    * @param owner Address to be checked
    * @return Return the balance of the corresponding address
    */
    function balanceOf(address owner) override public view returns (uint256) {
        return _balances[owner];
    }
    
    /**
    * @dev Check block information
    * @return createBlock Initial block number
    * @return recentlyUsedBlock Recently mined and issued block
    */
    function checkBlockInfo() public view returns(uint256 createBlock, uint256 recentlyUsedBlock) {
        return (_createBlock, _recentlyUsedBlock);
    }

    /**
     * @dev Check owner's approved allowance to the spender
     * @param owner Approving address
     * @param spender Approved address
     * @return Approved amount
     */
    function allowance(address owner, address spender) override public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
    * @dev Transfer method
    * @param to Transfer target
    * @param value Transfer amount
    * @return Whether the transfer is successful
    */
    function transfer(address to, uint256 value) override public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approval method
     * @param spender Approval target
     * @param value Approval amount
     * @return Whether the approval is successful
     */
    function approve(address spender, uint256 value) override public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens when approved
     * @param from Transfer-out account address
     * @param to Transfer-in account address
     * @param value Transfer amount
     * @return Whether approved transfer is successful
     */
    function transferFrom(address from, address to, uint256 value) override public returns (bool) {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        emit Approval(from, msg.sender, _allowed[from][msg.sender]);
        return true;
    }

    /**
     * @dev Increase the allowance
     * @param spender Approval target
     * @param addedValue Amount to increase
     * @return whether increase is successful
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the allowance
     * @param spender Approval target
     * @param subtractedValue Amount to decrease
     * @return Whether decrease is successful
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].sub(subtractedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
    * @dev Transfer method
    * @param to Transfer target
    * @param value Transfer amount
    */
    function _transfer(address from, address to, uint256 value) internal {
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }
    
    /**
    * @dev Check the creator
    * @return Creator address
    */
    function checkBidder() public view returns(address) {
        return _bidder;
    }
    
    /**
    * @dev Transfer creator
    * @param bidder New creator address
    */
    function changeBidder(address bidder) public {
        require(address(msg.sender) == _bidder);
        _bidder = bidder; 
    }
    
    // Administrator only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender));
        _;
    }
}

/**
 * @title NToken mapping contract
 * @dev Add, modify and check offering token mapping
 */
contract Nest_NToken_TokenMapping {
    
    mapping (address => address) _tokenMapping;                 //  Token mapping - offering token => NToken
    Nest_3_VoteFactory _voteFactory;                            //  Voting contract
    
    event TokenMappingLog(address token, address nToken);
    
    /**
    * @dev Initialization method
    * @param voteFactory Voting contract address
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));
    }
    
    /**
    * @dev Reset voting contract
    * @param voteFactory  voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));
    }
    
    /**
    * @dev Add token mapping
    * @param token Offering token address
    * @param nToken Mining NToken address
    */
    function addTokenMapping(address token, address nToken) public {
        require(address(msg.sender) == address(_voteFactory.checkAddress("nest.nToken.tokenAuction")), "No authority");
        require(_tokenMapping[token] == address(0x0), "Token already exists");
        _tokenMapping[token] = nToken;
        emit TokenMappingLog(token, nToken);
    }
    
    /**
    * @dev Change token mapping
    * @param token Offering token address
    * @param nToken Mining NToken address
    */
    function changeTokenMapping(address token, address nToken) public onlyOwner {
        _tokenMapping[token] = nToken;
        emit TokenMappingLog(token, nToken);
    }
    
    /**
    * @dev Check token mapping
    * @param token Offering token address
    * @return Mining NToken address
    */
    function checkTokenMapping(address token) public view returns (address) {
        return _tokenMapping[token];
    }
    
    // Only for administrator
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender), "No authority");
        _;
    }
}