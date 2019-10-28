pragma solidity ^0.4.18

contract RentBasic {

	struct HourseInfo {
			uint32   houseId; 
		    uint32   ratingIndex;  // 评级指数
			string   houseAddress; // 房屋地址
			uint16   huxing;  // 户型（1/2/3居）
			byte32   descibe;	// 房屋描述
			byte32	 landlord; //房东情况 
			uint32   tenancy; // 租期
			uint32   rent; // 租金
			byte32   hopeYou;  // 期待你的描述
			uint64   releaseTime;  // 发布时间
			uint64   updateTime; // 更新时间
			uint64   dealineTime;  // 截止时间
	}
	HourseInfo [] public houseInfos;

	uint 	public rent;	// 租金
	uint 	public house; 	// 房源
	address public landlord; // 房东地址 
	
	uint 	public createdTime; // 发布时间

	uint    public promiseAmount = 500; // 保证金数量, 初始为500个

	address public owner; // 合约发布者

	enum State {Created, Started, Terminated};
	State  public state;

	event PulishMessage(address _landlord, HourseInfo _baseInfo, uint8 _index);

	event SignContract(address indexed _landlord, address indexed _renter, uint256 _time);

	event RenterRaiseCrowding(address indexed _receiver, uint256 _fundingGoal, uint256 _durationInMinutes, address indexed _tokenContractAddress);
	
	function constructor() {
		owner = msg.sender;
	}

	modifer gtMinMoney(uint amount) {
		require(amount >= promiseAmount, "promise amount is not enough");
		_;
	}

	modifer onlyOwner() {
		require(msg.sender == owner);
		_;
	}
	/**
	 * @title lease
	 * @dev leaser rent out the house
	 * @Parm {_leaser: the address of the leaser, _lockKey：the key of the door , _value: the cash deposit}
	 */
	function releaseHouse(address _landlord, string _houseAddr,uint16 _huxing,byte32 _describe, byte32 _landlord, uint32 _tenancy, uint32 _rent, byte32 _hopeYou) public returns (bool) {
		uint256 nowTimes = now; 
		uint256 deadTime = now + 7 days;
		houseInfo = ({
			houseId: 1,  // random generate
			ratingIndex: 0,
			houseAddress: _houseAddr,
			huxing: _huxing,
			desciber: _describe,
			landlord: _landlord,
			tenancy: _tenancy,
			rent: _rent,
			hopeYou: _hopeYou,
			releaseTime: nowTimes,
			dealineTime: deadTime
		});
		houseInfos.push(houseInfo);
	    PulishMessage(_landlord, houseInfo, houseInfos.length);
	}
	/**
	 * @title getHouseInfo
	 * @dev get release rent house information
	 * @Parm {_index: the house informaion position}
	 */
	function getHouseInfo(uint8 _index) public returns(HouseInfo) {
		return houseInfos[_index];
	}	
	/**
	 * @title raisePromiseMoney
	 * @dev _renter and _leaser should raise a amount of the token as a promise
	 * @Parm {_addr: the address of the raise promise money, _lock_key：the key of the door , _value: the cash deposit}
	 */
	function raisePromiseMoney(uint _amount) public gtMinMoney(_amount) {
		address addr = msg.sender;
		// transfer(msg.sender, _amount);
	}
	/**
	 * @title transfer
	 * @dev transfer the coin from _renter to _leaser
	 * @Parm {_leaser: the address of the leaser, _lock_key：the key of the door , _value: the cash deposit}
	 */
	function transfer(address _renter, address _leaser, uint _value) public returns (bool);
	/**
	 * @title signContract
	 * @dev  _renter and _leaser sign how long agreement. It may be also including approve, send key
	 * @Parm {_leaser: the address of the leaser, _renter：the address of the renter , signHowLong: how long of the agreement}
	 */
	function signContract(address _leaser, address _renter, uint _signHowLong) public returns (bool);
	/**
	 * @title breakContract
	 * @dev  who break the contract and how to record it. And it will run by the contract or anyone call it
	 * @Parm {}
	 * TODO
	 */
	function breakContract(address _renter, address _leaser) public returns (uint256 money);
	/**
	 * @title sendKey
	 * @dev _leaser send the key to _renter
	 * @Parm {_leaser: the address of the leaser, _renter：the address of the renter , _lockKey: the key of the door}
	 */
	function sendKey(address _leaser, address _renter, address _lockKey) public onLeaser returns (bool) {

	};
		/**
	 * @title setPromiseMoney
	 * @dev _leaser send the key to _renter
	 * @Parm {_leaser: the address of the leaser, _renter：the address of the renter , _lockKey: the key of the door}
	 */
	function setPromiseMoney(uint256 _promiseAmount) public onlyOwner {
		promiseAmount = _promiseAmount
	}

	function getPromiseMoney() public returns(uint256) {
		return promiseAmount;
	}
 
	event Transfer(address indexed _renter, address indexed _leaser, uint256 _value);
}

contract rentAndLeaser is rentBasic {

	event Lock(uint256 _lockTime);
	event Approval(address indexed _leaser, address indexed _renter, uint256 _value);
	/**
	 * @title lockBond
	 * @dev lock the bond of the renter and the leaser when the contract take effect
	 * @Parm {}
	 */
	function lockBond() internal notLocked onlyOwner {

	}
	/**
	 * @title unLockBond
	 * @dev when there are some one break the contract, the bond will transfer to the other
	 * @Parm {}
	 */
	function unLockBond() public locked onlyOwner {

	}
   /**
	 * @title approve
	 * @dev approve the _renter the value of the people of the house
	 * @Parm {}
	 */
	function approve(address _renter, uint256 _value) public onlyLeaser returns (bool) {

	}
	/**
	 * @title Crowd-funding money for renter
	 * @dev renter can collect money by Crowd-Funding, and it should describe it clearly
	 * @Parm {_renter: who lauch the crowd-funding, long: how long it will contiune}
	 * return {} describe: It should include address,money,time
	 */
	function crowdFunding(address _renter, uint long) public return (uint money) {

	} 
	/**
	 * @title Crowd-funding money who can lend the money 
	 * @dev Approve someone can lend money to me.
	 * @Parm {_msgsender: who lauch the crowd-funding, _lender: who lend money}
	 * return true/false
	 */
	function approveCrowdFunding(address _msgsender, address _lender) public return (bool) {

	}


}