// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //TGE 7% AdvisersAndPartnerships, 5% Marketing, 0% Reservefunds.
    uint256 public advisersAndPartnershipsTGE;
    uint256 public marketingTGE;
    uint256 public reserveFundsTGE;

    uint256 public totalTokensinContract;
    uint256 public totalWithdrawableAmount;

    //tokens that can be withdrawn at any time.
    uint256 public advisersAndPartnershipsTGEPool;
    uint256 public marketingTGEPool;
    uint256 public reserveFundsTGEPool;

    //tokens that can be vested.
    uint256 public advisersAndPartnershipsVestingPool;
    uint256 public marketingVestingPool;
    uint256 public reserveFundsVestingPool;

    //total tokens each division has
    uint256 public vestingSchedulesTotalAmountforAdvisorsAndPartnership;
    uint256 public vestingSchedulesTotalAmountforMarketing;
    uint256 public vestingSchedulesTotalAmountforReserveFunds;

    //tracking TGE pool
    uint256 public advisersAndPartnershipsTGEBank;
    uint256 public marketingTGEBank;
    uint256 public reserveFundsTGEBank;

    //tracking beneficiary count
    uint256 public advisersAndPartnershipsBeneficiariesCount = 0;
    uint256 public marketingBeneficiariesCount = 0;
    uint256 public reserveFundsBeneficiariesCount = 0;

    mapping(address => uint256) private holdersVestingCount;

    mapping(bytes32 => VestingSchedule)
        private vestingSchedulesforAdvisorsAndPartnership;
    mapping(bytes32 => VestingSchedule) private vestingSchedulesforMarketing;
    mapping(bytes32 => VestingSchedule) private vestingSchedulesforReserveFunds;

    //keeping track of beneficiary
    mapping(address => bool) private advisersAndPartnershipsBeneficiaries;
    mapping(address => bool) private marketingBeneficiaries;
    mapping(address => bool) private reserveFundsBeneficiaries;

    bytes32[] private vestingSchedulesIds;

    enum Roles {
        AdvisersAndPartnerships,
        Marketing,
        ReserveFunds
    }

    struct VestingSchedule {
        bool initialized;
        address beneficiary;
        uint256 cliff;
        uint256 start;
        uint256 duration;
        uint256 slicePeriodSeconds;
        bool revocable;
        uint256 amountTotal;
        uint256 released;
        bool revoked;
    }
    IERC20 private _token;

    event Released(uint256 amount);
    event Revoked();

    constructor(address token_) {
        require(token_ != address(0x0));
        _token = IERC20(token_);
    }

    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId, Roles r) {
        if (r == Roles.AdvisersAndPartnerships) {
            require(
                vestingSchedulesforAdvisorsAndPartnership[vestingScheduleId]
                    .initialized == true
            );
        } else if (r == Roles.Marketing) {
            require(
                vestingSchedulesforMarketing[vestingScheduleId].initialized ==
                    true
            );
        } else {
            require(
                vestingSchedulesforReserveFunds[vestingScheduleId]
                    .initialized == true
            );
        }
        _;
    }

    modifier onlyIfVestingScheduleNotRevoked(
        bytes32 vestingScheduleId,
        Roles r
    ) {
        if (r == Roles.AdvisersAndPartnerships) {
            require(
                vestingSchedulesforAdvisorsAndPartnership[vestingScheduleId]
                    .initialized == true
            );
            require(
                vestingSchedulesforAdvisorsAndPartnership[vestingScheduleId]
                    .revoked == false
            );
        } else if (r == Roles.Marketing) {
            require(
                vestingSchedulesforMarketing[vestingScheduleId].initialized ==
                    true
            );
            require(
                vestingSchedulesforMarketing[vestingScheduleId].revoked == false
            );
        } else {
            require(
                vestingSchedulesforReserveFunds[vestingScheduleId]
                    .initialized == true
            );
            require(
                vestingSchedulesforReserveFunds[vestingScheduleId].revoked ==
                    false
            );
        }
        _;
    }

    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function updateTotalSupply() internal onlyOwner {
        totalTokensinContract = _token.balanceOf(address(this));
    }

    function updateTotalWithdrawableAmount() internal onlyOwner {
        uint256 reservedAmount = vestingSchedulesTotalAmountforAdvisorsAndPartnership +
                vestingSchedulesTotalAmountforMarketing +
                vestingSchedulesTotalAmountforReserveFunds;
        totalWithdrawableAmount = _token.balanceOf(address(this)).sub(
            reservedAmount
        );
    }

    function addBeneficiary(address _address, Roles r) internal onlyOwner {
        if (r == Roles.AdvisersAndPartnerships) {
            advisersAndPartnershipsBeneficiariesCount++;
            advisersAndPartnershipsBeneficiaries[_address] = true;
        } else if (r == Roles.Marketing) {
            marketingBeneficiariesCount++;
            marketingBeneficiaries[_address] = true;
        } else {
            reserveFundsBeneficiariesCount++;
            reserveFundsBeneficiaries[_address] = true;
        }
    }

    function conditionWhileCreatingSchedule(
        Roles r,
        address _beneficiary,
        uint256 _cliff,
        uint256 _start,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revocable,
        uint256 _amount,
        bytes32 vestingScheduleId
    ) internal {
        if (r == Roles.AdvisersAndPartnerships) {
            vestingSchedulesforAdvisorsAndPartnership[
                vestingScheduleId
            ] = VestingSchedule(
                true,
                _beneficiary,
                _cliff,
                _start,
                _duration,
                _slicePeriodSeconds,
                _revocable,
                _amount,
                0,
                false
            );
            vestingSchedulesTotalAmountforAdvisorsAndPartnership = vestingSchedulesTotalAmountforAdvisorsAndPartnership;
        } else if (r == Roles.Marketing) {
            vestingSchedulesforMarketing[vestingScheduleId] = VestingSchedule(
                true,
                _beneficiary,
                _cliff,
                _start,
                _duration,
                _slicePeriodSeconds,
                _revocable,
                _amount,
                0,
                false
            );
            vestingSchedulesTotalAmountforMarketing = vestingSchedulesTotalAmountforMarketing;
        } else {
            vestingSchedulesforReserveFunds[
                vestingScheduleId
            ] = VestingSchedule(
                true,
                _beneficiary,
                _cliff,
                _start,
                _duration,
                _slicePeriodSeconds,
                _revocable,
                _amount,
                0,
                false
            );
            vestingSchedulesTotalAmountforReserveFunds = vestingSchedulesTotalAmountforReserveFunds;
        }
    }

    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
        internal
        view
        returns (uint256)
    {
        uint256 currentTime = getCurrentTime();
        if (
            (currentTime < vestingSchedule.cliff) ||
            vestingSchedule.revoked == true
        ) {
            return 0;
        } else if (
            currentTime >= vestingSchedule.start.add(vestingSchedule.duration)
        ) {
            return vestingSchedule.amountTotal.sub(vestingSchedule.released);
        } else {
            uint256 timeFromStart = currentTime.sub(vestingSchedule.start);
            uint256 secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart.div(secondsPerSlice);
            uint256 vestedSeconds = vestedSlicePeriods.mul(secondsPerSlice);
            uint256 vestedAmount = vestingSchedule
                .amountTotal
                .mul(vestedSeconds)
                .div(vestingSchedule.duration);
            vestedAmount = vestedAmount.sub(vestingSchedule.released);
            return vestedAmount;
        }
    }

    receive() external payable {}

    fallback() external payable {}

    function getVestingSchedulesCountByBeneficiary(address _beneficiary)
        external
        view
        returns (uint256)
    {
        return holdersVestingCount[_beneficiary];
    }

    function getVestingIdAtIndex(uint256 index)
        external
        view
        returns (bytes32)
    {
        require(
            index < getVestingSchedulesCount(),
            "TokenVesting: index out of bounds"
        );
        return vestingSchedulesIds[index];
    }

    function getVestingScheduleByAddressAndIndex(
        address holder,
        uint256 index,
        Roles r
    ) external view returns (VestingSchedule memory) {
        return
            getVestingSchedule(
                computeVestingScheduleIdForAddressAndIndex(holder, index),
                r
            );
    }

    function getVestingSchedulesTotalAmount(Roles r)
        external
        view
        returns (uint256)
    {
        if (r == Roles.AdvisersAndPartnerships) {
            return vestingSchedulesTotalAmountforAdvisorsAndPartnership;
        } else if (r == Roles.Marketing) {
            return vestingSchedulesTotalAmountforMarketing;
        } else {
            return vestingSchedulesTotalAmountforReserveFunds;
        }
    }

    function getToken() external view returns (address) {
        return address(_token);
    }

    function createVestingSchedule(
        Roles r,
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revocable,
        uint256 _amount
    ) public onlyOwner {
        require(
            this.getWithdrawableAmount() >= _amount,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        uint256 cliff = _start.add(_cliff);

        require(_duration > 0, "TokenVesting: duration must be > 0");
        require(_amount > 0, "TokenVesting: amount must be > 0");
        require(
            _slicePeriodSeconds >= 1,
            "TokenVesting: slicePeriodSeconds must be >= 1"
        );
        require(
            r == Roles.AdvisersAndPartnerships ||
                r == Roles.Marketing ||
                r == Roles.ReserveFunds,
            "TokenVesting: roles must me 0, 1 or 2"
        );

        bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(
            _beneficiary
        );
        conditionWhileCreatingSchedule(
            r,
            _beneficiary,
            cliff,
            _start,
            _duration,
            _slicePeriodSeconds,
            _revocable,
            _amount,
            vestingScheduleId
        );
        addBeneficiary(_beneficiary, r);
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount.add(1);
    }

    function getVestingSchedule(bytes32 vestingScheduleId, Roles r)
        public
        view
        returns (VestingSchedule memory)
    {
        if (r == Roles.AdvisersAndPartnerships) {
            return vestingSchedulesforAdvisorsAndPartnership[vestingScheduleId];
        } else if (r == Roles.Marketing) {
            return vestingSchedulesforMarketing[vestingScheduleId];
        } else {
            return vestingSchedulesforReserveFunds[vestingScheduleId];
        }
    }

    function computeVestingScheduleIdForAddressAndIndex(
        address holder,
        uint256 index
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    function revoke(bytes32 vestingScheduleId, Roles r)
        public
        onlyOwner
        onlyIfVestingScheduleNotRevoked(vestingScheduleId, r)
    {
        if (r == Roles.AdvisersAndPartnerships) {
            VestingSchedule
                storage vestingSchedule = vestingSchedulesforAdvisorsAndPartnership[
                    vestingScheduleId
                ];
            require(
                vestingSchedule.revocable == true,
                "TokenVesting: vesting is not revocable"
            );
            uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
            if (vestedAmount > 0) {
                release(vestingScheduleId, vestedAmount, r);
            }
            uint256 unreleased = vestingSchedule.amountTotal.sub(
                vestingSchedule.released
            );
            vestingSchedulesTotalAmountforAdvisorsAndPartnership = vestingSchedulesTotalAmountforAdvisorsAndPartnership
                .sub(unreleased);
            vestingSchedule.revoked = true;
        } else if (r == Roles.Marketing) {
            VestingSchedule
                storage vestingSchedule = vestingSchedulesforMarketing[
                    vestingScheduleId
                ];
            require(
                vestingSchedule.revocable == true,
                "TokenVesting: vesting is not revocable"
            );
            uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
            if (vestedAmount > 0) {
                release(vestingScheduleId, vestedAmount, r);
            }
            uint256 unreleased = vestingSchedule.amountTotal.sub(
                vestingSchedule.released
            );
            vestingSchedulesTotalAmountforMarketing = vestingSchedulesTotalAmountforMarketing
                .sub(unreleased);
            vestingSchedule.revoked = true;
        } else {
            VestingSchedule
                storage vestingSchedule = vestingSchedulesforReserveFunds[
                    vestingScheduleId
                ];
            require(
                vestingSchedule.revocable == true,
                "TokenVesting: vesting is not revocable"
            );
            uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
            if (vestedAmount > 0) {
                release(vestingScheduleId, vestedAmount, r);
            }
            uint256 unreleased = vestingSchedule.amountTotal.sub(
                vestingSchedule.released
            );
            vestingSchedulesTotalAmountforReserveFunds = vestingSchedulesTotalAmountforReserveFunds
                .sub(unreleased);
            vestingSchedule.revoked = true;
        }
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(
            this.getWithdrawableAmount() >= amount,
            "TokenVesting: not enough withdrawable funds"
        );
        totalWithdrawableAmount = totalWithdrawableAmount.sub(amount);
        _token.safeTransfer(owner(), amount);
    }

    function release(
        bytes32 vestingScheduleId,
        uint256 amount,
        Roles r
    ) public onlyIfVestingScheduleNotRevoked(vestingScheduleId, r) {
        VestingSchedule storage vestingSchedule;
        if (r == Roles.AdvisersAndPartnerships) {
            vestingSchedule = vestingSchedulesforAdvisorsAndPartnership[
                vestingScheduleId
            ];
        } else if (r == Roles.Marketing) {
            vestingSchedule = vestingSchedulesforMarketing[vestingScheduleId];
        } else {
            vestingSchedule = vestingSchedulesforReserveFunds[
                vestingScheduleId
            ];
        }
        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isOwner = msg.sender == owner();
        require(
            isBeneficiary || isOwner,
            "TokenVesting: only beneficiary and owner can release vested tokens"
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(
            vestedAmount >= amount,
            "TokenVesting: cannot release tokens, not enough vested tokens"
        );
        vestingSchedule.released = vestingSchedule.released.add(amount);
        address payable beneficiaryPayable = payable(
            vestingSchedule.beneficiary
        );
        if (r == Roles.AdvisersAndPartnerships) {
            vestingSchedulesTotalAmountforAdvisorsAndPartnership = vestingSchedulesTotalAmountforAdvisorsAndPartnership
                .sub(amount);
        } else if (r == Roles.Marketing) {
            vestingSchedulesTotalAmountforMarketing = vestingSchedulesTotalAmountforMarketing
                .sub(amount);
        } else {
            vestingSchedulesTotalAmountforReserveFunds = vestingSchedulesTotalAmountforReserveFunds
                .sub(amount);
        }

        _token.safeTransfer(beneficiaryPayable, amount);
    }

    function getVestingSchedulesCount() public view returns (uint256) {
        return vestingSchedulesIds.length;
    }

    function computeReleasableAmount(bytes32 vestingScheduleId, Roles r)
        public
        view
        onlyIfVestingScheduleNotRevoked(vestingScheduleId, r)
        returns (uint256)
    {
        VestingSchedule storage vestingSchedule;
        if (r == Roles.AdvisersAndPartnerships) {
            vestingSchedule = vestingSchedulesforAdvisorsAndPartnership[
                vestingScheduleId
            ];
        } else if (r == Roles.Marketing) {
            vestingSchedule = vestingSchedulesforMarketing[vestingScheduleId];
        } else {
            vestingSchedule = vestingSchedulesforReserveFunds[
                vestingScheduleId
            ];
        }
        return _computeReleasableAmount(vestingSchedule);
    }

    function getWithdrawableAmount() public view returns (uint256) {
        return totalWithdrawableAmount;
    }

    /**
     * @dev Computes the next vesting schedule identifier for a given holder address.
     */
    function computeNextVestingScheduleIdForHolder(address holder)
        public
        view
        returns (bytes32)
    {
        return
            computeVestingScheduleIdForAddressAndIndex(
                holder,
                holdersVestingCount[holder]
            );
    }

    /**
     * @dev Returns the last vesting schedule for a given holder address.
     */
    function getLastVestingScheduleForHolder(address holder, Roles r)
        public
        view
        returns (VestingSchedule memory)
    {
        if (r == Roles.AdvisersAndPartnerships) {
            return
                vestingSchedulesforAdvisorsAndPartnership[
                    computeVestingScheduleIdForAddressAndIndex(
                        holder,
                        holdersVestingCount[holder] - 1
                    )
                ];
        } else if (r == Roles.Marketing) {
            return
                vestingSchedulesforMarketing[
                    computeVestingScheduleIdForAddressAndIndex(
                        holder,
                        holdersVestingCount[holder] - 1
                    )
                ];
        } else {
            return
                vestingSchedulesforReserveFunds[
                    computeVestingScheduleIdForAddressAndIndex(
                        holder,
                        holdersVestingCount[holder] - 1
                    )
                ];
        }
    }

    function withdrawFromTGEBank(Roles r, uint256 _amount) public {
        bool isOwner = msg.sender == owner();
        if (r == Roles.AdvisersAndPartnerships) {
            require(
                advisersAndPartnershipsBeneficiaries[msg.sender] == true ||
                    isOwner,
                "You're not a beneficiary"
            );
            require(
                _amount <=
                    advisersAndPartnershipsTGEBank.div(
                        advisersAndPartnershipsBeneficiariesCount
                    ),
                "You cannot withdraw this much"
            );
            advisersAndPartnershipsTGEBank = advisersAndPartnershipsTGEBank.sub(
                    _amount
                );
            _token.safeTransfer(msg.sender, _amount);
        } else if (r == Roles.Marketing) {
            require(
                marketingBeneficiaries[msg.sender] == true || isOwner,
                "You're not a beneficiary"
            );
            require(
                _amount <= marketingTGEBank.div(marketingBeneficiariesCount),
                "You cannot withdraw this much"
            );
            marketingTGEBank = marketingTGEBank.sub(_amount);
            _token.safeTransfer(msg.sender, _amount);
        } else {
            require(
                reserveFundsBeneficiaries[msg.sender] == true || isOwner,
                "You're not a beneficiary"
            );
            require(
                _amount <=
                    reserveFundsTGEBank.div(reserveFundsBeneficiariesCount),
                "You cannot withdraw this much"
            );
            reserveFundsTGEBank = reserveFundsTGEBank.sub(_amount);
            _token.safeTransfer(msg.sender, _amount);
        }
    }

    function setTGE(
        uint256 _TGEForAandP,
        uint256 _TGEForM,
        uint256 _TGEForR
    ) public onlyOwner {
        advisersAndPartnershipsTGE = _TGEForAandP;
        marketingTGE = _TGEForM;
        reserveFundsTGE = _TGEForR;
    }

    function calculatePools() public onlyOwner {
        updateTotalSupply();
        vestingSchedulesTotalAmountforAdvisorsAndPartnership = totalTokensinContract
            .mul(10)
            .div(100);
        vestingSchedulesTotalAmountforMarketing = totalTokensinContract
            .mul(6)
            .div(100);
        vestingSchedulesTotalAmountforReserveFunds = totalTokensinContract
            .mul(4)
            .div(100);

        advisersAndPartnershipsTGEPool = vestingSchedulesTotalAmountforAdvisorsAndPartnership
            .mul(advisersAndPartnershipsTGE)
            .div(100);
        marketingTGEPool = vestingSchedulesTotalAmountforMarketing
            .mul(marketingTGE)
            .div(100);
        reserveFundsTGEPool = vestingSchedulesTotalAmountforReserveFunds
            .mul(reserveFundsTGE)
            .div(100);

        advisersAndPartnershipsTGEBank = advisersAndPartnershipsTGEPool;
        marketingTGEBank = marketingTGEPool;
        reserveFundsTGEBank = reserveFundsTGEPool;

        advisersAndPartnershipsVestingPool = vestingSchedulesTotalAmountforAdvisorsAndPartnership
            .sub(advisersAndPartnershipsTGEPool);
        marketingVestingPool = vestingSchedulesTotalAmountforMarketing.sub(
            marketingTGEPool
        );
        reserveFundsVestingPool = vestingSchedulesTotalAmountforReserveFunds
            .sub(reserveFundsTGEPool);

        updateTotalWithdrawableAmount();
    }
}
