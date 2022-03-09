from brownie import accounts, network, exceptions
from scripts.deploy_auction import deploy_auction
from scripts.helpful_scripts import LOCAL_BLOCKCHAIN_ENVIRONMENTS, get_account
import pytest
from web3 import Web3

TEST_URI = "https://ipfs.io/ipfs/Qmd9MCGtdVz2miNumBHDbvj8bigSgTwnr4SbyH6DNnpWdt?filename=0-PUG.json"


def test_can_start_auction():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account(0)
    assert auction.auction_state() == 1
    tx = auction.StartAuction(TEST_URI, {"from": account})
    tx.wait(1)
    assert auction.auction_state() == 0


def test_cannot_start_auction_unless_owner():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account(1)
    with pytest.raises(exceptions.VirtualMachineError):
        auction.StartAuction(TEST_URI, {"from": account})


def test_cannot_bid_unless_added():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account()
    tx = auction.StartAuction(TEST_URI, {"from": account})
    tx.wait(1)
    with pytest.raises(exceptions.VirtualMachineError):
        # auction.NewBid(auction.GAS_FEE() + Web3.toWei(1, "ether"), {"from": account})
        rsCoin.transferAndCall(
            auction.address,
            auction.GAS_FEE() + Web3.toWei(1, "ether"),
            {"from": account},
        )


def test_cannot_bid_without_rscoin():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account(index=1)
    tx = auction.AddPlayer(account, {"from": get_account()})
    tx.wait(1)
    assert rsCoin.balanceOf(account) == 0
    with pytest.raises(exceptions.VirtualMachineError):
        rsCoin.transferAndCall(
            auction.address,
            auction.GAS_FEE() + Web3.toWei(1, "ether"),
            {"from": account},
        )


def test_cannot_bid_unless_open():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account()
    tx = rsCoin.approve(
        auction.address, auction.GAS_FEE() + Web3.toWei(1, "ether"), {"from": account}
    )
    tx.wait(1)
    tx = auction.AddPlayer(account, {"from": account})
    tx.wait(1)
    with pytest.raises(exceptions.VirtualMachineError):
        rsCoin.transferAndCall(
            auction.address,
            auction.GAS_FEE() + Web3.toWei(1, "ether"),
            {"from": account},
        )


def test_can_bid():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account()
    tx = auction.StartAuction(TEST_URI, {"from": account})
    tx.wait(1)
    rsCoin.approve(
        auction.address, Web3.toWei(1, "ether") + auction.GAS_FEE(), {"from": account}
    )
    tx = auction.AddPlayer(account, {"from": account})
    tx.wait(1)
    tx2 = rsCoin.transferAndCall(
        auction.address,
        auction.GAS_FEE() + Web3.toWei(1, "ether"),
        {"from": account},
    )
    tx2.wait(1)
    assert auction.winningBid() == Web3.toWei(1, "ether")
    assert auction.winningBidder() == account.address


def test_new_bid_works_properly():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account()
    tx = auction.StartAuction(TEST_URI, {"from": account})
    tx.wait(1)
    tx = auction.AddPlayer(account, {"from": account})
    tx.wait(1)
    tx = auction.AddPlayer(get_account(index=1), {"from": account})
    tx.wait(1)
    tx2 = rsCoin.transferAndCall(
        auction.address,
        auction.GAS_FEE() + Web3.toWei(1, "ether"),
        {"from": account},
    )
    tx2.wait(1)
    account = get_account(index=1)
    tx = rsCoin.transfer(
        account, Web3.toWei(50, "ether"), {"from": get_account(index=0)}
    )
    tx.wait(1)
    tx3 = rsCoin.transferAndCall(
        auction.address,
        (auction.GAS_FEE() + Web3.toWei(2, "ether")),
        {"from": account},
    )
    tx3.wait(1)
    assert auction.winningBid() == Web3.toWei(2, "ether")
    assert auction.winningBidder() == get_account(index=1).address


def test_cannot_end_unless_open():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account()
    with pytest.raises(exceptions.VirtualMachineError):
        auction.EndAuction({"from": account})


def test_mining_works_properly():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account()
    tx = auction.StartAuction(TEST_URI, {"from": account})
    tx.wait(1)
    tx = auction.AddPlayer(account, {"from": account})
    tx.wait(1)
    tx = auction.AddPlayer(get_account(index=1), {"from": account})
    tx.wait(1)
    tx.wait(1)
    for i in range(0, 10):
        tx = rsCoin.transferAndCall(
            auction.address,
            (auction.GAS_FEE() + Web3.toWei(2, "ether") + auction.winningBid()),
            {"from": account},
        )
    print(rsCoin.balanceOf(get_account(index=1)))
    assert auction.winningBid() == Web3.toWei(20, "ether")
    assert rsCoin.balanceOf(get_account(index=1)) != 0


def test_can_pick_winner_correctly():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    auction, rsCoin = deploy_auction()
    account = get_account()
    tx = auction.StartAuction(TEST_URI, {"from": account})
    tx.wait(1)
    tx = auction.AddPlayer(account, {"from": account})
    tx.wait(1)
    tx = auction.AddPlayer(get_account(index=1), {"from": account})
    tx.wait(1)
    tx2 = rsCoin.transferAndCall(
        auction.address,
        (auction.GAS_FEE() + Web3.toWei(1, "ether")),
        {"from": account},
    )
    tx2.wait(1)
    account = get_account(index=1)
    tx = rsCoin.transfer(
        account, Web3.toWei(50, "ether"), {"from": get_account(index=0)}
    )
    tx.wait(1)
    tx3 = rsCoin.transferAndCall(
        auction.address,
        (auction.GAS_FEE() + Web3.toWei(1, "ether") + auction.winningBid()),
        {"from": account},
    )
    tx3.wait(1)
    amount = rsCoin.balanceOf(get_account(index=0)) + rsCoin.balanceOf(auction.address)
    tx4 = auction.EndAuction({"from": get_account(index=0)})
    tx4.wait(1)
    assert rsCoin.balanceOf(get_account(index=0)) == amount
    assert auction.auction_state() == 1
    assert auction.ReturnWinner(0) == get_account(index=1).address
    assert (
        auction.winnerToObjectMap(get_account(index=1).address)
        == auction.currentTokenId()
    )
