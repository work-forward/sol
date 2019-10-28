pragma solidity ^0.4.24;
import './agreement.sol';

interface TokenInterface {
	function transfer(address _to, uint256 _value) external  returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function isToken() pure returns(bool isIndeed);
}
interface RegisterInterface {
	function isLogin(address _userAddr) external returns(bool);
	function isRegister() public pure returns(bool isIndeed);
}
contract RentBasic {
	enum HouseState {
		Release,  // 发布租赁中
		WaitRent,   // 租客交付定金后，请求租赁中
		Renting,  // 租赁中
		EndRent,   // 完成租赁
		Cance,   // 取消租赁
		BreakRent  // 解除租赁
	}
	HouseState defaultState = HouseState.Release;
	struct HouseInfo {			
			uint8    landRate; // 房东信用等级 1、信用非常好，2、信用良好，3、信用一般，4、信用差
		    uint8    ratingIndex;  // 评级指数
		    uint8    huxing;  // 户型（1/2/3居）		    
			string   houseAddress; // 房屋地址			
			bytes32  houseId;   // 房屋hash
			string   descibe;	// 房屋描述
			string	 landlordInfo; //房东情况 			
			string   hopeYou;  // 期待你的描述			
			address  landlord; // 房东地址		
	}
	struct HouseReleaseInfo {
		HouseState    state;   // 当前的状态
		uint32        tenancy; // 租期
		uint256       rent; // 租金
		uint          releaseTime;  // 发布时间
		uint          updateTime; // 更新时间
		uint          dealineTime;  // 截止时间
		bool          existed; // 该hash对应的House是否存在
		bool		  ischecked; // 毁约时是否通过管理员审核
	}
	// 租客对某一房源评价
	struct RemarkHouse {
		address tenant; // 租客地址	
		uint8   ratingIndex; // 评级级别
		string remarkLandlord; // 对房东评价
		uint256 optTime; // 评论时间
	}
	// 房东对某一租客评价
	struct RemarkTenant {
		address leaser; // 房东
		uint8   ratingIndex; // 评价级别
		string  remarkTenant; // 对租客评价
		uint256 optTime; // 评论时间
	}
	// 毁约时惩罚内容
	struct PunishCtx {
		uint punishAmount; // 惩罚的数量
		address punishAddr; // 惩罚的地址
	}
	TokenInterface token;
	TenancyAgreement tenancyContract;
	RegisterInterface userRegister;
	HouseInfo hsInformation;
	mapping(bytes32 => HouseInfo) houseInfos; 
	mapping(bytes32 => HouseReleaseInfo) hsReleaseInfos; 
	mapping(address => uint) public addrMoney; 
	mapping(bytes32 => RemarkHouse) remarks; 
	mapping(bytes32 => RemarkTenant) public remarkTenants; 
	mapping(bytes32 => PunishCtx) punishRelation;
	mapping(bytes32 => mapping(address => uint)) bonds; 
	mapping(address => address) l2rMaps;
	mapping(address => uint256) creditManager; 
	mapping(address => uint256) lockAmount;
	mapping(address => bool) addrs;

	address public owner; 
	bool public flag;
	address public recPromiseAddr = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB; 
	address public disRrkAddr = 0xA4ef5514CCfe79B821a3F36A123e528e096cEa28; 
	address public saveTenanantAddr = 0xF87932Ee0e167f8B54209ca943af4Fad93B3B8A0; 
	address public punishAddr = 0x583031D1113aD414F02576BD6afaBfb302140225; 

	uint256 promiseAmount = 500 * (10 ** 8);
	uint256 punishLevel1Amount = 10 * (10 ** 8); 
	uint256 remarkAmount = 4 * (10 ** 8);

	event RelInfo(bytes32 houseHash, HouseState _defaultState, uint32 _tenancy, uint256 _rent, uint _releaseTime, uint _deadTime, bool existed);	
	event RelBasic(bytes32 houseHash, uint8 rating,string _houseAddr,uint8 _huxing,string _describe, string _info, string _hopeYou,address indexed _landlord);		
	event SignContract(address indexed _sender, bytes32 _houseId, uint256 _signHowLong, uint256 _rental, bytes32 _signatrue, uint256 _time);
	event CommentHouse(address indexed _commenter, uint8 _rating, string _ramark);
	event RequestSign(address indexed _sender, bytes32 _houseId,uint256 _realRent, address indexed saveTenanantAddr);
	event BreakContract(bytes32 _houseId, address indexed sender,string _reason, uint256 uptime);
	event WithdrawDeposit(bytes32 _houseId,address indexed sender,uint256 amount,uint256 nowTime);
	// event RenterRaiseCrowding(address indexed _receiver, uint256 _fundingGoal, uint256 _durationInMinutes, address indexed _tokenContractAddress);
	
	constructor(address _token, address _register) {
		owner = msg.sender;
		token = TokenInterface(_token);
		require(token.isToken());
		userRegister = RegisterInterface(_register);
		require(userRegister.isRegister());
		addrs[recPromiseAddr] = true;
		addrs[punishAddr] = true;
	}

	modifier gtMinMoney(uint amount) {
		require(amount >= promiseAmount, "promise amount is not enough");
		_;
	}

	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}
    // https://ethereum.stackexchange.com/questions/75849/ethereum-smart-contract-calling-a-function-in-another-smart-contract-that-has-a
	modifier onlyLogin() {
		require(userRegister.isLogin(msg.sender), "require user must sign in!");
		_;
	}
	function releaseHouse(string _houseAddr,uint8 _huxing,string _describe, string _info, uint32 _tenancy, uint256 _rent, string _hopeYou) public onlyLogin returns (bytes32) {
		uint256 nowTimes = now; 
		uint256 deadTime = nowTimes + 7 days;
		address houseOwer = msg.sender;
		// releaser should hold not less than 500 BLT
		require(token.transferFrom(msg.sender, recPromiseAddr,  promiseAmount),"Release_Balance is not enough");
		addrMoney[houseOwer] = promiseAmount;
		bytes32 houseIds = keccak256(abi.encodePacked(houseOwer, nowTimes, deadTime));
		hsInformation = HouseInfo({				
			landRate: 2,		 
			ratingIndex: 2,
			huxing: _huxing,			
			hopeYou: _hopeYou,
			houseAddress: _houseAddr,			
			houseId: houseIds, 
			descibe: _describe,
			landlordInfo: _info,
			landlord: houseOwer			
		});
		houseInfos[houseIds] = hsInformation;
		hsReleaseInfos[houseIds] = HouseReleaseInfo({
			state: defaultState,
			tenancy: _tenancy,
			rent: _rent,
			releaseTime: nowTimes,
			updateTime: nowTimes,
			dealineTime: deadTime,
			existed: true,
			ischecked: false
		});
		// releations[houseId].leaser = houseOwer;
		RelBasic(houseIds, 2, _houseAddr, _huxing, _describe, _info, _hopeYou, houseOwer);
		RelInfo(houseIds, defaultState, _tenancy,_rent,nowTimes,deadTime,true);
		return houseIds;
	}
	function deadReleaseHouse(bytes32 _houseId) returns(bool) {
		HouseReleaseInfo hsRelInfo = hsReleaseInfos[_houseId];
		if (now > hsRelInfo.dealineTime && hsRelInfo.state == HouseState.Renting) {
			hsReleaseInfos[_houseId].state = HouseState.Cance;
			return true;
		}
		return false;
	}
	function requestSign(bytes32 _houseId, uint256 _realRent) public onlyLogin returns (HouseState,address){
		HouseInfo hsInfo = houseInfos[_houseId];
		HouseReleaseInfo hsReInfo = hsReleaseInfos[_houseId];
		address sender = msg.sender;
		require(hsReInfo.existed, "House is not existed");
		require(hsReInfo.state == defaultState, "House State is not in release");
		require(token.transferFrom(sender, saveTenanantAddr, _realRent), "Tenat's BLT not enough !");
		hsReleaseInfos[_houseId].state = HouseState.WaitRent;
		bonds[_houseId][msg.sender] = _realRent;
		// releations[_houseId].tenant = msg.sender;
		l2rMaps[hsInfo.landlord] = sender;
		RequestSign(sender, _houseId, _realRent, saveTenanantAddr);
		return (hsReInfo.state, hsInfo.landlord);
	}
	function signAgreement(bytes32 _houseId,string _name, uint _signHowLong,uint _rental, uint256 _yearRent) public onlyLogin returns (HouseState) {
		HouseInfo hsInfo = houseInfos[_houseId];
		HouseReleaseInfo hsReInfo = hsReleaseInfos[_houseId];
		require(hsReInfo.existed, "House is not existed");
		require(hsReInfo.state == HouseState.WaitRent, "House State is not in wait rent");
		uint256 nowTime = now;
		// pack message 
		bytes memory message = abi.encodePacked(sender, _houseId, _signHowLong, _rental, nowTime);
		
		bytes32 signatrue = keccak256(message);
		address sender = msg.sender;
		if (sender != hsInfo.landlord) {
			require(bonds[_houseId][sender] > 0, "Require the tenant have enough bond");
			require(token.transferFrom(sender, hsInfo.landlord, _rental), "Tenat's BLT not enough !");
 			tenancyContract.tenantSign(_houseId, _name, _rental, _signHowLong, signatrue);
 			hsReleaseInfos[_houseId].state = HouseState.Renting;
		} else {
			// tenancyContract.newAgreement(_name, _houseId, hsInfo.houseAddress, hsInfo.descibe, signatrue,_rental, _signHowLong);
			tenancyContract = new TenancyAgreement(_name, _houseId, hsInfo.houseAddress, hsInfo.descibe, signatrue,_rental, _signHowLong);
		}
		// client start timer
		SignContract(sender, _houseId, _signHowLong, _rental, signatrue, nowTime);
		hsReleaseInfos[_houseId].updateTime = nowTime;
		return hsReInfo.state;
	}
	 function withdraw(bytes32 _houseId, uint amount) onlyLogin public returns(bool) {
	 	HouseInfo hs = houseInfos[_houseId];
	 	HouseReleaseInfo reInfo = hsReleaseInfos[_houseId];
	 	require(reInfo.existed, "Not find the house!");
	 	require(reInfo.state == HouseState.EndRent || reInfo.state == HouseState.Cance, "House rent is not finished, if you want break the rent, please break contract first!");
	 	require(amount > 0 , "Amount must less than 0 !");
	 	address sender = msg.sender;
	 	if (sender == hs.landlord) {
	 		require(addrMoney[msg.sender] >= amount);
	 		addrMoney[msg.sender] = addrMoney[msg.sender] - amount; // decrease the landlord promise amount.
	 		require(token.transferFrom(recPromiseAddr, sender, amount), "withdraw error");
	 	} else {
	 		// Return the bond to the tenant
	 		require(bonds[_houseId][sender] >= amount);
	 		bonds[_houseId][sender] = bonds[_houseId][sender] - amount;
		 	require(token.transferFrom(saveTenanantAddr, sender, amount), "Transfer fail");
	 	}
	 	uint256 nowTime = now;
	 	hsReleaseInfos[_houseId].updateTime = nowTime;
	 	WithdrawDeposit(_houseId, sender, amount, nowTime);
	 	return true;
	 }
	
	function getHouseBasicInfo(bytes32 _houseId) public returns(bytes32, uint8, string, uint8, string, 
		string, string, address) {
		HouseInfo houseInfo = houseInfos[_houseId];
		return (_houseId, houseInfo.ratingIndex, houseInfo.houseAddress, houseInfo.huxing,houseInfo.descibe,
			  houseInfo.landlordInfo,houseInfo.hopeYou, houseInfo.landlord);		
	}
	function getHouseReleaseInfo(bytes32 _houseId) public returns(HouseState, uint32, uint256, uint, uint, bool) {
		HouseReleaseInfo RelInfo = hsReleaseInfos[_houseId];
		require(RelInfo.existed, "Require the house is existed !");
		return (RelInfo.state, RelInfo.tenancy, RelInfo.rent, RelInfo.releaseTime, RelInfo.dealineTime, RelInfo.existed);		
	}	
	/*
	  @dev breakContract
	  @des this method call should be checked by admin, then it call be called.
	*/	
	function breakContract(bytes32 _houseId, string _reason) public onlyLogin returns(bool) {
		HouseInfo hus = houseInfos[_houseId];
		HouseReleaseInfo relInfo = hsReleaseInfos[_houseId];
		require(relInfo.existed, "House is not existed !");
		require(relInfo.ischecked, "Apply must pass admin checked");
		require(relInfo.state != HouseState.Cance || relInfo.state != HouseState.BreakRent,"Break Contract reqiure house not in cance or return rent status!");
		// If the house is in WaitRent, anyone can break the house normal
		if 	(relInfo.state == HouseState.WaitRent)	{
			hsReleaseInfos[_houseId].state = HouseState.Cance;
		} else if (relInfo.state == HouseState.Renting) {
			hsReleaseInfos[_houseId].state = HouseState.BreakRent;
		}
		address sender = msg.sender;	
		if (relInfo.state != HouseState.Release) {
			PunishCtx puCtx = punishRelation[_houseId];
			uint256 amount = puCtx.punishAmount;
			address puSender = recPromiseAddr;
			// 如果房东是被惩罚的地址并且是房东调用时，则惩罚房东
			address another = l2rMaps[sender];
			if (sender == puCtx.punishAddr && sender == hus.landlord) {		
				addrMoney[hus.landlord] = addrMoney[hus.landlord] - amount;
			} else if (sender == puCtx.punishAddr && sender != hus.landlord) { // 惩罚租客
				puSender = saveTenanantAddr;
			    bonds[_houseId][another] = bonds[_houseId][another] - amount;
			} else if (sender == hus.landlord) { // 若房东不是被惩罚者时候，调用此方法则惩罚租客
				puSender = saveTenanantAddr;
			    bonds[_houseId][another] = bonds[_houseId][another] - amount;
			} else { // 惩罚房东
				addrMoney[hus.landlord] = addrMoney[hus.landlord] - amount;
			}
			require(token.transferFrom(puSender, punishAddr, amount),"transfer fail!");
			hsReleaseInfos[_houseId].state = HouseState.Cance;
		}
		// Update releaseHouse information
		uint256 nowTime = now;
		hsReleaseInfos[_houseId].updateTime = nowTime;	
		BreakContract(_houseId, sender, _reason, nowTime);
		return true;
	}
	/*
 	* @dev checkBreak
 	* des: Admin judge punish one of the rent house. 
	*/
	function checkBreak(bytes32 _houseId, uint _punishAmount, address _punishAddr) public returns(bool){
		address sender = msg.sender;
        if (!addrs[sender]) {
        	return false;
        }
		HouseReleaseInfo relInfo = hsReleaseInfos[_houseId];
		hsReleaseInfos[_houseId].ischecked = true;
		punishRelation[_houseId].punishAmount = _punishAmount;
		punishRelation[_houseId].punishAddr = _punishAddr;
		return true;
	}

	function commentHouse(bytes32 _houseId, uint8 _ratingIndex, string _ramark) onlyLogin public returns(bool) {
		address sender = msg.sender;
		HouseReleaseInfo reInfo = hsReleaseInfos[_houseId];
		require(reInfo.existed, "Not find house!");
	 	require(reInfo.state == HouseState.EndRent, "Rent is not finished!");
		if (houseInfos[_houseId].landlord == sender) {
			remarks[_houseId] = RemarkHouse(sender, _ratingIndex, _ramark, now);
			creditManager[l2rMaps[sender]] += _ratingIndex; 
		} else {
			address landlord = houseInfos[_houseId].landlord;
			creditManager[landlord] += _ratingIndex;
			remarkTenants[_houseId] = RemarkTenant(sender, _ratingIndex, _ramark, now);
		}
		require(!token.transferFrom(disRrkAddr,sender, remarkAmount), "Distribute fail !");
		CommentHouse(sender, _ratingIndex, _ramark);
		return true;
	}
}
