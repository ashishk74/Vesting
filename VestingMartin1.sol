// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
contract ERC20 is IERC20 {
   

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply = 1000000000;  // 1 billion
    address internal owner_;
    constructor()  {
        owner_ = msg.sender;
        _balances[owner_] = _totalSupply;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender]-(amount));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender]+(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender]-(subtractedValue));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender]-(amount);
        _balances[recipient] = _balances[recipient]+(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply+(amount);
        _balances[account] = _balances[account]+(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply-(value);
        _balances[account] = _balances[account]-(value);
        emit Transfer(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender]-(amount));
    }
}

contract VestingMartin is ERC20 {

    
    
    
    
    ERC20 public token;
    
    modifier onlyAdmin {
        require(msg.sender == owner_, "Not Admin");
        _;
    }

    modifier onlyValidAddress(address _recipient) {
        require(_recipient != address(0) && _recipient != address(this) && _recipient != address(token), "not valid _recipient");
        _;
    }

    uint24 constant internal SECONDS_PER_DAY = 86400;
//    uint24 constant internal SECONDS_PER_MONTH = 2592000;
    
    event GrantAdded(address indexed recipient, uint256 vestingId);
    event GrantTokensClaimed(address indexed recipient, uint256 amountClaimed);
    event GrantRemoved(address recipient, uint256 amountVested, uint256 amountNotVested);
    event ChangedAdmin(address admin);

    enum VGroup{ Ecosystem_Development, Founder_Advisors, Team, Seed, Private_Sale}

    struct Grant {
        uint256 startTime;
        uint256 amount;
        uint16 vestingDuration; // In months
        uint16 vestingCliff;    // In months
        uint16 daysClaimed;
        uint256 totalClaimed;
        address recipient;
    }

    // Category of Vesting Group    
    struct VestingGroup {
        uint8 vestingDuration; // In months
        uint8 vestingCliff; // In months
        uint8 percent_tSupply;  // percent of total supply 
    }

    mapping (uint256 => Grant) public tokenGrants;
    mapping (address => uint[]) private activeGrants;
    mapping (VGroup => VestingGroup) parameter; // Enum mapped to Struct
    //address public admin;
    uint256 public totalVestingCount;
    
    constructor(ERC20 _token)  {
        require(address(_token) != address(0));
        owner_ = msg.sender;
        token = _token;
    }

    function vestingGroupParameter(VGroup _name, uint8 _vestingDurationInMonths, 
                        uint8 _vestingCliffInMonths, uint8 _percent) external onlyAdmin{
        require(_vestingDurationInMonths >= _vestingCliffInMonths, "Duration < Cliff");
        parameter[_name] = VestingGroup(_vestingDurationInMonths, _vestingCliffInMonths, _percent);
    }
   
    function addTokenGrant(address[] memory _recipient, VGroup[] memory _name, 
                uint256[] memory _startTime,uint256[] memory _amount)external payable onlyAdmin{
    require(_recipient.length == _name.length, "Different array length");
    require(_recipient.length == _startTime.length, "Different array length");
    require(_recipient.length == _amount.length, "Different array length");
    
    for(uint i=0;i<_recipient.length;i++) {
     // require(_startTime[i] != 0, "should be positive");
      uint256 amountVestedPerDay = _amount[i]/(parameter[_name[i]].vestingDuration*(30));
      require(amountVestedPerDay > 0, "0-amount-vested-per-period");

        // Transfer the grant tokens under the control of the vesting contract
        token.approve(owner_, _amount[i]);
        require(token.transferFrom(owner_, address(this), _amount[i]), "transfer failed");

        Grant memory grant = Grant({
            startTime: _startTime[i] == 0 ? currentTime() : _startTime[i],
            amount: _amount[i],
            vestingDuration: parameter[_name[i]].vestingDuration,
            vestingCliff: parameter[_name[i]].vestingCliff,
            daysClaimed: 0,
            totalClaimed: 0,
            recipient: _recipient[i]
        });
        tokenGrants[totalVestingCount] = grant;
        activeGrants[_recipient[i]].push(totalVestingCount);
        emit GrantAdded(_recipient[i], totalVestingCount);
        totalVestingCount++;    //grantId
        }
    }

    function getActiveGrants(address _recipient) public view returns(uint256[] memory){
        return activeGrants[_recipient];
    }

    /// @notice Calculate the vested and unclaimed months and tokens available for `_grantId` to claim
    /// Due to rounding errors once grant duration is reached, returns the entire left grant amount
    /// Returns (0, 0) if cliff has not been reached
    function calculateGrantClaim(uint256 _grantId) public view returns (uint16, uint256) {
        Grant storage tokenGrant = tokenGrants[_grantId];

        // For grants created with a future start date, that hasn't been reached, return 0, 0
        if (currentTime() < tokenGrant.startTime) {
            return (0, 0);
        }

        // Check cliff was reached
        uint elapsedTime = currentTime()-(tokenGrant.startTime);
        uint elapsedDays = elapsedTime/(SECONDS_PER_DAY);
        
        if (elapsedDays < tokenGrant.vestingCliff*(30)) {
            return (uint16(elapsedDays), 0);
        }

        // If over vesting duration, all tokens vested
        if (elapsedDays >= tokenGrant.vestingDuration*(30)) {
            uint256 remainingGrant = tokenGrant.amount-(tokenGrant.totalClaimed);
            return (tokenGrant.vestingDuration, remainingGrant);
        } else {
            uint16 timeVested = uint16(elapsedDays-(tokenGrant.daysClaimed));
            uint256 amountVestedPerDay = tokenGrant.amount/(uint256(tokenGrant.vestingDuration*(30)));
            uint256 amountVested = uint256(timeVested*(amountVestedPerDay));
            return (timeVested, amountVested);
        }
    }

    /// @notice Allows a grant recipient to claim their vested tokens. Errors if no tokens have vested
    /// It is advised recipients check they are entitled to claim via `calculateGrantClaim` before calling this
    function claimVestedTokens(uint256 _grantId) external {
        uint16 timeVested;
        uint256 amountVested;
        (timeVested, amountVested) = calculateGrantClaim(_grantId);
        require(amountVested > 0, "amountVested is 0");

        Grant storage tokenGrant = tokenGrants[_grantId];
        tokenGrant.daysClaimed = uint16(tokenGrant.daysClaimed+(timeVested));
        tokenGrant.totalClaimed = uint256(tokenGrant.totalClaimed+(amountVested));
        
        require(token.transfer(tokenGrant.recipient, amountVested), "no tokens");
        emit GrantTokensClaimed(tokenGrant.recipient, amountVested);
    }

    /// @notice Terminate token grant transferring all vested tokens to the `_grantId`
    /// and returning all non-vested tokens to the V12 MultiSig
    /// Secured to the V12 MultiSig only
    /// @param _grantId grantId of the token grant recipient
    function removeTokenGrant(uint256 _grantId) 
        external 
        onlyAdmin
    {
        Grant storage tokenGrant = tokenGrants[_grantId];
        address recipient = tokenGrant.recipient;
        uint16 timeVested;
        uint256 amountVested;
        (timeVested, amountVested) = calculateGrantClaim(_grantId);

        uint256 amountNotVested = (tokenGrant.amount-(tokenGrant.totalClaimed))-(amountVested);

        require(token.transfer(recipient, amountVested));
        require(token.transfer(owner_, amountNotVested));

        tokenGrant.startTime = 0;
        tokenGrant.amount = 0;
        tokenGrant.vestingDuration = 0;
        tokenGrant.vestingCliff = 0;
        tokenGrant.daysClaimed = 0;
        tokenGrant.totalClaimed = 0;
        tokenGrant.recipient = address(0);

        emit GrantRemoved(recipient, amountVested, amountNotVested);
    }

    function currentTime() public view returns(uint256) {
        return block.timestamp;
    }

    function tokensVestedPerDay(uint256 _grantId) public view returns(uint256) {
        Grant storage tokenGrant = tokenGrants[_grantId];
        return tokenGrant.amount/(uint256(tokenGrant.vestingDuration/(30)));
    }

    function changeAdmin(address _newAdmin) 
        external 
        onlyAdmin
        onlyValidAddress(_newAdmin)
    {
        owner_ = _newAdmin;
        emit ChangedAdmin(_newAdmin);
    }

}