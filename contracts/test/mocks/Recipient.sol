pragma solidity ^0.4.24;

import "../../IERC777Recipient.sol";

contract Recipient is IERC777Recipient {

    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes userData,
        bytes operatorData
    ) external {

    }

}
