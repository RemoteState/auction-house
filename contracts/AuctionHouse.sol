// SPDX License-Identifier: MIT

pragma solidity 0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./RSCoin.sol";
import "./SimpleCollectible.sol";

contract AuctionHouse is Ownable, IERC721Receiver {
    enum AUCTION_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    AUCTION_STATE public auction_state;
    address[] internal players;
    mapping(address => uint256) internal playersIndex;
    uint256 public winningBid;
    address payable public winningBidder;
    event HighestBidIncreased(
        uint256 indexed tokenId,
        address bidder,
        uint256 amount
    );
    event AuctionEnded(address winner, uint256 amount, uint256 tokenId);
    // event RequestedRandomness(bytes32 requestId);
    mapping(address => uint256) public winnerToObjectMap;
    address[] public winners;
    SimpleCollectible public nft;
    uint256 public currentTokenId;
    RSCoin public currency;
    uint256 public constant GAS_FEE = 500000000000000000;
    address internal currentBidder;

    constructor(
        string memory _name,
        string memory _symbol,
        address _currency
    ) public {
        auction_state = AUCTION_STATE.CLOSED;
        nft = new SimpleCollectible(_name, _symbol);
        currency = RSCoin(_currency);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    modifier CheckPlayer(address player) {
        require(playersIndex[player] > 0, "Player is not part of Auction!");
        _;
    }

    function AddPlayer(address player) public onlyOwner {
        require(playersIndex[player] == 0, "Player already exists!");
        players.push(player);
        playersIndex[player] = players.length;
    }

    function RemovePlayer(address player) public CheckPlayer(player) onlyOwner {
        require(players.length > 0);
        uint256 index = playersIndex[player];
        players[index - 1] = players[players.length - 1];
        playersIndex[players[index - 1]] = index;
        players.pop();
        playersIndex[player] = 0;
    }

    function StartAuction(string memory _tokenURI) public onlyOwner {
        require(
            auction_state == AUCTION_STATE.CLOSED,
            "Auction not closed yet!"
        );
        auction_state = AUCTION_STATE.OPEN;
        winningBid = 0;
        winningBidder = address(0);
        currentTokenId = nft.CreateCollectible(_tokenURI);
    }

    function EndAuction() public onlyOwner {
        require(auction_state == AUCTION_STATE.OPEN, "Auction not open yet!");
        require(players.length > 0, "No one has bid yet!");
        auction_state = AUCTION_STATE.CLOSED;
        nft.TransferCollectible(winningBidder, currentTokenId);
        winnerToObjectMap[winningBidder] = currentTokenId;
        emit AuctionEnded(winningBidder, winningBid, currentTokenId);
        winners.push(winningBidder);
        currency.transfer(owner(), winningBid);
    }

    function onTokenTransfer(address payable sender, uint256 amount)
        external
        CheckPlayer(sender)
        returns (bool success)
    {
        require(auction_state == AUCTION_STATE.OPEN, "Auction not open yet!");
        require(
            (amount - GAS_FEE) > winningBid,
            "Amount needs to be greater than current bid!"
        );
        require(msg.sender == address(currency));
        currentBidder = sender;
        uint256 random = random();
        address randomMiner = players[random % players.length];
        require(currency.transfer(randomMiner, GAS_FEE));

        if (winningBid != 0 && winningBidder != address(0)) {
            require(currency.transfer(winningBidder, winningBid));
        }
        winningBidder = sender;
        winningBid = amount - GAS_FEE;
        emit HighestBidIncreased(currentTokenId, sender, winningBid);
        return true;
    }

    function random() private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        msg.sender,
                        players,
                        block.number,
                        block.gaslimit,
                        blockhash(block.number)
                    )
                )
            );
    }

    function ReturnWinner(uint256 index) external view returns (address) {
        return winners[index];
    }

    function IsPlayerAdded() external view returns (bool) {
        if (playersIndex[msg.sender] == 0) {
            return false;
        } else {
            return true;
        }
    }

    function GetMetaDataByTokenID(uint256 _token_id)
        external
        view
        returns (string memory)
    {
        require(_token_id <= currentTokenId);
        return nft.tokenURI(_token_id);
    }
}
