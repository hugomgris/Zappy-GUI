#include "Behavior.hpp"
#include "../helpers/Logger.hpp"

#include <limits>

static const LevelReq& levelReq(int level) {
	static const LevelReq table[7] = {
		{ 1, { 0, 1, 0, 0, 0, 0, 0 } },
		{ 2, { 0, 1, 1, 1, 0, 0, 0 } },
		{ 2, { 0, 2, 0, 1, 0, 2, 0 } },
		{ 4, { 0, 1, 1, 2, 0, 1, 0 } }, 
		{ 4, { 0, 1, 2, 1, 3, 0, 0 } },
		{ 6, { 0, 1, 2, 3, 0, 1, 0 } }, 
		{ 6, { 0, 2, 2, 2, 2, 2, 1 } },
	};

	if (level < 1 || level > 7)
		return table[0];
	return table[level - 1];
}

static const std::vector<std::string> STONE_PRIORITY = {
	"thystame", "phiras", "mendiane", "sibur", "deraumere", "linemate"
};

static int foodRallyForLevel(int level) {
    static const int table[7] = {
        16,
        24,
        24,
        32,
        32,
        40,
        40,
    };
    if (level < 1 || level > 7) return 24;
    return table[level - 1];
}

static int foodFollowForLevel(int level) {
    static const int table[7] = {
        10,
        10,
        12,
        16,
        16,
        20,
        20,
    };
    if (level < 1 || level > 7) return 24;
    return table[level - 1];
}

Behavior::Behavior(Sender& sender, WorldState& state) : _sender(sender), _state(state) {}

void Behavior::disbandRally(bool wasLeader) {
	_stonesReady			= false;
	_claimSent				= false;
	_hereSent				= false;
	_isLeader				= false;
	_isMovingToRally		= false;
	_isRallying				= false;
	_peerConfirmedCount		= 0;
	_broadcastDirection		= -1;
	_waitingForBroadcast = false;
	_rallyLevel				= 0;
	_rallyBroadcastCount	= 0;
	_lastMovingToRallyVisionMs = 0;
	_waitingForBroadcast       = false;
	_movingToRallyTimeoutMs = 0;
	clearNavPlan();

	if (wasLeader) {
		_sender.sendDisbandLeader();
		_sender.expect("disband_leader", [this](const ServerMessage&) {
			_commandInFlight = false;
			_ignoreDone = false;
		});
		
		_ignoreDone = true; 

		_sender.sendBroadcast("DONE:" + std::to_string(_state.player.level));
		_sender.expect("broadcast", [](const ServerMessage&) {});

		_commandInFlight = true;

		Logger::info("Client with level " + std::to_string(_state.player.level) + " disbanded as LEADER");
	}


    if (!wasLeader) {
        _broadcastDirection = -1;
		setVisionStale();

		Logger::info("Client with level " + std::to_string(_state.player.level) + " disbanded as FOLLOWER");
    }
}

void Behavior::executeNavCmd(NavCmd cmd) {
	_commandInFlight = true;

	switch (cmd) {
		case NavCmd::Forward:
			_sender.sendAvance();
			_sender.expect("avance", [this](const ServerMessage& msg) {
				_commandInFlight = false;
				if (msg.isOk()) {
					switch (_state.player.orientation) {
						case Orientation::N: _state.player.y--; break;
						case Orientation::E: _state.player.x++; break;
						case Orientation::S: _state.player.y++; break;
						case Orientation::W: _state.player.x--; break;
						default: break;
					}

					_state.player.x = ((_state.player.x % _state.mapWidth)  + _state.mapWidth)  % _state.mapWidth;
                    _state.player.y = ((_state.player.y % _state.mapHeight) + _state.mapHeight) % _state.mapHeight;

					Logger::info("Client executed FORWARD while in state [" +
								std::to_string(static_cast<int>(_aiState)) + "] and is now at position x=" +
								std::to_string(_state.player.x) + ", y=" + std::to_string(_state.player.y) +
								"with orientation [" + std::to_string(static_cast<int>(_state.player.orientation)) + "]");

					setVisionStale();
				} else {
					clearNavPlan();
					setVisionStale();
				}
			});
			break;

		case NavCmd::TurnLeft:
			_sender.sendGauche();
			_sender.expect("gauche", [this](const ServerMessage& msg) {
				_commandInFlight = false;
				if (msg.isOk()) {
					switch (_state.player.orientation) {
						case Orientation::N: _state.player.orientation = Orientation::W; break;
						case Orientation::E: _state.player.orientation = Orientation::N; break;
						case Orientation::S: _state.player.orientation = Orientation::E; break;
						case Orientation::W: _state.player.orientation = Orientation::S; break;
						default: break;
					}

					Logger::info("Client executed GAUCHE while in state [" +
								std::to_string(static_cast<int>(_aiState)) + "] and is now at position x=" +
								std::to_string(_state.player.x) + ", y=" + std::to_string(_state.player.y) +
								"with orientation [" + std::to_string(static_cast<int>(_state.player.orientation)) + "]");

					setVisionStale();
				} else {
					clearNavPlan();
					setVisionStale();
				}
			});
			break;

		case NavCmd::TurnRight:
			_sender.sendDroite();
			_sender.expect("droite", [this](const ServerMessage& msg) {
				_commandInFlight = false;
				if (msg.isOk()) {
					switch (_state.player.orientation) {
						case Orientation::N: _state.player.orientation = Orientation::E; break;
						case Orientation::E: _state.player.orientation = Orientation::S; break;
						case Orientation::S: _state.player.orientation = Orientation::W; break;
						case Orientation::W: _state.player.orientation = Orientation::N; break;
						default: break;
					}

					Logger::info("Client executed DROITE while in state [" +
								std::to_string(static_cast<int>(_aiState)) + "] and is now at position x=" +
								std::to_string(_state.player.x) + ", y=" + std::to_string(_state.player.y) +
								"with orientation [" + std::to_string(static_cast<int>(_state.player.orientation)) + "]");

					setVisionStale();
				} else {
					clearNavPlan();
					setVisionStale();
				}
			});
			break;
	}
}

void Behavior::tick(int64_t nowMs) {
	if (hasCommandInFlight()) return;

	if (nowMs - _lastInventoryRefreshMs > 5000) {
		_lastInventoryRefreshMs = nowMs;
		if (!isInventoryStale() && !hasCommandInFlight()) {
			refreshInventory();
			return;
		}
	}

	if (_aiState == AIState::MovingToRally) {

		// If the nav plan just emptied we may be on the leader's tile — refresh immediately
		bool navJustDrained = _navPlan.empty() && _waitingForBroadcast;
		if (isVisionStale() && (navJustDrained || nowMs - _lastMovingToRallyVisionMs > 2000)) {
			_lastMovingToRallyVisionMs = nowMs;
			refreshVision();
			return;
		}
	} else {
		if (isVisionStale()) { refreshVision(); return; }
	}

	if (isInventoryStale()) { refreshInventory(); return; }

	switch (_aiState) {
		case AIState::CollectFood:      tickCollectFood();           break;
		case AIState::CollectStones:    tickCollectStones();         break;
		case AIState::Idle:             tickIdle();                  break;
		case AIState::Incantating:      tickIncantating();           break;
		case AIState::ClaimingLeader:   tickClaimingLeader();        break;
		case AIState::Leading:          tickLeading(nowMs);          break;
		case AIState::MovingToRally:    tickMovingToRally(nowMs);    break;
		case AIState::Rallying:         tickRallying(nowMs);         break;
	}
}

// refreshers
void Behavior::refreshVision() {
	if (_commandInFlight) return; 

	_commandInFlight = true;
	_sender.sendVoir();
	_sender.expect("voir", [this](const ServerMessage& msg) {
		_commandInFlight = false;
		if (msg.vision.has_value()) {
			_state.vision = msg.vision.value();
			_staleVision = false;

			Logger::info("Refreshed vision in state [" + std::to_string(static_cast<int>(_aiState)) + "] at x=" + std::to_string(_state.player.x) + ", y=" + std::to_string(_state.player.y) + ": " + msg.raw);

			if (!_navPlan.empty() && !_navTarget.empty() &&
				!_state.visionHasItem(_navTarget)) {
				Logger::debug("Behavior: target '" + _navTarget +
					"' no longer visible, clearing nav plan");
				clearNavPlan();
			}
		} else if (msg.isKo()) {
			Logger::warn("Voir failed");
		}
	});
}

void Behavior::refreshInventory() {
	if (_commandInFlight) return;

	_commandInFlight = true;
	_sender.sendInventaire();
	_sender.expect("inventaire", [this](const ServerMessage& msg) {
		_commandInFlight = false;
		if (msg.inventory.has_value()) {
			Logger::info("Refreshed inventory in state [" + std::to_string(static_cast<int>(_aiState)) + "] at x=" + std::to_string(_state.player.x) + ", y=" + std::to_string(_state.player.y) + ": " + msg.raw);
			_state.player.inventory = msg.inventory.value();
			_staleInventory = false;
		} else if (msg.isKo()) {
			Logger::warn("Inventaire failed");
		}
	});
}

void Behavior::tickCollectFood() {
	if (_state.player.food() <= 1) {
		if (isVisionStale()) {
			refreshVision();
			return;
		}
		
		if (_state.countItemOnCurrentTile("nourriture") > 0) {
			clearNavPlan();
			_commandInFlight = true;
			_sender.sendPrend("nourriture");
			_sender.expect("prend nourriture", [this](const ServerMessage& msg) {
				_commandInFlight = false;
				if (msg.isOk()) {
					_state.player.inventory.nourriture++;
					setInventoryStale();
					Logger::info("Emergency food pickup successful! Food now: " + 
								std::to_string(_state.player.food()));
				} else {
					Logger::error("Emergency food pickup FAILED!");
				}
				setVisionStale();
			});
			return;
		}
		
		if (_state.visionHasItem("nourriture")) {
			auto tile = _state.nearestTileWithItem("nourriture");
			if (tile.has_value()) {
				if (_navPlan.empty()) {
					auto plan = Navigator::planPath(_state.player.orientation, tile->localX, tile->localY);
					_navPlan.assign(plan.begin(), plan.end());
				}
				if (!_navPlan.empty()) {
					NavCmd next = _navPlan.front(); _navPlan.pop_front();
					executeNavCmd(next);
				}
				return;
			}
		}

		Logger::error("CRITICAL: Food = " + std::to_string(_state.player.food()) +
					" but no food visible! Moving randomly!");
		if (_navPlan.empty()) {
			auto plan = Navigator::explorationStep(_explorationStep);
			_navPlan.assign(plan.begin(), plan.end());
		}
		if (!_navPlan.empty()) {
			NavCmd next = _navPlan.front(); _navPlan.pop_front();
			executeNavCmd(next);
		}
		return;
	}
	
	int foodTarget = (_stonesReady) ? foodRallyForLevel(_state.player.level) : FOOD_SAFE;
	if (_state.player.inventory.nourriture >= foodTarget) {
		_stonesReady = false;
		_aiState = AIState::CollectStones;
		clearNavPlan();
		return;
	}

	if (_state.countItemOnCurrentTile("nourriture")) {
		Logger::info("Found food on current tile! Picking up. Food in inventory: " + 
				std::to_string(_state.player.inventory.nourriture));
		clearNavPlan();
		_commandInFlight = true;
		_sender.sendPrend("nourriture");
		_sender.expect("prend nourriture", [this](const ServerMessage& msg) {
			_commandInFlight = false;
			if (msg.isOk()) {
				_state.player.inventory.nourriture++;
				setInventoryStale();
			}
			setVisionStale();
		});
		return;
	} else {
		if (!_state.vision.empty()) {
			std::string items;
			for (const auto& item : _state.vision[0].items) {
				items += item + " ";
			}
			Logger::info("Current tile has: " + items + " Food count: " + 
						std::to_string(_state.countItemOnCurrentTile("nourriture")));
		}
	}

	if (_state.visionHasItem("nourriture")) {
		if (_navPlan.empty() || _navTarget != "nourriture") {
			clearNavPlan();
			auto tile = _state.nearestTileWithItem("nourriture");
			if (!tile.has_value()) {
				setVisionStale();
				return;
			}
			auto& t = tile.value();
			auto plan = Navigator::planPath(_state.player.orientation, t.localX, t.localY);
			_navPlan.assign(plan.begin(), plan.end());
			_navTarget = "nourriture";
		}
		if (!_navPlan.empty()) {
			NavCmd next = _navPlan.front(); _navPlan.pop_front();
			executeNavCmd(next);
		}
		return;
	}

	if (_navPlan.empty()) {
		auto plan = Navigator::explorationStep(_explorationStep);
		_navPlan.assign(plan.begin(), plan.end());
		_navTarget.clear();
	}
	if (!_navPlan.empty()) {
		NavCmd next = _navPlan.front(); _navPlan.pop_front();
		executeNavCmd(next);
	}
}

void Behavior::tickCollectStones() {
	if (_state.player.food() < FOOD_CRITICAL) {
		_aiState = AIState::CollectFood;
		clearNavPlan();
		return;
	}

	if (_state.player.food() > FOOD_FORK && _state.player.level >= 2 && _state.forkEnabled) {
		Logger::info("Fork call triggered");
		_aiState = AIState::CollectStones;
		clearNavPlan();
		_commandInFlight = true;
		_sender.sendFork();
		_sender.expect("fork", [this](const ServerMessage& msg) {
			(void)msg;
			_aiState = AIState::CollectStones;
			setVisionStale();
			setInventoryStale();
			_forkInProgress = false;
			_commandInFlight = false;
		});
		_forkInProgress = true;
		return;
	}

	computeMissingStones();

	if (_stonesNeeded.empty()) {
		const LevelReq& req = levelReq(_state.player.level);
		if (!_easyMode && req.players > 1) {
			if (_state.player.food() < foodRallyForLevel(_state.player.level)) {
				Logger::info("Behavior: stones ready but food too low (" +
					std::to_string(_state.player.food()) +
					"), collecting food before rally");
				_stonesReady = true;
				_aiState = AIState::CollectFood;
				return;
			}
			Logger::info("Behavior: all stones ready for level " +
				std::to_string(_state.player.level) +
				" (needs " + std::to_string(req.players) +
				" players) — claiming leadership");
			_aiState = AIState::ClaimingLeader;
			clearNavPlan();
		} else {
			_aiState = AIState::Incantating;
			_incantationReady = false;
			clearNavPlan();
		}
		return;
	}

	for (const auto& stone : _stonesNeeded) {
		if (_state.countItemOnCurrentTile(stone)) {
			clearNavPlan();
			_commandInFlight = true;
			_sender.sendPrend(stone);
			_sender.expect("prend " + stone, [this](const ServerMessage& msg) {
				_commandInFlight = false;
				if (msg.isOk()) setInventoryStale();
				setVisionStale();
			});
			return;
		}
	}

	if (_state.player.food() < FOOD_SAFE && _state.countItemOnCurrentTile("nourriture")) {
		_commandInFlight = true;
		_sender.sendPrend("nourriture");
		_sender.expect("prend nourriture", [this](const ServerMessage& msg) {
			_commandInFlight = false;
			if (msg.isOk()) {
				_state.player.inventory.nourriture++;
				setInventoryStale();
			}
			setVisionStale();
		});
		return;
	}

	if (_state.player.food() < FOOD_SAFE && _state.visionHasItem("nourriture")) {
		clearNavPlan();
		auto tile = _state.nearestTileWithItem("nourriture");
		if (tile.has_value()) {
			auto plan = Navigator::planPath(_state.player.orientation, tile->localX, tile->localY);
			_navPlan.assign(plan.begin(), plan.end());
			_navTarget = "nourriture";
			if (!_navPlan.empty()) {
				NavCmd next = _navPlan.front(); _navPlan.pop_front();
				executeNavCmd(next);
			}
			return;
		}
	}

	std::string previousTarget = _navTarget;
	auto tile = getNearestTileWithNeededResource();

	if (tile.localX == std::numeric_limits<int>::max()) {
		if (_navPlan.empty()) {
			auto plan = Navigator::explorationStep(_explorationStep);
			_navPlan.assign(plan.begin(), plan.end());
			_navTarget.clear();
		}
	} else if (_navPlan.empty() || _navTarget != previousTarget) {
		auto plan = Navigator::planPath(_state.player.orientation, tile.localX, tile.localY);
		Logger::debug("Behavior: CollectStones: planned " + std::to_string(plan.size()) +
			" steps to " + _navTarget + " at (" +
			std::to_string(tile.localX) + "," + std::to_string(tile.localY) + ")");
		_navPlan.assign(plan.begin(), plan.end());
	}

	if (!_navPlan.empty()) {
		NavCmd next = _navPlan.front(); _navPlan.pop_front();
		executeNavCmd(next);
	}
}

void Behavior::tickIdle() {
	if (_forkInProgress) return;
	_aiState = AIState::CollectStones;
}

void Behavior::tickClaimingLeader() {
	if (_claimSent) return;

	_claimSent = true;
	_commandInFlight = true;

	Logger::info("Behavior: sending claim_leader for level " +
		std::to_string(_state.player.level));

	_sender.sendClaimLeader();
	_sender.expect("claim_leader", [this](const ServerMessage& msg) {
		_commandInFlight = false;
		_claimSent = false;

		if (msg.isOk()) {
			Logger::info("Behavior: claim_leader OK — entering Leading");
			_isLeader             = true;
			_rallyLevel           = _state.player.level;
			_peerConfirmedCount   = 0;
			_lastRallyBroadcastMs = 0;
			_leadingTimeoutMs     = 0;
			_aiState = AIState::Leading;

		} else {
			Logger::info("Behavior: claim_leader KO — entering MovingToRally as follower");
			_isLeader = false;
			_isMovingToRally = false;
			if (_broadcastDirection < 0)
				_broadcastDirection = -1;
			
			if (_broadcastDirection == 0)
				_aiState = AIState::Rallying;   // already there, skip MovingToRally
			else
				_aiState = AIState::MovingToRally;
		}
	});
}

void Behavior::tickLeading(int64_t nowMs) {
	if (_leadingTimeoutMs == 0) {
		_leadingTimeoutMs     = nowMs;
		_lastRallyBroadcastMs = nowMs - 600;
		_rallyBroadcastCount  = 0;
		Logger::info("Behavior: Leading - level " + std::to_string(_state.player.level));
	}

	if (nowMs - _leadingTimeoutMs >= 30000) {
		Logger::warn("Behavior: Leading timed out — disbanding");
		disbandRally(true);
		_aiState = AIState::CollectStones;
		return;
	}

	if (_state.player.food() < FOOD_CRITICAL) {
		Logger::warn("Behavior: Leading - food critical, disbanding");
		disbandRally(true);
		_aiState = AIState::CollectFood;
		return;
	}

	if (nowMs - _lastRallyBroadcastMs >= 500) {
		_lastRallyBroadcastMs = nowMs;
		_rallyBroadcastCount++;
		_commandInFlight = true;
		
		Logger::info("Leader sending RALLY broadcast from position x=" +
					std::to_string(_state.player.x) + ", y=" + std::to_string(_state.player.y));

		_sender.sendBroadcast("RALLY:" + std::to_string(_state.player.level));
		_sender.expect("broadcast", [this](const ServerMessage&) {
			_commandInFlight = false;
		});
		return;
	}

	if (_rallyBroadcastCount < 3) {
		return;
	}

	if (_state.vision.empty()) {
		setVisionStale();
		return;
	}
}

void Behavior::tickIncantating() {
	if (!_incantationReady) {
		setVisionStale();
		_incantationReady = true;
		return;
	}

	if (!_stonesPlaced) {
		if (_easyMode) {
			auto& tile = _state.vision[0];
			if (tile.countItem("linemate") < 1) {
				_commandInFlight = true;
				_sender.sendPose("linemate");
				_sender.expect("pose linemate", [this](const ServerMessage& msg) {
					_commandInFlight = false;
					if (msg.isOk()) {
						_state.player.inventory.linemate--;
						setInventoryStale();
					}
					setVisionStale();
				});
				return;
			}
		} else {
			auto requirements = levelReq(_state.player.level);
			auto& tile = _state.vision[0];

			#define TRY_POSE(stone_name) \
				if (requirements.stones.stone_name > 0 && \
					tile.countItem(#stone_name) < requirements.stones.stone_name) { \
					_commandInFlight = true; \
					_sender.sendPose(#stone_name); \
					_sender.expect("pose " #stone_name, [this](const ServerMessage& msg) { \
						_commandInFlight = false; \
						if (msg.isOk()) { \
							_state.player.inventory.stone_name--; \
							setInventoryStale(); \
						} \
						setVisionStale(); \
					}); \
					return; \
				}

			TRY_POSE(linemate)
			TRY_POSE(deraumere)
			TRY_POSE(sibur)
			TRY_POSE(mendiane)
			TRY_POSE(phiras)
			TRY_POSE(thystame)
			#undef TRY_POSE
		}

		_stonesPlaced = true;
		setVisionStale();
		return;
	}

	if (_staleVision) return;

	auto& tile = _state.vision[0];
	bool stonesOk;
	if (_easyMode) {
		stonesOk = tile.countItem("linemate") >= 1;
	} else {
		auto req = levelReq(_state.player.level);
		stonesOk =
			tile.countItem("linemate")  >= req.stones.linemate  &&
			tile.countItem("deraumere") >= req.stones.deraumere &&
			tile.countItem("sibur")     >= req.stones.sibur     &&
			tile.countItem("mendiane")  >= req.stones.mendiane  &&
			tile.countItem("phiras")    >= req.stones.phiras    &&
			tile.countItem("thystame")  >= req.stones.thystame;
	}

	if (!stonesOk) {
		Logger::warn("Behavior: stones missing after placement, back to CollectStones");
		_stonesPlaced = false;
		_incantationReady = false;
		_aiState = AIState::CollectStones;
		return;
	}

	_commandInFlight = true;
	_sender.sendIncantation();
	_sender.expect("incantation", [this](const ServerMessage& msg) {
		if (msg.isInProgress()) return;

		_commandInFlight = false;
		_stonesPlaced = false;
		_incantationReady = false;

		disbandRally(true);

		if (_pendingLevelUp) {
			_state.player.level++;
			Logger::info("Level up! Now level " + std::to_string(_state.player.level));
			_pendingLevelUp = false;
			_aiState = (_state.player.level >= 8) ? AIState::Idle : AIState::CollectStones;
		} else {
			Logger::warn("Incantation failed (ko/timeout), restarting stone collection");
			_aiState = AIState::CollectStones;
		}
	});
}

void Behavior::tickMovingToRally(int64_t nowMs) {
	if (_broadcastDirection == 0) {
		clearNavPlan();
		_commandInFlight = false;
		_isMovingToRally = false;
		_aiState = AIState::Rallying;
		return;
	}
	
	if (_shouldStopMoving) {
        _shouldStopMoving = false;
        if (_broadcastDirection == 0) {
            clearNavPlan();
            _isMovingToRally = false;
            _aiState = AIState::Rallying;
            return;
        }
    }
	
	// One-time init
    if (_movingToRallyTimeoutMs == 0) {
		_isMovingToRally = true;
		_movingToRallyTimeoutMs = nowMs;
		_navTarget.clear();
		clearNavPlan();
		return;
	}

    if (nowMs - _movingToRallyTimeoutMs >= 30000) {
        Logger::warn("Behavior: MovingToRally timed out");
        disbandRally(false);
        _aiState = AIState::CollectStones;
        return;
    }
	

    if (_state.player.food() < FOOD_CRITICAL) {
        Logger::warn("Behavior: MovingToRally — food critical, disbanding");
        disbandRally(false);
        _aiState = AIState::CollectFood;
        return;
    }
	

	if (_state.player.food() < FOOD_SAFE && _state.countItemOnCurrentTile("nourriture")) {
		_commandInFlight = true;
		_sender.sendPrend("nourriture");
		_sender.expect("prend nourriture", [this](const ServerMessage& msg) {
			_commandInFlight = false;
			if (msg.isOk()) _state.player.inventory.nourriture++;
			setVisionStale();
		});
		return;
	}

    if (_broadcastDirection == -1) {
        if (hasCommandInFlight()) return;

		auto plan = Navigator::explorationStep(_explorationStep);
		_navPlan.assign(plan.begin(), plan.end());
		if (!_navPlan.empty()) {
			NavCmd next = _navPlan.front(); _navPlan.pop_front();
			executeNavCmd(next);
		}
        
        return;
    }

	if (_broadcastDirection == 0) {
		clearNavPlan();
		_isMovingToRally = false;
		_aiState = AIState::Rallying;
		return;
	}

	if (_navPlan.empty() && _broadcastDirection != -1 && _broadcastDirection != 0) {
		if (_waitingForBroadcast) {
			// Consumed the last plan; don't re-plan until a fresh broadcast updates direction
			return;
		}
		auto plan = Navigator::planApproachDirection(_broadcastDirection, _state.player.orientation);
		_navPlan.assign(plan.begin(), plan.end());
		Logger::info("Built new approach plan with " + std::to_string(plan.size()) + " commands");
		_waitingForBroadcast = true;  // arm the gate; onBroadcast will clear it
	}
	
	if (!_navPlan.empty()) {
		NavCmd next = _navPlan.front();
		_navPlan.pop_front();
		executeNavCmd(next);
	}
}

void Behavior::tickRallying(int64_t nowMs) {
	if (!_isRallying) {
		Logger::info("cucufu1");
        _isRallying = true;
        _rallyingTimeoutMs = nowMs;
        setVisionStale();
        return;
    }

	if (_state.player.food() < FOOD_CRITICAL) {
		Logger::info("cucufu2");
		Logger::warn("Behavior: Rallying — food critical, disbanding");
		bool wasLeader = _isLeader;
		disbandRally(wasLeader);
		_aiState = AIState::CollectFood;
		return;
	}

	if (_incantationReady) {
		Logger::info("CUCUFUYYYYYYY");
		Logger::warn("LEADER going into INCANTATON state");
		_isRallying = false;
		_aiState = AIState::Incantating;
		_incantationReady = false;
		_stonesPlaced = false;
		_readyForIncantation = false;
		return;
	}

	if (_pendingLevelUp) {
		Logger::info("cucufu3");
		_pendingLevelUp = false;
		_state.player.level++;
		Logger::info("Behavior: Rallying level_up — now level " +
			std::to_string(_state.player.level));
		_sender.cancelAll();
		_commandInFlight = false;
		//disbandRally(true);
		disbandRally(_isLeader);
		_stonesPlaced = false;
		_incantationReady = false;
		_aiState = (_state.player.level >= 8) ? AIState::Idle : AIState::CollectStones;
		setInventoryStale();
		setVisionStale();
		return;
	}

	if (nowMs - _rallyingTimeoutMs >= 30000) {
		Logger::info("cucufu4");
		Logger::warn("Behavior: Rallying timed out");
		bool wasLeader = _isLeader;
		disbandRally(wasLeader);
		_aiState = AIState::CollectStones;
		return;
	}

	if (!_isLeader) {
		if (_broadcastDirection != 0) {
			Logger::info("cucufu5");
			_isRallying = false;
			_isMovingToRally = false;
			clearNavPlan();
			_aiState = AIState::MovingToRally;
			return;
		}
		Logger::info("cucufu6");
		return;
	}

	if (_state.vision.empty()) {
			Logger::info("cucufu7");
			setVisionStale();
			return;
		}

	const auto& req = levelReq(_state.player.level);
	if (_peerConfirmedCount >= req.players - 1) {
		if (!_incantationReady) {
			_incantationReady = true;
			_readyForIncantationTime = nowMs;
			Logger::info("All peers confirmed, waiting 2 seconds...");
		}
		if (nowMs - _readyForIncantationTime >= 2000) {
			Logger::info("Grace period ended, incantating");
			_aiState = AIState::Incantating;
			_incantationReady = false;
			_isRallying = false;
			return;
		}
	}
	/* if (_peerConfirmedCount < req.players - 1) {
		Logger::info("cucufu8");
		if (nowMs - _lastRallyBroadcastMs >= 500) {
			_lastRallyBroadcastMs = nowMs;
			_commandInFlight = true;
			_sender.sendBroadcast("RALLY:" + std::to_string(_state.player.level));
			_sender.expect("broadcast", [this](const ServerMessage&) {
				_commandInFlight = false;
			});
			return;
		}
	} else {
		_incantationReady = true;
	} */

	// Broadcast RALLY during grace period AND when still waiting for peers
	if (nowMs - _lastRallyBroadcastMs >= 500) {
		Logger::info("cucufu9");
		_lastRallyBroadcastMs = nowMs;
		_commandInFlight = true;
		_sender.sendBroadcast("RALLY:" + std::to_string(_state.player.level));
		_sender.expect("broadcast", [this](const ServerMessage&) {
			_commandInFlight = false;
		});
		return;
	}

	Logger::info("cucufuXXXX");

	setVisionStale();
}

void Behavior::onBroadcast(const ServerMessage& msg) {
	if (!msg.messageText.has_value()) return;
	const std::string& text = msg.messageText.value();
	int direction = msg.broadcastDirection.value_or(-1);

	if (text.empty()) return;

	Logger::debug("Behavior::onBroadcast: dir=" + std::to_string(direction) +
		" msg='" + text + "'");

	if (text.rfind("RALLY:", 0) == 0) {
		int level = 0;
		try { level = std::stoi(text.substr(6)); } catch (...) { return; }

		if (level != _state.player.level) return;

		if (_isLeader) return;

		int previousDirection = _broadcastDirection;
		
		if (direction == 0) {
			Logger::info("Behavior: ON LEADER'S TILE! (direction 0 from server)");
			_sender.cancelAll();
			_commandInFlight = false;
			clearNavPlan();
			_broadcastDirection = direction;
			_isMovingToRally = false;
			_isRallying = false;
			_aiState = AIState::Rallying;
			
			if (!_hereSent) {
				Logger::info("SENDING HERE");
				
				_hereSent = true;
				_sender.sendBroadcast("HERE:" + std::to_string(_state.player.level));
				_sender.expect("broadcast", [this](const ServerMessage&) {});
			}
			return;
		}
		
		_broadcastDirection = direction;
    	_broadcastReceivedFacing = _state.player.orientation;
		_waitingForBroadcast = false;  // fresh direction received, safe to plan again

		if (_aiState == AIState::MovingToRally && direction != previousDirection) {
			// Only discard the plan if it hasn't started executing yet (first command is a turn).
			// If the next command is Forward, the player just turned and needs that step —
			// dropping it leaves them rotated with no movement, causing drift.
			bool planStartsWithForward = !_navPlan.empty() &&
				_navPlan.front() == NavCmd::Forward;
			if (!planStartsWithForward) {
				clearNavPlan();
			}
		}

		if (_aiState == AIState::Incantating) {
			return;
		}

		if (_aiState == AIState::CollectFood && _state.player.food() < FOOD_CRITICAL * 2) {
			return;
		}

		if (_aiState == AIState::CollectFood || _aiState == AIState::CollectStones) {
			if (_state.player.food() >= foodFollowForLevel(_state.player.level)) {
				Logger::info("Responding to rally because enough food:" + std::to_string(_state.player.food()));
				_stonesReady = false;
				_sender.cancelAll();
				_commandInFlight = false; 
				clearNavPlan();
				
				Logger::info("Going to MovingToRally state at level " + std::to_string(_state.player.level) + " from position x=" + std::to_string(_state.player.x) +
							", y=" + std::to_string(_state.player.y) + " and orientation [" + 
							std::to_string(static_cast<int>(_state.player.orientation)) + "]");
				_isMovingToRally = false;
				_aiState = AIState::MovingToRally;
			} else {
				Logger::info("Received rally call when in state [" +
							std::to_string(static_cast<int>(_aiState)) +
							"] but NOT ENOUGH FOOD:" + std::to_string(_state.player.food()));
			}
			return;
		}

		if (_aiState == AIState::ClaimingLeader) {
			return;
		}

		if (_aiState != AIState::MovingToRally && _aiState != AIState::Rallying) {
			Logger::info("Behavior: RALLY dir=" + std::to_string(direction) +
						" → MovingToRally");
			_isMovingToRally = false;
			_isRallying = false;
			_aiState = AIState::MovingToRally;
		}
		
		return;
	}

	if (text.rfind("HERE:", 0) == 0) {
		int level = 0;
		try { level = std::stoi(text.substr(5)); } catch (...) { return; }

		if (!_isLeader || level != _state.player.level) return;
		if (_aiState == AIState::Incantating) return;

		const auto& req = levelReq(_state.player.level);
		int needed = req.players - 1;

		if (_peerConfirmedCount >= needed) return;

		_peerConfirmedCount++;
		Logger::info("Behavior: peer HERE (total=" + std::to_string(_peerConfirmedCount) + ")");

		if (_peerConfirmedCount >= needed) {
			Logger::info("Behavior: all peers confirmed → Rallying");
			_aiState = AIState::Rallying;
			_isRallying = false;
		}
		return;
	}

	if (text.rfind("DONE:", 0) == 0) {
		if (_isLeader) return;
		int level = 0;
		try { level = std::stoi(text.substr(5)); } catch (...) { return; }
		if (level != _state.player.level) return;

		_sender.cancelAll();
		_commandInFlight = false;

		if (_aiState == AIState::MovingToRally || _aiState == AIState::Rallying
			|| _broadcastDirection != -1 || _hereSent) {
			disbandRally(false);
			if (_aiState != AIState::CollectFood && _aiState != AIState::Incantating)
				_aiState = AIState::CollectStones;
		}
		return;
	}

	/* if (text.rfind("DONE:", 0) == 0) {
		Logger::info("DONE received at position x=" + std::to_string(_state.player.x) + 
					", y=" + std::to_string(_state.player.y));
		
		// Don't check _isLeader or _ignoreDone here - let the condition below handle it
		if (_isLeader) return;
		
		int level = 0;
		try { level = std::stoi(text.substr(5)); } catch (...) { return; }

		if (level != _state.player.level) return;

		// CRITICAL: Cancel any in-flight command immediately
		_sender.cancelAll();
		_commandInFlight = false;
		
		if (_aiState == AIState::MovingToRally || _aiState == AIState::Rallying) {
			Logger::info("Behavior: DONE received — disbanding, back to CollectStones");
			disbandRally(false);
			_aiState = AIState::CollectStones;
		}
		return;
	} */
}

// resource helpers
void Behavior::computeMissingStones() {
	if (_state.vision.empty()) return;

	_stonesNeeded.clear();

	if (_easyMode) {
		if (_state.player.inventory.linemate < 1)
			_stonesNeeded.push_back("linemate");
		return;
	}

	const LevelReq& req = levelReq(_state.player.level);
	Inventory& inv = _state.player.inventory;

	for (const auto& stone : STONE_PRIORITY) {
		if      (stone == "linemate"  && req.stones.linemate  > inv.linemate)  _stonesNeeded.push_back(stone);
		else if (stone == "deraumere" && req.stones.deraumere > inv.deraumere) _stonesNeeded.push_back(stone);
		else if (stone == "sibur"     && req.stones.sibur     > inv.sibur)     _stonesNeeded.push_back(stone);
		else if (stone == "mendiane"  && req.stones.mendiane  > inv.mendiane)  _stonesNeeded.push_back(stone);
		else if (stone == "phiras"    && req.stones.phiras    > inv.phiras)    _stonesNeeded.push_back(stone);
		else if (stone == "thystame"  && req.stones.thystame  > inv.thystame)  _stonesNeeded.push_back(stone);
	}
}

VisionTile Behavior::getNearestTileWithNeededResource() {
	VisionTile nearest;
	nearest.localX = std::numeric_limits<int>::max();
	nearest.localY = std::numeric_limits<int>::max();

	for (const auto& stone : _stonesNeeded) {
		auto tile = _state.nearestTileWithItem(stone);
		if (tile.has_value()) {
			nearest = tile.value();
			_navTarget = stone;
			return nearest;
		}
	}

	return nearest;
}