// SPDX License-Identifier: MIT

pragma solidity 0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "./RSCoin.sol";
import "./SimpleCollectible.sol";

contract AuctionHouse is Ownable, IERC721Receiver, VRFConsumerBase {
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
    event HighestBidIncreased(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount, uint256 tokenId);
    // event RequestedRandomness(bytes32 requestId);
    mapping(address => uint256) public winnerToObjectMap;
    address[] public winners;
    SimpleCollectible public nft;
    uint256 public currentTokenId;
    RSCoin public currency;
    uint256 public GAS_FEE = 500000000000000000;
    address internal currentBidder;
    uint256 internal fee;
    bytes32 internal keyHash;

    constructor(
        string memory _name,
        string memory _symbol,
        address _currency,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyHash
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        auction_state = AUCTION_STATE.CLOSED;
        nft = new SimpleCollectible(_name, _symbol);
        currency = RSCoin(_currency);
        fee = _fee;
        keyHash = _keyHash;
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

    function NewBid(uint256 amount) public CheckPlayer(msg.sender) {
        require(auction_state == AUCTION_STATE.OPEN, "Auction not open yet!");
        require(
            amount > winningBid,
            "Amount needs to be greater than current bid!"
        );
        require(
            currency.balanceOf(msg.sender) >= GAS_FEE + amount,
            "Not enough balance!"
        );
        require(
            currency.allowance(msg.sender, address(this)) >= GAS_FEE + amount,
            "Not approved!"
        );
        currentBidder = msg.sender;
        uint256 random = random();
        address randomMiner = players[random % players.length];
        require(currency.transferFrom(msg.sender, randomMiner, GAS_FEE));
        require(currency.transferFrom(msg.sender, address(this), amount));

        // bytes32 requestId = requestRandomness(keyHash, fee);
        // emit RequestedRandomness(requestId);

        if (winningBid != 0 && winningBidder != address(0)) {
            currency.transfer(winningBidder, winningBid);
        }
        emit HighestBidIncreased(msg.sender, amount);
        winningBidder = msg.sender;
        winningBid = amount;
    }

    // Deprecating usage because time taken for VRFCoordinator to callback is too long

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        require(randomness > 0, "Randomness not generated");
        uint256 randomMiner = randomness % players.length;
        require(
            currency.transferFrom(currentBidder, players[randomMiner], GAS_FEE)
        );
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
}
