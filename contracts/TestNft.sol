//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";

contract TestNft is ERC721{
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol){
    }

    uint tokenId;

    function mint() external payable{
        tokenId += 1;
        _mint(msg.sender, tokenId);
    }


}