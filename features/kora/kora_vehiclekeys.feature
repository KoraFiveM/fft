@kora @kora_vehiclekeys
Feature: kora_vehiclekeys session keys, locks and ignition
  Virtual keys are held per server session and decide who may toggle a
  vehicle's lock (/togglelocks), run its engine (/engine,
  Config.RequireKeyToStart) or hand keys over (/givekeys). Keys are granted and
  read through the server exports; the lock state is asserted on the server
  from the entity state bag. Vehicle scenarios use a temporary client-spawned
  car on the Sandy Shores airfield (position unverified until a live run).

  Not covered: lockpick and hotwire success (rule 5: the minigame is never
  forced, and the lockpick event is only fired where the server or client
  refuses before authorising one), handing keys to another player (the tester
  is the only subject), admin /addkeys and /removekeys (permission gated),
  physical key items (Config.PhysicalKey.enabled is false), job vehicles
  (Config.JobVehicles is empty), bike guard, lock feedback sounds and lights.

  Background:
    Given resource "kora_vehiclekeys" is running

  @server
  Scenario: Keys are granted and revoked by plate
    Given I am given vehicle keys for plate "FFTKEY1"
    Then I should hold vehicle keys for plate "FFTKEY1"
    When my vehicle keys for plate "FFTKEY1" are taken away
    Then I should not hold vehicle keys for plate "FFTKEY1"

  @server
  Scenario: Plates are normalised before keys are compared
    Given I am given vehicle keys for plate " fftkey2 "
    Then I should hold vehicle keys for plate "FFTKEY2"
    And I should not hold vehicle keys for plate "FFTKEY3"

  @server @rejection
  Scenario: A blank plate is never given keys
    Then giving vehicle keys for an empty plate should be refused
    And I should not hold vehicle keys for plate "   "

  @world
  Scenario: Key holder locks and unlocks the vehicle
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    Then my client key check for the vehicle I am driving should say yes
    When I run the command "togglelocks"
    Then I should see a notification containing "Vehicle locked."
    And the vehicle I am driving should be locked by its keys
    When I run the command "togglelocks"
    Then I should see a notification containing "Vehicle unlocked."
    And the vehicle I am driving should not be locked by its keys

  @world @rejection
  Scenario: Lock toggle is refused without keys
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    Then my client key check for the vehicle I am driving should say no
    When I run the command "togglelocks"
    Then I should see a notification containing "You do not have the keys for this vehicle."
    And the vehicle I am driving should not be locked by its keys

  @world @rejection
  Scenario: Lock toggle finds no vehicle on an empty airfield
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    When I run the command "togglelocks"
    Then I should see a notification containing "No nearby networked vehicle."

  @world
  Scenario: Key holder switches the engine off and on again
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    And the engine of the vehicle I am driving is running
    When I run the command "engine"
    Then the engine of the vehicle I am driving should be off
    When I run the command "engine"
    Then the engine of the vehicle I am driving should be running

  @world @rejection
  Scenario: Engine does not run without keys
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    Then the engine of the vehicle I am driving should be off
    When I run the command "engine"
    Then the engine of the vehicle I am driving should stay off
    And I should still hold no keys of the vehicle I am driving

  @world @rejection
  Scenario: Keys cannot be handed over without holding them
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    When I run the command "givekeys"
    Then I should see a notification containing "You don't have keys to this vehicle."
    And I should still hold no keys of the vehicle I am driving

  @world @rejection
  Scenario: Keys are not handed over when nobody is nearby
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    When I run the command "givekeys"
    Then I should see a notification containing "There is nobody nearby to hand keys to"
    And I should still hold the keys of the vehicle I am driving

  @world @rejection
  Scenario: Lockpick is not needed for a vehicle whose keys I hold
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    Then my client key check for the vehicle I am driving should say yes
    When I use a lockpick on the nearest vehicle
    Then I should see a notification containing "You do not need a lockpick for this vehicle."
    And no lockpick minigame should have started

  @world @rejection
  Scenario: Hotwiring from the driver seat needs a lockpick item
    # The server refuses before authorising a minigame because the test
    # character holds neither Config.Lockpick.items entry.
    Given I should have no "lockpick"
    And I should have no "advancedlockpick"
    And I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    Then the engine of the vehicle I am driving should be off
    When I use a lockpick on the nearest vehicle
    Then I should see a notification containing "You need a lockpick."
    And no lockpick minigame should have started
    And I should still hold no keys of the vehicle I am driving

  # -------------------------------------------------------------------------
  # Plate normalisation and the key exports (server/main.lua normalisePlate:
  # trimmed, upper-cased, inner whitespace collapsed, at most 32 characters,
  # any characters allowed).
  # -------------------------------------------------------------------------

  @server
  Scenario: Giving and removing keys is idempotent
    Given I am given vehicle keys for plate "FFTIDEM1"
    And I am given vehicle keys for plate "FFTIDEM1"
    Then I should hold vehicle keys for plate "FFTIDEM1"
    When my vehicle keys for plate "FFTIDEM1" are taken away
    Then I should not hold vehicle keys for plate "FFTIDEM1"
    When my vehicle keys for plate "FFTIDEM1" are taken away
    Then I should not hold vehicle keys for plate "FFTIDEM1"

  @server
  Scenario: Inner whitespace of a plate is collapsed, not removed
    Given I am given vehicle keys for plate "fft   key 4"
    Then I should hold vehicle keys for plate "FFT KEY 4"
    And I should hold vehicle keys for plate "  Fft Key   4  "
    And I should not hold vehicle keys for plate "FFTKEY4"

  @server
  Scenario: Plates may carry punctuation
    Given I am given vehicle keys for plate " fft-#1 "
    Then I should hold vehicle keys for plate "FFT-#1"
    And I should not hold vehicle keys for plate "FFT1"

  @server @rejection
  Scenario: A 32 character plate is accepted and a 33 character plate is refused
    Given I am given vehicle keys for plate "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"
    Then I should hold vehicle keys for plate "abcdefghijklmnopqrstuvwxyz012345"
    And giving vehicle keys for plate "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456" should be refused
    And I should not hold vehicle keys for plate "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456"

  @rejection
  Scenario: The client key check answers for plates the server knows and refuses over-long plates locally
    Given I am given vehicle keys for plate "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"
    Then my client key check for plate "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345" should say yes
    And my client key check for plate "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456" should say no
    And my client key check for plate "FFTNOKEY" should say no

  @rejection
  Scenario: Plates that are not text are refused everywhere
    Then the vehicle key exports should refuse a plate that is not text
    And the server key checks should answer no for a plate that is not text

  @server
  Scenario: The legacy exports tolerate swapped arguments
    Given I am given vehicle keys for plate "FFTLEG1" through the legacy export with swapped arguments
    Then I should hold vehicle keys for plate "FFTLEG1"
    When my vehicle keys for plate "FFTLEG1" are taken away through the legacy export
    Then I should not hold vehicle keys for plate "FFTLEG1"

  @server @rejection
  Scenario: The legacy exports refuse ids that are not online players
    Then the legacy key exports should refuse player ids that are not online players

  @world
  Scenario: The legacy GiveKeys export without a plate keys the vehicle I am driving
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    When the legacy GiveKeys export without a plate gives me the keys of the vehicle I am driving
    Then I should still hold the keys of the vehicle I am driving
    And my client key check for the vehicle I am driving should say yes

  @world @rejection
  Scenario: The legacy GiveKeys export without a plate does nothing on foot
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    Then the legacy GiveKeys export without a plate should refuse me on foot

  # -------------------------------------------------------------------------
  # Stock callbacks and events answering about the caller only
  # -------------------------------------------------------------------------

  Scenario: The server key list and ownership check follow a held key
    Given I am given vehicle keys for plate "FFTLIST1"
    Then the server key list should include plate "FFTLIST1"
    And the server should say plate "FFTLIST1" is owned by me
    When my vehicle keys for plate "FFTLIST1" are taken away
    Then the server key list should not include plate "FFTLIST1"

  @rejection
  Scenario: A plate that is neither keyed nor registered is not mine
    Then the server key list should not include plate "FFTNONE1"
    And the server should say plate "FFTNONE1" is not owned by me

  Scenario: A registered vehicle counts as owned without a key
    Given my vehiclekeys test plate belongs to an owned vehicle
    Then the server should say my vehiclekeys test plate is owned by me

  Scenario: The legacy client RemoveKeys event drops my own key
    Given I am given vehicle keys for plate "FFTDROP1"
    When I drop my keys for plate "FFTDROP1" through the legacy client event
    Then I should lose the vehicle keys for plate "FFTDROP1"

  # -------------------------------------------------------------------------
  # Callback validation (server/main.lua validateVehicle and kora_lib
  # Kora.world.resolveNetworkEntity)
  # -------------------------------------------------------------------------

  @rejection
  Scenario Outline: A lock toggle for a malformed network id is refused
    Then asking the server to toggle network id "<id>" should be refused with "Invalid vehicle."

    Examples:
      | id  |
      | 0   |
      | -1  |
      | 1.5 |
      | abc |

  @rejection
  Scenario: A lock toggle for an entity that is not a vehicle is refused
    Then asking the server to toggle my own character should be refused with "Vehicle is no longer available."

  @world @rejection
  Scenario: A lock toggle from beyond the remote distance is refused
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And my test car carries my vehiclekeys test plate
    And I hold the keys of my vehiclekeys test car
    When I step out of the vehicle I am driving
    And I move 40 metres away from my test car
    Then asking the server to toggle my test car should be refused with "Move closer to the vehicle."
    And my vehiclekeys test car should not be locked by its keys

  @world
  Scenario: Ignition access needs the keys and the driver seat
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    Then the server should answer no when I ask for access to my test car
    Given I hold the keys of the vehicle I am driving
    Then the server should answer yes when I ask for access to my test car
    When I step out of the vehicle I am driving
    Then the server should answer no when I ask for access to my test car

  # -------------------------------------------------------------------------
  # Lock state: server state bag and the client door lock it drives
  # -------------------------------------------------------------------------

  @world
  Scenario: The server lock toggle drives the client door lock
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    Then asking the server to toggle the lock of my test car should answer locked
    And the vehicle I am driving should be locked by its keys
    And the doors of my test car should report lock status 2
    Then asking the server to toggle the lock of my test car should answer unlocked
    And the vehicle I am driving should not be locked by its keys
    And the doors of my test car should report lock status 1

  @world
  Scenario: The legacy lock state event locks and unlocks for a key holder
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    When I set the lock state of my test car to 2 through the legacy server event
    Then the vehicle I am driving should be locked by its keys
    When I set the lock state of my test car to 1 through the legacy server event
    Then the vehicle I am driving should not be locked by its keys

  @world @rejection
  Scenario: The legacy lock state event is ignored without keys
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    When I set the lock state of my test car to 2 through the legacy server event
    Then the vehicle I am driving should not be locked by its keys

  @world
  Scenario: A model marked as having no lock is skipped by the lock toggle until unmarked
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    And the vehicle model "sultan" is marked as having no lock
    When I run the command "togglelocks"
    Then I should not see a notification containing "Vehicle locked."
    And the vehicle I am driving should not be locked by its keys
    When the vehicle model "sultan" is no longer marked as having no lock
    And I run the command "togglelocks"
    Then I should see a notification containing "Vehicle locked."
    And the vehicle I am driving should be locked by its keys

  @world
  Scenario: A locked bike keeps its native doors unlocked
    # client/main.lua applyLockState: bikes have no doors, so the native status stays 1.
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "bati"
    And I hold the keys of the vehicle I am driving
    Then asking the server to toggle the lock of my test car should answer locked
    And the vehicle I am driving should be locked by its keys
    And the doors of my test car should keep lock status 1

  @world
  Scenario: The legacy engine event toggles the engine for a key holder
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    And the engine of the vehicle I am driving is running
    When I toggle the engine with the legacy client event
    Then the engine of the vehicle I am driving should be off

  # -------------------------------------------------------------------------
  # Lockpick and hotwire refusals before any minigame is authorised
  # (server/main.lua lockpickStarted / hotwireStarted; Config.Text)
  # -------------------------------------------------------------------------

  @world @rejection
  Scenario: Lockpicking an unlocked car on foot is refused
    Given I should have no "lockpick"
    And I should have no "advancedlockpick"
    And I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    When I step out of the vehicle I am driving
    And I use a lockpick on the nearest vehicle
    Then I should see a notification containing "This vehicle is not locked."
    And no lockpick minigame should have started

  @world @rejection
  Scenario: Lockpicking a locked car whose keys I hold is refused
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And my test car carries my vehiclekeys test plate
    And I hold the keys of my vehiclekeys test car
    Then asking the server to toggle the lock of my test car should answer locked
    When I step out of the vehicle I am driving
    Then my vehiclekeys test car should be locked by its keys
    And asking the server to lockpick my test car should be refused with "You already have the keys."
    And no lockpick minigame should have started

  @world @rejection
  Scenario: Lockpicking a locked car without a lockpick item is refused
    Given I should have no "lockpick"
    And I should have no "advancedlockpick"
    And I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And my test car carries my vehiclekeys test plate
    And I hold the keys of my vehiclekeys test car
    Then asking the server to toggle the lock of my test car should answer locked
    Given I hold no keys of my vehiclekeys test car
    When I step out of the vehicle I am driving
    And I use a lockpick on the nearest vehicle
    Then I should see a notification containing "You need a lockpick."
    And no lockpick minigame should have started
    And my vehiclekeys test car should be locked by its keys
    And I should hold no keys of my vehiclekeys test car

  @world @rejection
  Scenario: Hotwiring a car whose keys I hold is refused by the server
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    Then asking the server to hotwire my test car should be refused with "You already have the keys."
    And no lockpick minigame should have started

  @world @rejection
  Scenario: A lockpick with no vehicle in reach explains itself
    # The kora_doorlock door fallback runs first; the airfield has no lockpickable door.
    Given I should have no "lockpick"
    And I stand at 1747.0 3273.7 41.6 facing 90.0
    When I use a lockpick on the nearest vehicle
    Then I should see a notification containing "There is no vehicle close enough to lockpick."
    And no lockpick minigame should have started

  # -------------------------------------------------------------------------
  # Trusted owner grants (Config.TrustedSetOwner: a vehicle the player
  # spawned within 15 s, unlocked, not an owned row, plate not contested)
  # -------------------------------------------------------------------------

  @world
  Scenario: A freshly spawned car is keyed through the stock SetOwner event
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    When I claim the keys of the vehicle I am driving with the client event "vehiclekeys:client:SetOwner"
    Then I should be granted the keys of the vehicle I am driving
    And my client key check for the vehicle I am driving should say yes

  @world
  Scenario: A freshly spawned car is keyed when an older caller sends its plate
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold no keys of the vehicle I am driving
    When I claim the keys of the vehicle I am driving by plate through the legacy server event
    Then I should be granted the keys of the vehicle I am driving

  @world @rejection
  Scenario: A locked car is never keyed through the stock AddKeys event
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And my test car carries my vehiclekeys test plate
    And I hold the keys of my vehiclekeys test car
    Then asking the server to toggle the lock of my test car should answer locked
    Given I hold no keys of my vehiclekeys test car
    When I claim the keys of the vehicle I am driving with the client event "qb-vehiclekeys:client:AddKeys"
    Then I should not be granted the keys of the vehicle I am driving

  @world @rejection
  Scenario: A car carrying a registered plate is never keyed through SetOwner
    Given my vehiclekeys test plate belongs to an owned vehicle
    And I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And my test car carries my vehiclekeys test plate
    When I claim the keys of the vehicle I am driving with the client event "vehiclekeys:client:SetOwner"
    Then I should not be granted the keys of the vehicle I am driving

  @world @rejection @slow
  Scenario: A car spawned more than 15 seconds ago is not keyed through SetOwner
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    When I wait 8000 milliseconds
    And I wait 8000 milliseconds
    And I claim the keys of the vehicle I am driving with the client event "vehiclekeys:client:SetOwner"
    Then I should not be granted the keys of the vehicle I am driving

  # -------------------------------------------------------------------------
  # Handing keys over: the giver never counts as a receiver
  # -------------------------------------------------------------------------

  @world @rejection
  Scenario: Handing keys to my own id with the givekeys command does nothing
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    When I run the givekeys command with my own server id
    Then I should not see a notification containing "You hand over the keys."
    And I should still hold the keys of the vehicle I am driving

  @world @rejection
  Scenario: The legacy GiveVehicleKeys event ignores the giver as receiver
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    When I hand the keys of the vehicle I am driving to myself through the legacy server event
    Then I should not see a notification containing "You hand over the keys."
    And I should not see a notification containing "You get keys to the vehicle!"
    And I should still hold the keys of the vehicle I am driving

  # -------------------------------------------------------------------------
  # Rate limit (Config.RateLimits.toggle = 10 calls per 5000 ms)
  # -------------------------------------------------------------------------

  @world @rejection @slow
  Scenario: The eleventh lock toggle within five seconds is rejected
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    And I am driving a temporary "sultan"
    And I hold the keys of the vehicle I am driving
    And I wait 5100 milliseconds
    When I toggle the lock of my test car 10 times through the server
    Then the next lock toggle of my test car should be rejected by the rate limit
    And the vehicle I am driving should not be locked by its keys
    When I wait 5100 milliseconds
    Then asking the server to toggle the lock of my test car should answer locked
    And the vehicle I am driving should be locked by its keys
