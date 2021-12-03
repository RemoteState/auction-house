//SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RSCoin is ERC20, Ownable {
    event minted(address owner, uint256 amount);

    constructor(string memory name_, string memory symbol_)
        public
        ERC20(name_, symbol_)
    {}

    function mintByOwner(uint256 amount) public onlyOwner {
        _mint(msg.sender, amount);
        emit minted(msg.sender, amount);
    }
}
