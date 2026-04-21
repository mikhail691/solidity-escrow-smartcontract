// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Escrow {
    enum EscrowState {
        AWAITING_PAYMENT,
        AWAITING_DELIVERY,
        COMPLETE,
        REFUNDED
    }

    address public immutable buyer;
    address public immutable seller;
    address public immutable arbiter;
    uint256 public immutable amount;
    EscrowState public state;

    event Deposited(address indexed from, uint256 value);
    event Released(address indexed to, uint256 value);
    event Refunded(address indexed to, uint256 value);

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter");
        _;
    }

    modifier inState(EscrowState expected) {
        require(state == expected, "Invalid state");
        _;
    }

    constructor(address _buyer, address _seller, address _arbiter, uint256 _amount) {
        require(_buyer != address(0), "Invalid buyer");
        require(_seller != address(0), "Invalid seller");
        require(_arbiter != address(0), "Invalid arbiter");
        require(_amount > 0, "Amount must be > 0");

        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        amount = _amount;
        state = EscrowState.AWAITING_PAYMENT;
    }

    function deposit() external payable onlyBuyer inState(EscrowState.AWAITING_PAYMENT) {
        require(msg.value == amount, "Incorrect deposit amount");
        state = EscrowState.AWAITING_DELIVERY;
        emit Deposited(msg.sender, msg.value);
    }

    function confirmDelivery() external onlyBuyer inState(EscrowState.AWAITING_DELIVERY) {
        state = EscrowState.COMPLETE;
        (bool success, ) = seller.call{value: address(this).balance}("");
        require(success, "Transfer to seller failed");
        emit Released(seller, amount);
    }

    function arbiterReleaseToSeller() external onlyArbiter inState(EscrowState.AWAITING_DELIVERY) {
        state = EscrowState.COMPLETE;
        (bool success, ) = seller.call{value: address(this).balance}("");
        require(success, "Transfer to seller failed");
        emit Released(seller, amount);
    }

    function refundBuyer() external onlyArbiter inState(EscrowState.AWAITING_DELIVERY) {
        state = EscrowState.REFUNDED;
        (bool success, ) = buyer.call{value: address(this).balance}("");
        require(success, "Refund transfer failed");
        emit Refunded(buyer, amount);
    }
}
