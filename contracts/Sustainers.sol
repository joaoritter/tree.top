pragma solidity >=0.4.25 <0.7.0;

// The Sustainers contract specifies the workings of a system made up of Purposes and their stewards, constrained only by time.
// Each Purpose has a predefined sustainability that can be contributed to by any sustainer, after which the surplus get's redistributed proportionally to sustainers.
contract Sustainers {
    // The Purpose structure represents a purpose envisioned by a steward, and accounts for who has contributed to the vision.
    struct Purpose {
        // The address which is stewarding this purpose.
        address steward;
        // The amount that represents sustainability for this purpose.
        uint256 sustainability;
        // The description of this purpose. This is an opportunity for the steward to make the case
        // for this Purpose's sutainability on-chain.
        string description;
        // The number of days this Purpose can be sustained for according to `sustainability`.
        uint256 duration;
        // The time when this Purpose will become active.
        uint256 start;
        // The running amount that's been contributed to sustaining this purpose.
        uint256 sustainment;
        // The addresses who have helped to sustain this purpose.
        address[] sustainers;
        // The amount each address has contributed to the sustaining of this purpose.
        mapping(address => uint256) sustainments;
        // The net amount each address has contributed to the sustaining of this purpose after redistribution.
        mapping(address => uint256) netSustainments;
        // The amount that has been redistributed to each address as a consequence of abundant sustainment of this Purpose.
        mapping(address => uint256) redistribution;
        // Helper to verify this Purpose exists.
        bool exists;
    }

    // The past Purposes, which are entirely immutable.
    mapping(address => Purpose[]) pastPurposes;

    // The current Purposes, which are immutable once the Purpose receives some sustainment.
    mapping(address => Purpose) currentPurposes;

    // The next Purposes, which are entirely mutable until they becomes the current Purpose.
    mapping(address => Purpose) nextPurposes;

    // The amount that has been redistributed to each address as a consequence of overall abundance.
    mapping(address => uint256) redistribution;

    // IERC20 public daiInstance;

    // constructor() public {
    // balances[tx.origin] = 10000;
    // }
    // constructor(IERC20 _daiInstance) public {
    //   daiInstance = _daiInstance;
    // }

    function updateSustainability(uint256 _sustainability) public {
        Purpose storage purpose = purposeToUpdate(msg.sender);
        purpose.sustainability = _sustainability;
    }

    function updateDuration(uint256 _duration) public {
        Purpose storage purpose = purposeToUpdate(msg.sender);
        purpose.duration = _duration;
    }

    function updateDescription(string memory _description) public {
        Purpose storage purpose = purposeToUpdate(msg.sender);
        purpose.description = _description;
    }

    // Contribute a specified amount to the sustainability of the specified Steward's active Purpose.
    // If the amount results in surplus, redistribute the surplus proportionally to sustainers of the Purpose.
    function sustain(address _steward, uint256 _amount) public {
        // The function first tries to operate on the state of the current Purpose belonging to the specified steward.
        Purpose storage currentPurpose = currentPurposes[_steward];

        require(
            currentPurpose.exists,
            "This account isn't currently stewarding a purpose."
        );
        require(_amount > 0, "The sustainment amount should be positive.");

        sustainPurpose(currentPurpose, _steward, _amount);
    }

    // A sender can withdrawl funds that have been redistributed to it.
    function withdrawl(uint256 _amount) public {
        require(redistribution[msg.sender] > 0, "There's nothing to collect.");

        //TODO: transfer to msg.sender wallet;
    }

    // Contribute a specified amount to the sustainability of a Purpose stewarded by the specified address.
    // If the amount results in surplus, redistribute the surplus proportionally to sustainers of the Purpose.
    function sustainPurpose(
        Purpose storage _purpose,
        address _steward,
        uint256 _amount
    ) private {
        // If the current time is greater than the current Purpose's endTime, progress to the next Purpose.
        if (now > _purpose.start + (_purpose.duration * 1 days)) {
            Purpose storage nextPurpose = nextPurposes[_steward];
            require(
                nextPurpose.exists,
                "This account isn't currently stewarding a purpose."
            );
            pastPurposes[_steward].push(_purpose);
            currentPurposes[_steward] = nextPurposes[_steward];
            sustainPurpose(_purpose, _steward, _amount);
            return;
        }

        /// ************* Before changing state:
        // Save the amount to send to the steward of the Purpose.
        uint256 amountToSendToSteward = _purpose.sustainability -
            _purpose.sustainment >
            _amount
            ? _amount
            : _purpose.sustainability - _purpose.sustainment;
        // Save if the message sender is contributing to this Purpose for the first time.
        bool isNewSustainer = _purpose.sustainments[msg.sender] == 0;
        /// *************

        /// ************* TODO: Transfer an amount to the steward:
        // bool success = daiInstance.transferFrom(msg.sender, address(this), amountToSend);
        // require(success, "Transfer failed.");
        /// *************

        /// ************* Update the state of the Purpose:
        // Increment the sustainments to the Purpose made by the message sender.
        _purpose.sustainments[msg.sender] += _amount;
        // Increment the total amount contributed to the sustainment of the Purpose.
        _purpose.sustainment += _amount;
        // Add the message sender as a sustainer of the Purpose if this is the first sustainment it's making to it.
        if (isNewSustainer) {
            _purpose.sustainers.push(msg.sender);
        }
        /// *************

        /// ************* Manage redistribution:
        // Save the amount to distribute before changing the state.
        uint256 amountToDistribute = _purpose.sustainment <=
            _purpose.sustainability
            ? 0
            : _purpose.sustainment - _purpose.sustainability;
        // Redistribute any leftover amount.
        if (amountToDistribute > 0) {
            redistribute(_purpose, amountToDistribute);
        }
        /// *************
    }

    // function progressPurpose(address _steward) private {
    //   require(nextPurposes[_steward] > 0, "");

    //   //TODO not sure consequence of referencing like this.
    //   Purpose currentPurpose = currentPurposes[_steward];
    //   unit currentPurposeDuration = currentPurpose.duration;
    //   unit currentPurposeSustainability = currentPurpose.sustainability;
    //   unit currentPurposeDescription = currentPurpose.description;

    //   //TODO: fix up.
    //   currentPurposes[_steward] = nextChapter[_steward];
    //   nextChapter[_steward] = 0;
    //   // Chapter(now, currentPurposeDuration, _steward, currentPurposeSustainability, 0, description);
    // }

    // The sustainability of a Purpose cannot be updated if there have been sustainments made to it.
    function purposeToUpdate(address _steward)
        private
        returns (Purpose storage)
    {
        // If the steward does not have a current Purpose in the current Chapter, make one and return it.
        if (!currentPurposes[_steward].exists) {
            Purpose storage purpose = currentPurposes[_steward];
            purpose.exists = true;
            return purpose;
        }

        // If the steward's current Purpose does not yet have sustainments, return it.
        if (currentPurposes[_steward].sustainment == 0) {
            return currentPurposes[_steward];
        }

        // If the steward does not have a Purpose in the next Chapter, make one and return it.
        if (!nextPurposes[_steward].exists) {
            Purpose storage purpose = nextPurposes[_steward];
            purpose.exists = true;
            return purpose;
        }

        // Return the steward's next Purpose.
        return nextPurposes[_steward];
    }

    // Proportionally allocate the specified amount to the contributors of the specified Purpose,
    // meaning each sustainer will receive a portion of the specified amount equivalent to the portion of the total
    // amount contributed to the sustainment of the Purpose that they are responsible for.
    function redistribute(Purpose storage purpose, uint256 amount) internal {
        assert(amount > 0);

        // For each sustainer, calculate their share of the sustainment and allocate a proportional share of the amount.
        for (uint256 i = 0; i < purpose.sustainers.length; i++) {
            address sustainer = purpose.sustainers[i];
            uint256 amountShare = (purpose.sustainments[sustainer] * amount) /
                purpose.sustainment;
            redistribution[sustainer] += amountShare;
        }
    }
}
