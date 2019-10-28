pragma solidity ^0.4.0;
contract RentalAgreement {
    /* This declares a new complex type which will hold the paid rents*/
    struct PaidRent {
        uint id;
        uint value;
    }

    PaidRent [] public paidrents;
    uint public createdTimestamp;

    uint public rent; // 租金

    string public house;   // 房子

    address public landlord; // 房东

    address public tenant;  // 房客
    enum State {Created, Started, Terminated}
    State public state;

    constructor (uint _rent, string _house) payable public {
        rent = _rent;
        house = _house;
        landlord = msg.sender;
        createdTimestamp = block.timestamp;
    }


 modifier condition(bool _condition) {
        require(_condition);
        _;
    }

    modifier onlyLandlord () {
        if (msg.sender != landlord) revert();
        _;
    }

    modifier onlyTenant () {
        if (msg.sender != tenant) revert();
        _;
    }

    modifier inState(State _state) { // 在某种状态下
        if (state != _state) revert();
        _;
    }

    // 获得租金
    function getPaidRents () internal view returns (PaidRent[]) {
        return paidrents;
    }
    // 获得房子
    function getHouse() public constant returns (string) {
        return house;
    }

    function getLandlord() public constant returns (address) {
        return landlord;
    }

    function getTenant() public constant returns (address) {
        return tenant;
    }
    // 查询租金
    function getRent() public constant returns (uint) {
        return rent;
    }

    function getContractCreated() public constant returns (uint) {
        return createdTimestamp;
    }

    function getContractAddress() public constant returns (address) {
        return this;
    }



    /* Events for DApps to listen to */
    event agreementConfirmed();

    event paidRent();

    event contractTerminated();

    /* Confirm the lease agreement as tenant*/
    function confirmAgreement() payable public
    inState(State.Created)
    condition (msg.sender != landlord)

    {
        emit agreementConfirmed();
        tenant = msg.sender;
        state = State.Started;
    }

    function payRent() payable public
    onlyTenant
    inState(State.Started)
    condition(msg.value == rent)
    {
        emit paidRent();
        landlord.transfer(address(this).balance);
        paidrents.push(PaidRent({
        id : paidrents.length + 1,
        value : msg.value
        }));
    }
    /* Terminate the contract so the tenant can’t pay rent anymore,
    and the contract is terminated */
    function terminateContract () payable public
    onlyLandlord
    {
        emit contractTerminated();
        landlord.transfer(address(this).balance);
        /* If there is any value on the
               contract send it to the landlord*/
        state = State.Terminated;
    }
}

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  function Migrations() public {
    owner = msg.sender;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}