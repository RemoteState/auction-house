//SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ERC677 {
    function onTokenTransfer(address payable sender, uint256 amount)
        external
        returns (bool success);
}

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

    function transferAndCall(address receiver, uint256 amount)
        public
        returns (bool success)
    {
        require(transfer(receiver, amount));
        ERC677 erc677 = ERC677(receiver);
        require(erc677.onTokenTransfer(msg.sender, amount));
        return true;
    }
}
