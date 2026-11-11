@kora @kora_garages
Feature: kora_garages parking, job garages and the impound lot
  Garages are kora_lib interact box zones (the selector opens on entering the
  zone) that open the AppShell app "kora_garages:garage"; a vehicle card runs the
  action "garage:use", which takes the vehicle out, stores it or pays its
  impound release depending on the row state. Each scenario creates its own
  owned vehicle through kora_core's createVehicle export with a fresh plate and
  removes the spawned entity, the keys and the row again in cleanup; state is
  asserted on the server from player_vehicles (kora_core getByPlate).
  Garage ids, labels and coordinates are Config.garages in shared/config.lua
  (legionsquare, missionrow, impoundlot); positions are unverified until a live
  run. The impound fee is taken from cash (server/server.lua confirmOut), not
  from Config.impound.account.

  Not covered: storing into a property garage and taking out of one (a
  successful RegisterPropertyGarage writes a durable row with no delete API, so
  only its validation refusals are exercised), storing with saved cosmetics or
  damage snapshots, the "Vehicle is occupied." refusal (needs a second player),
  a foreign-owned row ("That is not your vehicle"), the admin garage:storeAll
  command (ACE gated and it would park every player's vehicle).

  Background:
    Given resource "kora_garages" is running

  @server
  Scenario: Garage directory lists the configured garages
    Then the garage directory should list "legionsquare" as the public garage "Legion Square Parking"
    And the garage directory should list "missionrow" as the job garage "Mission Row Motor Pool"
    And the garage directory should list "impoundlot" as the impound garage "Davis Impound Lot"

  @world @ui
  Scenario: Walking into a public garage offers its panel
    Given I stand at 211.52 -802.16 30.89 facing 341.39
    Then the interact selector should offer "Open Legion Square Parking"
    When I choose "Open Legion Square Parking" in the interact selector
    Then the app "kora_garages:garage" should be open
    When I close the app
    Then no app should be open

  @world @ui
  Scenario: A garaged vehicle is taken out with its keys
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    When I ask to open the garage "legionsquare"
    Then the app "kora_garages:garage" should be open
    When I use my garage test vehicle in the garage app
    Then the garage should announce my garage test vehicle with "is ready."
    And my garage test vehicle should be out
    And my garage test vehicle should be in the world
    And I should hold the keys of my garage test vehicle

  @world @ui @slow
  Scenario: A vehicle that is out is stored again
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    When I ask to open the garage "legionsquare"
    And the app "kora_garages:garage" should be open
    And I use my garage test vehicle in the garage app
    Then the garage should announce my garage test vehicle with "is ready."
    And my garage test vehicle should be out
    # The car waits in the first free bay, up to 26 m away; drive it back.
    When I drive my garage test vehicle to 210.6 -801.2 29.95 facing 250.0
    And I ask to open the garage "legionsquare"
    And the app "kora_garages:garage" should be open
    And I use my garage test vehicle in the garage app
    Then the garage should announce my garage test vehicle with "is parked."
    And my garage test vehicle should be garaged
    And my garage test vehicle should be recorded at garage "legionsquare"
    And my garage test vehicle should not be in the world

  @world @ui @rejection @slow
  Scenario: A vehicle that is out but nowhere nearby cannot be stored
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    When I ask to open the garage "legionsquare"
    And the app "kora_garages:garage" should be open
    And I use my garage test vehicle in the garage app
    Then the garage should announce my garage test vehicle with "is ready."
    Given my garage test vehicle is removed from the world
    When I ask to open the garage "legionsquare"
    And the app "kora_garages:garage" should be open
    And I use my garage test vehicle in the garage app
    Then I should see a notification containing "That vehicle is not here."
    And my garage test vehicle should stay out

  @world @rejection
  Scenario: A garage cannot be opened from far away
    Given I stand at 211.52 -802.16 30.89 facing 341.39
    When I ask to open the garage "impoundlot"
    Then I should see a notification containing "Too far from the garage"
    And no app should be open

  @rejection
  Scenario: An unknown garage is refused by the export
    Then asking to open the garage "fft_no_such_garage" should be refused with "Garage is unavailable."
    And no app should be open

  @world @rejection
  Scenario: The police motor pool refuses a civilian
    Given my job is "unemployed" at grade 1
    And I stand at 456.01 -1017.22 28.40 facing 89.70
    When I ask to open the garage "missionrow"
    Then I should see a notification containing "You cannot use this garage"
    And no app should be open

  @world @rejection
  Scenario: The police motor pool refuses an off-duty officer
    Given I am off duty as "police" at grade 1
    And I stand at 456.01 -1017.22 28.40 facing 89.70
    When I ask to open the garage "missionrow"
    Then I should see a notification containing "You cannot use this garage"
    And no app should be open

  @world @ui
  Scenario: The police motor pool opens for an on-duty officer
    Given I am on duty as "police" at grade 1
    And I stand at 456.01 -1017.22 28.40 facing 89.70
    Then the interact selector should offer "Open Mission Row Motor Pool"
    When I choose "Open Mission Row Motor Pool" in the interact selector
    Then the app "kora_garages:garage" should be open

  @world @ui
  Scenario: Paying the fee releases an impounded vehicle
    Given I own a garaged "blista" for the garage tests
    And my garage test vehicle is impounded for a fee of 500
    And I have 600 in my "cash" account
    And I remember my "cash" balance
    And I stand at 409.9 -1622.9 29.3 facing 230.0
    Then the interact selector should offer "Collect from Davis Impound Lot"
    When I choose "Collect from Davis Impound Lot" in the interact selector
    Then the app "kora_garages:garage" should be open
    When I use my garage test vehicle in the garage app
    Then the garage should announce my garage test vehicle with "is ready."
    And my garage test vehicle should be out
    And my "cash" balance should have decreased by 500
    And I should hold the keys of my garage test vehicle

  @world @ui @rejection
  Scenario: An impounded vehicle stays held without the fee
    Given I own a garaged "blista" for the garage tests
    And my garage test vehicle is impounded for a fee of 500
    And I have 100 in my "cash" account
    And I remember my "cash" balance
    And I stand at 409.9 -1622.9 29.3 facing 230.0
    When I ask to open the garage "impoundlot"
    Then the app "kora_garages:garage" should be open
    When I use my garage test vehicle in the garage app
    Then I should see a notification containing "You need $500 to release this vehicle"
    And my garage test vehicle should stay impounded
    And my "cash" balance should be unchanged
    And my garage test vehicle should not be in the world
    And I should hold no keys of my garage test vehicle

  @world @ui @rejection
  Scenario: An impounded vehicle is not offered at a public garage
    Given I own a garaged "blista" for the garage tests
    And my garage test vehicle is impounded for a fee of 500
    And I stand at 211.52 -802.16 30.89 facing 341.39
    When I ask to open the garage "legionsquare"
    Then the app "kora_garages:garage" should be open
    When I try to use my unlisted garage test vehicle in the garage app
    Then my garage test vehicle should stay impounded
    And my garage test vehicle should not be in the world
    And I should hold no keys of my garage test vehicle

  # -------------------------------------------------------------------------
  # Every configured garage (shared/config.lua Config.garages and
  # Config.garageTypes: blip sprite 357 / impound 67, colour public 3,
  # job 38, gang 6, impound 5)
  # -------------------------------------------------------------------------

  Scenario Outline: The garage "<id>" is published to servers and clients
    Then the garage directory should list "<id>" as the <type> garage "<label>"
    And the garage directory entry "<id>" should use the "<blip>" blip with sprite <sprite> and colour <colour>
    And the garage directory entry "<id>" should bring vehicles out at <x> <y> <z>
    And the client garage catalogue should describe "<id>" as "<label>" of type <type>

    Examples:
      | id           | type    | label                   | blip        | sprite | colour | x      | y        | z     |
      | legionsquare | public  | Legion Square Parking   | Garage      | 357    | 3      | 207.56 | -798.5   | 29.98 |
      | motel        | public  | Pink Cage Motel Parking | Garage      | 357    | 3      | 267.15 | -332.51  | 43.92 |
      | sandyshores  | public  | Sandy Shores Parking    | Garage      | 357    | 3      | 1735.0 | 3714.3   | 34.1  |
      | missionrow   | job     | Mission Row Motor Pool  | Job Garage  | 357    | 38     | 446.5  | -1019.5  | 27.7  |
      | ballas       | gang    | Forum Drive Lockup      | Gang Garage | 357    | 6      | 92.3   | -1958.5  | 20.7  |
      | impoundlot   | impound | Davis Impound Lot       | Impound     | 67     | 5      | 403.5  | -1627.5  | 29.2  |

  @server @rejection
  Scenario: An unknown garage is not in the directory
    Then the garage directory should not list "fft_no_such_garage"

  @world @ui
  Scenario Outline: Walking into the public garage "<label>" offers its panel
    Given I stand at <x> <y> <z> facing <heading>
    Then the interact selector should offer "Open <label>"
    When I choose "Open <label>" in the interact selector
    Then the app "kora_garages:garage" should be open
    When I close the app
    Then no app should be open

    Examples:
      | label                   | x      | y      | z    | heading |
      | Pink Cage Motel Parking | 273.4  | -343.2 | 45.1 | 159.0   |
      | Sandy Shores Parking    | 1728.8 | 3712.0 | 34.2 | 22.0    |

  @world
  Scenario: The garage list callback names the garage it answers for
    Given I stand at 1728.8 3712.0 34.2 facing 22.0
    Then listing the garage "sandyshores" should describe it as "Sandy Shores Parking" of type public

  # -------------------------------------------------------------------------
  # Job and gang garages
  # -------------------------------------------------------------------------

  @world @rejection
  Scenario: The police motor pool zone is not offered to a civilian
    Given my job is "unemployed" at grade 1
    And I stand at 456.01 -1017.22 28.40 facing 89.70
    Then the garage zone should not offer "Open Mission Row Motor Pool"
    And listing the garage "missionrow" should be refused with "You cannot use this garage"

  @world @ui
  Scenario: The gang lockup opens for a gang member and lists their vehicles
    Given my gang is "ballas" at grade 0
    And I own a garaged "blista" for the garage tests
    And I stand at 85.0 -1959.7 21.1 facing 320.0
    Then the interact selector should offer "Open Forum Drive Lockup"
    When I choose "Open Forum Drive Lockup" in the interact selector
    Then the app "kora_garages:garage" should be open
    And listing the garage "ballas" should show my garage test vehicle as garaged

  @world @rejection
  Scenario: The gang lockup refuses someone outside the gang
    Given my gang is "vagos" at grade 0
    And I own a garaged "blista" for the garage tests
    And I stand at 85.0 -1959.7 21.1 facing 320.0
    Then the garage zone should not offer "Open Forum Drive Lockup"
    And listing the garage "ballas" should be refused with "You cannot use this garage"
    And taking my garage test vehicle out of "ballas" directly should be refused with "You cannot use this garage"
    And my garage test vehicle should stay garaged

  @world @rejection
  Scenario: Nothing is brought out when the only spawn point is blocked
    # ballas has a single spawn (92.3 -1958.5 20.7); a car parked on it blocks it
    # (Config.spawn.clearance = 3.0).
    Given my gang is "ballas" at grade 0
    And I own a garaged "blista" for the garage tests
    And I stand at 92.3 -1958.5 20.7 facing 320.0
    And I am driving a temporary "sultan"
    And I step out of the vehicle I am driving
    And I stand at 85.0 -1959.7 21.1 facing 320.0
    Then taking my garage test vehicle out of "ballas" directly should be refused with "There is no free spot to bring that out"
    And my garage test vehicle should stay garaged
    And my garage test vehicle should not be in the world

  # -------------------------------------------------------------------------
  # kora_garages:list, takeOut, confirmOut and cancelOut driven directly
  # -------------------------------------------------------------------------

  @world @rejection
  Scenario: Garage callbacks refuse an unknown garage
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    Then listing the garage "fft_no_such_garage" should be refused with "Unknown garage"
    And taking my garage test vehicle out of "fft_no_such_garage" directly should be refused with "Unknown garage"
    And storing my garage test vehicle at "fft_no_such_garage" directly with fuel 50.0 should be refused with "Unknown garage"
    And my garage test vehicle should stay garaged

  @world @rejection
  Scenario: Garage callbacks refuse a garage across town
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    Then listing the garage "motel" should be refused with "Too far from the garage"
    And taking my garage test vehicle out of "motel" directly should be refused with "Too far from the garage"
    And storing my garage test vehicle at "motel" directly with fuel 50.0 should be refused with "Too far from the garage"
    And my garage test vehicle should stay garaged
    And my garage test vehicle should not be in the world

  @world @rejection
  Scenario: A plate without a vehicle row cannot be taken out
    Given I stand at 211.52 -802.16 30.89 facing 341.39
    Then taking my garage test vehicle out of "legionsquare" directly should be refused with "That vehicle does not exist"

  @world @rejection
  Scenario: A vehicle that is already out is listed as out and cannot be taken out again
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    And my garage test vehicle is brought out at 207.56 -798.5 29.98
    Then listing the garage "legionsquare" should show my garage test vehicle as out
    And listing the garage "impoundlot" should be refused with "Too far from the garage"
    And taking my garage test vehicle out of "legionsquare" directly should be refused with "That vehicle is already out"
    And my garage test vehicle should stay out

  @world @rejection
  Scenario: An impounded vehicle cannot be taken out of a public garage directly
    Given I own a garaged "blista" for the garage tests
    And my garage test vehicle is impounded for a fee of 500
    And I stand at 211.52 -802.16 30.89 facing 341.39
    Then listing the garage "legionsquare" should not show my garage test vehicle
    And taking my garage test vehicle out of "legionsquare" directly should be refused with "That vehicle is impounded"
    And my garage test vehicle should stay impounded
    And my garage test vehicle should not be in the world

  @world
  Scenario: A direct take-out becomes final only once confirmed
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    When I start taking my garage test vehicle out of "legionsquare" directly
    Then my garage test vehicle should stay garaged
    And I should hold no keys of my garage test vehicle
    When I confirm taking my garage test vehicle out
    Then my garage test vehicle should be out
    And my garage test vehicle should be in the world
    And I should hold the keys of my garage test vehicle
    And my spawned garage test vehicle should carry its player_vehicles id

  @world @rejection
  Scenario: A second take-out of the same vehicle is refused and the first can be cancelled
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    When I start taking my garage test vehicle out of "legionsquare" directly
    Then taking my garage test vehicle out of "legionsquare" directly should be refused with "That vehicle is already being brought out"
    When I cancel taking my garage test vehicle out
    Then my garage test vehicle should not be in the world
    And my garage test vehicle should stay garaged
    And I should hold no keys of my garage test vehicle
    And confirming my garage test vehicle out with network id 0 should be refused with "That vehicle is no longer being brought out"

  @world @rejection
  Scenario: Confirming a take-out with the wrong network id discards it
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    When I start taking my garage test vehicle out of "legionsquare" directly
    Then confirming my garage test vehicle out with network id 0 should be refused with "Could not spawn that vehicle"
    And my garage test vehicle should not be in the world
    And my garage test vehicle should stay garaged
    And I should hold no keys of my garage test vehicle

  @world @rejection
  Scenario: Confirming a take-out that was never started is refused
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    Then confirming my garage test vehicle out with network id 0 should be refused with "That vehicle is no longer being brought out"
    And my garage test vehicle should stay garaged

  # -------------------------------------------------------------------------
  # Impound lot listing and fees
  # -------------------------------------------------------------------------

  @world
  Scenario: The impound lot lists only impounded vehicles, with their fee
    Given I own a garaged "blista" for the garage tests
    And I stand at 409.9 -1622.9 29.3 facing 230.0
    Then listing the garage "impoundlot" should describe it as "Davis Impound Lot" of type impound
    And listing the garage "impoundlot" should not show my garage test vehicle
    Given my garage test vehicle is impounded for a fee of 750
    Then listing the garage "impoundlot" should show my garage test vehicle with a fee of 750
    And listing the garage "impoundlot" should show my garage test vehicle as impounded

  @world @ui
  Scenario: Exactly the impound fee in cash is enough to release a vehicle
    Given I own a garaged "blista" for the garage tests
    And my garage test vehicle is impounded for a fee of 750
    And I have 750 in my "cash" account
    And I remember my "cash" balance
    And I stand at 409.9 -1622.9 29.3 facing 230.0
    When I ask to open the garage "impoundlot"
    Then the app "kora_garages:garage" should be open
    When I use my garage test vehicle in the garage app
    Then the garage should announce my garage test vehicle with "is ready."
    And my garage test vehicle should be out
    And my "cash" balance should have decreased by 750
    And my spawned garage test vehicle should carry its player_vehicles id

  @world @rejection
  Scenario: An impound fee above the configured maximum is capped
    # Config.impound.maxFee = 100000 ("ceiling so a bad impound write can't
    # bankrupt someone", shared/config.lua).
    Given I own a garaged "blista" for the garage tests
    And my garage test vehicle is impounded for a fee of 150000
    And I stand at 409.9 -1622.9 29.3 facing 230.0
    Then listing the garage "impoundlot" should show my garage test vehicle with a fee of 100000

  # -------------------------------------------------------------------------
  # kora_garages:store validation (server/server.lua)
  # -------------------------------------------------------------------------

  @world
  Scenario Outline: A fuel snapshot of <fuel> is stored
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    And my garage test vehicle is brought out at 207.56 -798.5 29.98
    When I store my garage test vehicle at "legionsquare" directly with fuel <fuel>
    Then my garage test vehicle should be garaged
    And my garage test vehicle should be recorded at garage "legionsquare"
    And my garage test vehicle should not be in the world

    Examples:
      | fuel  |
      | 0.0   |
      | 100.0 |

  @world @rejection
  Scenario Outline: A fuel snapshot of <fuel> is refused
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    And my garage test vehicle is brought out at 207.56 -798.5 29.98
    Then storing my garage test vehicle at "legionsquare" directly with fuel <fuel> should be refused with "Invalid fuel snapshot."
    And my garage test vehicle should stay out
    And my garage test vehicle should be in the world

    Examples:
      | fuel  |
      | -1.0  |
      | 100.5 |
      | 101.0 |

  @world @rejection
  Scenario: Vehicle modifications that are not a table are refused
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    And my garage test vehicle is brought out at 207.56 -798.5 29.98
    Then storing my garage test vehicle at "legionsquare" directly with the modifications "color1" should be refused with "Invalid vehicle modifications."
    And my garage test vehicle should stay out

  @world @rejection
  Scenario: A vehicle parked beyond the store distance is refused
    # The last legionsquare spawn (216.01 -776.44) is about 26 m from the
    # garage point; Config.interaction.storeDistance is 12.0.
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    And my garage test vehicle is brought out at 216.01 -776.44 29.83
    Then storing my garage test vehicle at "legionsquare" directly with fuel 50.0 should be refused with "Vehicle is too far away."
    And my garage test vehicle should stay out
    And my garage test vehicle should be in the world

  @world @rejection
  Scenario: Storing another car under my plate is refused
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    And I am driving a temporary "sultan"
    Then storing my garage test vehicle at "legionsquare" with the car I am driving should be refused with "Vehicle plate does not match."
    And I should be in a vehicle
    And my garage test vehicle should stay garaged

  @world @rejection
  Scenario: A vehicle that is nowhere in the world cannot be stored directly
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    Then storing my garage test vehicle at "legionsquare" directly with fuel 50.0 should be refused with "That vehicle is not here"
    And my garage test vehicle should stay garaged

  @world
  Scenario: A vehicle is stored at a different public garage and the stock list follows it
    Given I own a garaged "blista" for the garage tests
    Then my stock vehicle list should show my garage test vehicle as "Garaged" at "None"
    Given I stand at 1728.8 3712.0 34.2 facing 22.0
    And my garage test vehicle is brought out at 1735.0 3714.3 34.1
    Then my stock vehicle list should show my garage test vehicle as "Out" at "None"
    When I store my garage test vehicle at "sandyshores" directly with fuel 42.0
    Then my garage test vehicle should be garaged
    And my garage test vehicle should be recorded at garage "sandyshores"
    And my garage test vehicle should not be in the world
    And my stock vehicle list should show my garage test vehicle as "Garaged" at "Sandy Shores Parking"

  @world @rejection
  Scenario: Nothing can be parked at the impound lot
    # Config.garageTypes.impound.allowStore = false.
    Given I own a garaged "blista" for the garage tests
    And I stand at 409.9 -1622.9 29.3 facing 230.0
    And my garage test vehicle is brought out at 403.5 -1627.5 29.2
    Then storing my garage test vehicle at "impoundlot" directly should be refused
    And my garage test vehicle should stay out
    And my garage test vehicle should be in the world

  @world @rejection
  Scenario: An impounded vehicle cannot be parked to skip its fee
    Given I own a garaged "blista" for the garage tests
    And I stand at 211.52 -802.16 30.89 facing 341.39
    And my garage test vehicle is brought out at 207.56 -798.5 29.98
    And my garage test vehicle is impounded for a fee of 500
    Then storing my garage test vehicle at "legionsquare" directly should be refused
    And my garage test vehicle should stay impounded

  # -------------------------------------------------------------------------
  # Stock qb-garages vehicle list (server/compat.lua)
  # -------------------------------------------------------------------------

  @rejection
  Scenario: The stock vehicle list answers at most once a second
    Given I own a garaged "blista" for the garage tests
    Then asking for my stock vehicle list twice within a second should answer nothing the second time

  Scenario: The stock vehicle list labels an impounded vehicle
    Given I own a garaged "blista" for the garage tests
    And my garage test vehicle is impounded for a fee of 500
    Then my stock vehicle list should show my garage test vehicle as "Impounded By Police" at "None"

  # -------------------------------------------------------------------------
  # Property garage registration refusals (server/property.lua); every case
  # returns before the database write
  # -------------------------------------------------------------------------

  @server @rejection
  Scenario Outline: A property garage with <definition> is refused
    Then registering the property garage "<id>" with "<definition>" should be refused with "<message>"
    And the garage directory should not list "fft_property_probe"

    Examples:
      | id                                                  | definition                          | message                                         |
      | legionsquare                                        | a valid definition                  | Garage id already exists.                       |
      | fft_property_probe                                  | not a table                         | Invalid property garage.                        |
      | fft_property_probe_with_an_id_longer_than_fifty_chs | missing coordinates                 | Invalid property garage.                        |
      | fft_property_probe                                  | missing coordinates                 | Garage coordinates and capacity are required.   |
      | fft_property_probe                                  | no capacity                         | Garage coordinates and capacity are required.   |
      | fft_property_probe                                  | zero capacity                       | Garage coordinates and capacity are required.   |
      | fft_property_probe                                  | fractional capacity                 | Garage coordinates and capacity are required.   |
      | fft_property_probe                                  | capacity above 1000                 | Garage coordinates and capacity are required.   |
      | fft_property_probe                                  | no spawn                            | Garage needs a vehicle spawn.                   |
      | fft_property_probe                                  | a malformed spawn                   | Invalid garage spawn.                           |
      | fft_property_probe                                  | capacity owners that are not a list | Invalid capacity owners.                        |
      | fft_property_probe                                  | an empty capacity owner             | Invalid capacity owner.                         |

  @server @rejection
  Scenario: A property garage without a callable policy is refused
    Then registering the property garage "fft_property_probe" without a policy should be refused with "Garage policy must be callable."
    And the garage directory should not list "fft_property_probe"

  @server @rejection
  Scenario: A configured garage cannot be unregistered by another resource
    Then unregistering the property garage "legionsquare" should be refused with "Garage is not owned by this resource."
    And the garage directory should list "legionsquare" as the public garage "Legion Square Parking"
