from scripts.deploy_coin import deploy_coin, mint_coin
from scripts.helpful_scripts import fund_with_link, get_account, get_contract
from brownie import AuctionHouse, config, network, RSCoin
import time
from web3 import Web3


def deploy_auction():
    account = get_account()
    if len(RSCoin) <= 0:
        deploy_coin()
        mint_coin()
    rsCoin = RSCoin[-1]
    auction = AuctionHouse.deploy(
        "Test",
        "TestSymbols",
        rsCoin.address,
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )
    print("Deployed Auction!")
    return auction, rsCoin


def start_auction():
    sample_token_uri = "https://ipfs.io/ipfs/Qmd9MCGtdVz2miNumBHDbvj8bigSgTwnr4SbyH6DNnpWdt?filename=0-PUG.json"
    account = get_account()
    auction = AuctionHouse[-1]
    fund_with_link(auction.address)
    starting_tx = auction.StartAuction(sample_token_uri, {"from": account})
    starting_tx.wait(1)
    print("The Auction is started!")


def enter_auction():
    account = get_account()
    auction = AuctionHouse[-1]
    rsCoin = RSCoin[-1]
    gas_fee = auction.GAS_FEE()
    value = Web3.toWei(1, "ether") + auction.winningBid()
    tx = rsCoin.approve(auction.address, gas_fee + value, {"from": account})
    tx.wait(1)
    tx = auction.NewBid(value, {"from": account})
    tx.wait(1)
    account = get_account(index=1)
    tx = rsCoin.transfer(
        account, Web3.toWei(50, "ether"), {"from": get_account(index=0)}
    )
    tx.wait(1)
    tx = rsCoin.approve(
        auction.address, gas_fee + auction.winningBid() + value, {"from": account}
    )
    tx.wait(1)
    tx = auction.NewBid(value + auction.winningBid(), {"from": account})
    tx.wait(1)
    print(auction.winningBid())
    print(rsCoin.balanceOf(auction.address))
    print(rsCoin.balanceOf(account))
    print("Entered the Auction!")


def end_auction():
    account = get_account()
    auction = AuctionHouse[-1]
    tx = auction.EndAuction({"from": account})
    tx.wait(1)
    time.sleep(10)
    print("Auction ended :-(")
    print(f"Recent winner is {auction.winners(0)}")


def main():
    deploy_auction()
    start_auction()
    # enter_auction()
    # end_auction()
