pragma solidity ^0.4.24;

/* import "./Controlled.sol"; */
/* import "./ITokenController.sol"; */
import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";
import "@aragon/apps-shared-minime/contracts/ITokenController.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import "./IERC777Recipient.sol";

pragma solidity ^0.4.24;

contract Token is Controlled {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowed;
    uint256 private _totalSupply;

    string public name;
    uint8 public decimals;
    string public symbol;
    bool public transfersEnabled;

    string private constant ERROR_NULL_ADDRESS = "NULL_ADDRESS_REJECTED";
    string private constant ERROR_CONTROLLER = "CONTROLLER_REJECTED";

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
    event Sent(
      address indexed _operator, address indexed _from, address indexed _to,
      uint256 _amount, bytes _data, bytes _operatorData
    );

    constructor(string _name, uint8 _decimals, string _symbol, bool _transfersEnabled) public {
        name = _name;
        decimals = _decimals;
        symbol = _symbol;
        transfersEnabled = _transfersEnabled;
    }

    /// @notice The fallback function: If the contract's controller has not been
    ///  set to 0, then the `proxyPayment` method is called which relays the
    ///  ether and creates tokens as described in the token controller contract
    function () external payable {
        require(isContract(controller), "CONTROLLER_IS_NOT_CONTRACT");
        require(ITokenController(controller).proxyPayment.value(msg.value)(msg.sender) == true, ERROR_CONTROLLER);
    }

    /**
     * @dev Modifier to make a function callable only when caller is controller or transfers are enabled.
     */
    modifier transferable() {
        require(msg.sender == controller || transfersEnabled, "NON_TRANSFERABLE");
        _;
    }

    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return A uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
     * @dev Function to mint tokens
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function generateTokens(address _to, uint256 _amount) public onlyController returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    /**
     * @dev Burns a specific amount of tokens from the target address
     * @param _from address The account whose tokens will be burned.
     * @param _amount uint256 The amount of token to be burned.
     */
    function destroyTokens(address _from, uint256 _amount) public onlyController returns (bool) {
        _burn(_from, _amount);
        return true;
    }

    /// @notice Enables token holders to transfer their tokens freely if true
    /// @param _transfersEnabled True if transfers are allowed
    function enableTransfers(bool _transfersEnabled) public onlyController {
        transfersEnabled = _transfersEnabled;
    }

    /**
     * @dev Transfer token to a specified address
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address to, uint256 value) public transferable returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public transferable returns (bool) {
        _transfer(from, to, value);
        /* if(msg.sender != controller) {
          _approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
        } */
        _approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public transferable returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     * @param spender The address which will spend the funds.
     * @param addedValue The increase in spendable amount.
     */
    function increaseAllowance(address spender, uint256 addedValue) public transferable returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The reduction in spendable amount.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public transferable returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Send tokens+data to ERC777 recipient
     * @param to The recipient address.
     * @param value The amount to be sent.
     * @param data The data to be passed along an erc777 compatible recipient contract.
     */
    function send(address to, uint256 value, bytes data) external {
        _transfer(msg.sender, to, value);
        emit Sent(msg.sender, msg.sender, to, value, data, "");
        if(isContract(to))
          IERC777Recipient(to).tokensReceived(msg.sender, msg.sender, to, value, data, "");
    }

    /**
     * @dev Transfer token for a specified addresses
     * @param _from The address to transfer from.
     * @param _to The address to transfer to.
     * @param _amount The amount to be transferred.
     */
    function _transfer(address _from, address _to, uint256 _amount) internal {
        // Alerts the token controller of the transfer
        if (isContract(controller)) {
            require(ITokenController(controller).onTransfer(_from, _to, _amount) == true, ERROR_CONTROLLER);
        }

        require(_to != address(0), ERROR_NULL_ADDRESS);

        _balances[_from] = _balances[_from].sub(_amount);
        _balances[_to] = _balances[_to].add(_amount);
        emit Transfer(_from, _to, _amount);
    }

    /**
     * @dev Approve an address to spend another addresses' tokens.
     * @param _owner The address that owns the tokens.
     * @param _spender The address that will spend the tokens.
     * @param _amount The number of tokens that can be spent.
     */
    function _approve(address _owner, address _spender, uint256 _amount) internal {
        // Alerts the token controller of the approve function call
        if (isContract(controller)) {
            require(ITokenController(controller).onApprove(_owner, _spender, _amount) == true, ERROR_CONTROLLER);
        }

        require(_spender != address(0), ERROR_NULL_ADDRESS);
        require(_owner != address(0), ERROR_NULL_ADDRESS);

        _allowed[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0), ERROR_NULL_ADDRESS);

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), ERROR_NULL_ADDRESS);

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /// @dev Internal function to determine if an address is a contract
    /// @param _addr The address being queried
    /// @return True if `_addr` is a contract
    function isContract(address _addr) internal view returns(bool) {
        uint size;
        if (_addr == 0)
            return false;

        assembly {
            size := extcodesize(_addr)
        }

        return size>0;
    }
}
