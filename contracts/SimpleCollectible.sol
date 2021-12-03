// SPDX License-Identifier: MIT

pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SimpleCollectible is ERC721 {
    uint256 public tokenCounter;

    constructor(string memory _name, string memory _symbol)
        public
        ERC721(_name, _symbol)
    {
        tokenCounter = 0;
    }

    function CreateCollectible(string memory tokenURI)
        public
        returns (uint256)
    {
        uint256 newTokenId = tokenCounter;
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        tokenCounter = tokenCounter + 1;
        return newTokenId;
    }

    function TransferCollectible(address _to, uint256 _tokenId) public {
        safeTransferFrom(msg.sender, _to, _tokenId, "none");
    }
}
