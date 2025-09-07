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
        ApproveClaimant,
        ApproveDefendant,
        Clearify,
        RequestOpposerEvidence,
        RequestDefenderEvidence
    }

    struct Case {
        address claimant;
        address defendant;
        address token; // address(0) for ETH
        uint256 amount;
        Evidence[] evidencesClaimant;
        Evidence[] evidencesDefendant;
        string complaint; // plaintext complaint by claimant
        string[] justificationHistory; // plaintext justification for proposed outcome by AI judge
        string[] challengeHistory; // plaintext reasons for challenges
        uint64 deadline; // unix time delivery deadline
        uint64 proposedAt;
        Status status;
        Outcome outcome;
    }

    struct Policy {
        uint256 id;
        string name;
        string description;
        address policyOwner;
        uint256 createdAt; // unix time when policy was created
    }

    struct Evidence {
        string cid; // IPFS CID
        uint256 policyId; // associated policy
        uint256 createdAt; // unix time when evidence was created
    }

    address public aiJudge; // trusted proposer
    uint64 public challengeSecs;
    uint256 public nextCaseId = 0;
    uint256 public nextPolicyId = 0;
    mapping(uint256 => Case) public cases;
    mapping(uint256 => Policy) public policies;

    event CaseOpened(
        uint256 id,
        address claimant,
        address defendant,
        uint256 amount
    );
    event EvidenceSubmitted(uint256 caseId, address party, Evidence evidence);
    event Proposed(uint256 caseId, Outcome outcome, string justification);
    event Challenged(uint256 caseId, address challenger);
    event Finalized(uint256 caseId, Outcome outcome);

    constructor(address _aiJudge, uint64 _challengeSecs) {
        aiJudge = _aiJudge;
        challengeSecs = _challengeSecs;
    }

    modifier onlyJudge() {
        require(msg.sender == aiJudge, "not ai");
        _;
    }

    function openCase(
        address defendant,
        string calldata complaint,
        uint64 deadline,
        Evidence[] calldata initialEvidences
    ) external payable returns (uint256) {
        require(msg.value > 0, "need funds");
        uint256 id = nextCaseId++;
        cases[id] = Case({
            claimant: msg.sender,
            defendant: defendant,
            token: address(0),
            amount: msg.value,
            evidencesClaimant: initialEvidences,
            evidencesDefendant: new Evidence[](0),
            complaint: complaint,
            justificationHistory: new string[](0),
            challengeHistory: new string[](0),
            deadline: deadline,
            proposedAt: uint64(block.timestamp),
            status: Status.Open,
            outcome: Outcome.None
        });
        emit CaseOpened(id, msg.sender, defendant, msg.value);
        return id;
    }

    function submitEvidence(uint256 caseId, Evidence calldata evidence) public {
        Case storage c = cases[caseId];
        require(
            c.status == Status.Open || c.status == Status.Proposed,
            "bad status"
        );
        require(
            msg.sender == c.claimant || msg.sender == c.defendant,
            "not party"
        );
        if (msg.sender == c.claimant) {
            c.evidencesClaimant.push(evidence);
        } else {
            c.evidencesDefendant.push(evidence);
        }
        emit EvidenceSubmitted(caseId, msg.sender, evidence);
    }

    // AI judge calls with decision + plaintext justification
    function proposeDecision(
        uint256 caseId,
        Outcome outcome,
        string calldata justification
    ) external onlyJudge {
        Case storage c = cases[caseId];
        require(
            c.status == Status.Open || c.status == Status.Proposed,
            "bad status"
        );
        c.outcome = outcome;
        c.justificationHistory.push(justification);
        c.proposedAt = uint64(block.timestamp);
        c.status = Status.Proposed;
        emit Proposed(caseId, outcome, justification);
    }

    function challenge(
        uint256 caseId,
        string calldata reason,
        Evidence[] calldata evidences
    ) external {
        Case storage c = cases[caseId];
        require(c.status == Status.Proposed, "not proposed");
        /*         require(
            block.timestamp <= c.proposedAt + challengeSecs,
            "challenge window closed"
        ); */
        require(
            msg.sender == c.claimant || msg.sender == c.defendant,
            "not party"
        );
        c.status = Status.Challenged;
        c.proposedAt = uint64(block.timestamp); // reset challenge window
        c.challengeHistory.push(reason);
        for (uint256 i = 0; i < evidences.length; i++) {
            if (msg.sender == c.claimant) {
                c.evidencesClaimant.push(evidences[i]);
            } else {
                c.evidencesDefendant.push(evidences[i]);
            }
            emit EvidenceSubmitted(caseId, msg.sender, evidences[i]);
        }
        emit Challenged(caseId, msg.sender);
    }

    function finalize(uint256 caseId) external {
        Case storage c = cases[caseId];
        require(c.status == Status.Proposed, "not finalizable");
        // require(block.timestamp > c.proposedAt + challengeSecs, "window open");
        c.status = Status.Finalized;

        if (c.outcome == Outcome.ApproveDefendant) {
            (bool ok, ) = c.defendant.call{value: c.amount}("");
            require(ok, "pay defendant fail");
        } else if (c.outcome == Outcome.ApproveClaimant) {
            (bool ok, ) = c.claimant.call{value: c.amount}("");
            require(ok, "refund claimant fail");
        } else {
            revert("no outcome");
        }
        emit Finalized(caseId, c.outcome);
    }

    function getPartyCaseIds(
        address party
    ) external view returns (uint256[] memory ids) {
        uint256 count;
        for (uint256 i = 0; i < nextCaseId; i++) {
            if (cases[i].claimant == party || cases[i].defendant == party) {
                count++;
            }
        }
        ids = new uint256[](count);
        uint256 idx;
        for (uint256 i = 0; i < nextCaseId; i++) {
            if (cases[i].claimant == party || cases[i].defendant == party) {
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
            Evidence[] memory claimantEvidences,
            Evidence[] memory defendantEvidences
        )
    {
        Case storage c = cases[id];
        claimantEvidences = c.evidencesClaimant;
        defendantEvidences = c.evidencesDefendant;
    }

    function getCaseChallengeHistory(
        uint256 id
    ) external view returns (string[] memory) {
        return cases[id].challengeHistory;
    }

    function getCaseJustificationHistory(
        uint256 id
    ) external view returns (string[] memory) {
        return cases[id].justificationHistory;
    }

    function createPolicy(
        string calldata name,
        string calldata description
    ) external returns (uint256 id) {
        id = nextPolicyId++;
        policies[id] = Policy({
            id: id,
            name: name,
            description: description,
            policyOwner: msg.sender,
            createdAt: block.timestamp
        });
    }
}
