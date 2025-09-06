// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract CaseRegistry {
    enum Status {
        Open,
        Proposed,
        Challenged,
        Finalized
    }
    enum Outcome {
        None,
        PayProvider,
        RefundClient
    }

    struct CaseData {
        address client;
        address provider;
        address token; // address(0) for ETH
        uint256 amount;
        string[] evidencesClient; // IPFS CID(s) as a single string
        string[] evidencesProvider;
        string justification; // plaintext justification for proposed outcome by AI judge
        uint64 deadline; // unix time delivery deadline
        uint64 proposedAt; // block timestamp when proposed
        Status status;
        Outcome outcome;
    }

    address public aiJudge; // trusted propose
    uint64 public challengeSecs;
    uint256 public nextId;
    mapping(uint256 => CaseData) public cases;

    event CaseOpened(
        uint256 id,
        address client,
        address provider,
        uint256 amount
    );
    event Evidence(uint256 id, address party, string cid);
    event Proposed(uint256 id, Outcome outcome, string justification);
    event Challenged(uint256 id, address challenger);
    event Finalized(uint256 id, Outcome outcome);

    constructor(address _aiJudge, uint64 _challengeSecs) {
        aiJudge = _aiJudge;
        challengeSecs = _challengeSecs;
    }

    modifier onlyJudge() {
        require(msg.sender == aiJudge, "not ai");
        _;
    }

    function openCase(
        address provider,
        uint64 deadline,
        string[] calldata initialEvidences
    ) external payable returns (uint256 id) {
        require(msg.value > 0, "need funds");
        id = nextId++;
        cases[id] = CaseData({
            client: msg.sender,
            provider: provider,
            token: address(0),
            amount: msg.value,
            evidencesClient: initialEvidences,
            evidencesProvider: new string[](0),
            justification: "",
            deadline: deadline,
            proposedAt: 0,
            status: Status.Open,
            outcome: Outcome.None
        });
        emit CaseOpened(id, msg.sender, provider, msg.value);
    }

    function submitEvidence(uint256 id, string calldata cid) public {
        CaseData storage c = cases[id];
        require(
            c.status == Status.Open || c.status == Status.Proposed,
            "bad status"
        );
        require(
            msg.sender == c.client || msg.sender == c.provider,
            "not party"
        );
        if (msg.sender == c.client) {
            c.evidencesClient.push(cid);
        } else {
            c.evidencesProvider.push(cid);
        }
        emit Evidence(id, msg.sender, cid);
    }

    // AI judge calls with decision + plaintext justification
    function proposeDecision(
        uint256 id,
        Outcome outcome,
        string calldata justification
    ) external onlyJudge {
        CaseData storage c = cases[id];
        require(
            c.status == Status.Open || c.status == Status.Proposed,
            "bad status"
        );
        c.outcome = outcome;
        c.justification = justification;
        c.proposedAt = uint64(block.timestamp);
        c.status = Status.Proposed;
        emit Proposed(id, outcome, justification);
    }

    function challenge(uint256 id) external {
        CaseData storage c = cases[id];
        require(c.status == Status.Proposed, "not proposed");
        require(block.timestamp <= c.proposedAt + challengeSecs, "window over");
        c.status = Status.Challenged;
        emit Challenged(id, msg.sender);
    }

    function finalize(uint256 id) external {
        CaseData storage c = cases[id];
        require(c.status == Status.Proposed, "not finalizable");
        require(block.timestamp > c.proposedAt + challengeSecs, "window open");
        c.status = Status.Finalized;

        if (c.outcome == Outcome.PayProvider) {
            (bool ok, ) = c.provider.call{value: c.amount}("");
            require(ok, "pay provider fail");
        } else if (c.outcome == Outcome.RefundClient) {
            (bool ok, ) = c.client.call{value: c.amount}("");
            require(ok, "refund client fail");
        } else {
            revert("no outcome");
        }
        emit Finalized(id, c.outcome);
    }

    function getPartyCaseIds(
        address party
    ) external view returns (uint256[] memory ids) {
        uint256 count;
        for (uint256 i = 0; i < nextId; i++) {
            if (cases[i].client == party || cases[i].provider == party) {
                count++;
            }
        }
        ids = new uint256[](count);
        uint256 idx;
        for (uint256 i = 0; i < nextId; i++) {
            if (cases[i].client == party || cases[i].provider == party) {
                ids[idx++] = i;
            }
        }
    }

    function getCaseEvidences(
        uint256 id
    )
        external
        view
        returns (
            string[] memory clientEvidences,
            string[] memory providerEvidences
        )
    {
        CaseData storage c = cases[id];
        clientEvidences = c.evidencesClient;
        providerEvidences = c.evidencesProvider;
    }
}
