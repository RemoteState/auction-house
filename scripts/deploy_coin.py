from brownie import RSCoin, config, network
from scripts.helpful_scripts import get_account
from web3 import Web3


def deploy_coin():
    account = get_account()
    rsCoin = RSCoin.deploy(
        "RemoteState Coin",
        "RSCoin",
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )
    print("RSCoin deployed!")
    return rsCoin


def mint_coin():
    account = get_account()
    rsCoin = RSCoin[-1]
    tx = rsCoin.mintByOwner(Web3.toWei(1000, "ether"), {"from": account})
    tx.wait(1)
    print(f"Minted 1000 RSCoin for {account}")


def main():
    deploy_coin()
    mint_coin()
