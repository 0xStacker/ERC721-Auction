//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20("Test", "TST"){

    function mint(uint amount) external{
        _mint(msg.sender, amount);
    }
}