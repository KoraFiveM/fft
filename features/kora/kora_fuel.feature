@kora @kora_fuel
Feature: kora_fuel paid refuelling and EV charging
  Petrol pumps offer the kora_target option "Service nearby vehicle" and EV
  charging stations "Charge vehicle" (only while a chargeable electric vehicle
  is nearby). Both open the AppShell app "kora_fuel:pump"; its "fuel-submit"
  action asks the server to validate, run the progress bar on the client, take
  the money and fill the vehicle. Scenarios park a temporary vehicle (engine
  off, level set through the SetFuel export) beside the Little Seoul charger
  (Config.charging.stations in config.lua: -727.31 -906.89 18.05) or the pump
  nearest the Little Seoul station point (Config.stations: -723.145 -935.051
  19.213) and press the real options; the purchase event is never sent
  directly. Prices are Config.charging.pricePerPercent 1.25 (rounded up) and
  Config.pricePerUnit.fuel 2.0. Prop positions, the free side of each prop and
  ambient traffic on the forecourt are unverified until a live run: the parking
  step fails with a clear message when another vehicle is closer than its own.

  Not covered: fuel drain while driving (time and speed dependent), cancelling
  the progress bar (needs a key press), the "no vehicle nearby" and "move to a
  station" refusals (the options are only reachable beside a prop with the
  parked vehicle present), map blips, the legacy LegacyFuel/ps-fuel export
  names and server refusals that need a forged request (wrong network id,
  unknown payment account).

  Round 3 adds the legacy LegacyFuel / qb-fuel / ps-fuel / cdn-fuel exports
  (exports[name] resolves through kora_lib's compat handler), the
  classification of every listed EV model, every charging station and every
  Config.stations service point, price rounding, exact and short funds, the
  client-side amount checks, the app header, notification titles and the GPS
  waypoint an EV gets at a petrol pump. Still not covered: a non-cash/bank
  account (the form only offers Config.paymentAccounts) and the server's
  busy-guard (the app closes on submit, so a second submit cannot be sent).

  Background:
    Given resource "kora_fuel" is running

  @world
  Scenario: Fuel exports clamp the level and classify the vehicle
    Given I park a "blista" with fuel level 40 at the charger near -727.31 -906.89 18.05
    Then the fuel level of the parked vehicle should be 40
    And the parked vehicle should count as petrol for fuel
    When I set the fuel level of the parked vehicle to 150.0
    Then the fuel level of the parked vehicle should be 100
    When I set the fuel level of the parked vehicle to 40.7
    Then the fuel level of the parked vehicle should be 40
    And setting the fuel level of a missing vehicle should be refused

  @world @ui @slow
  Scenario: An electric vehicle is charged for cash
    Given I have 50 in my "cash" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 40 at the charger near -727.31 -906.89 18.05
    Then the parked vehicle should count as electric for fuel
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 4, "account": "cash" } }
      """
    Then a progress bar labelled "Charging vehicle" should start
    And the progress bar should finish
    And I should see a notification containing "Vehicle charged for $5."
    And my "cash" balance should have decreased by 5
    And the fuel level of the parked vehicle should be 44

  @world @ui @rejection
  Scenario: Charging is refused without the money
    Given I have 0 in my "cash" account
    And I have 0 in my "bank" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 40 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 4, "account": "cash" } }
      """
    Then I should see a notification containing "Insufficient funds."
    And no progress bar should be running
    And my "cash" balance should be unchanged
    And the fuel level of the parked vehicle should stay 40

  @world @ui @rejection
  Scenario: A fill amount above the free capacity is refused
    Given I have 200 in my "cash" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 90 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 50, "account": "cash" } }
      """
    Then I should see a notification containing "Invalid fill amount."
    And my "cash" balance should be unchanged
    And the fuel level of the parked vehicle should stay 90

  @world @rejection
  Scenario: The charger offers nothing for a petrol vehicle
    Given I park a "blista" with fuel level 40 at the charger near -727.31 -906.89 18.05
    Then no target option should be visible

  @world @rejection
  Scenario: The charger offers nothing for a full battery
    Given I park a "voltic" with fuel level 100 at the charger near -727.31 -906.89 18.05
    Then no target option should be visible

  @world @rejection
  Scenario: Charging is refused while the engine is running
    Given I park a "voltic" with fuel level 40 at the charger near -727.31 -906.89 18.05
    And the engine of the parked vehicle is left running
    When I target "Charge vehicle"
    Then I should see a notification containing "Switch the engine off before servicing the vehicle."
    And no app should be open

  @world @ui @slow
  Scenario: A petrol vehicle is refuelled from the bank account
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    And I park a "blista" with fuel level 40 at the fuel pump near -723.145 -935.051 19.213
    When I target "Service nearby vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 5, "account": "bank" } }
      """
    Then a progress bar labelled "Refuelling vehicle" should start
    And the progress bar should finish
    And I should see a notification containing "Vehicle refuelled for $10."
    And my "bank" balance should have decreased by 10
    And the fuel level of the parked vehicle should be 45

  @world @rejection
  Scenario: A petrol pump sends an electric vehicle to a charging station
    Given I park a "voltic" with fuel level 40 at the fuel pump near -723.145 -935.051 19.213
    When I target "Service nearby vehicle"
    Then I should see a notification containing "Electric vehicles cannot use petrol pumps."
    And no app should be open
    And the fuel level of the parked vehicle should stay 40

  @world @rejection
  Scenario: A full tank is not offered a refuel menu
    Given I park a "blista" with fuel level 100 at the fuel pump near -723.145 -935.051 19.213
    When I target "Service nearby vehicle"
    Then I should see a notification containing "Vehicle is already full."
    And no app should be open

  # ---------------------------------------------------------------------------
  # Exports (client/main.lua:28-85)
  # ---------------------------------------------------------------------------

  @world
  Scenario: SetFuel clamps negative and boundary levels
    Given I spawn a temporary "blista" beside me for kora_fuel
    When I set the fuel level of the parked vehicle to -5.0
    Then the fuel level of the parked vehicle should be 0
    When I set the fuel level of the parked vehicle to 0.0
    Then the fuel level of the parked vehicle should be 0
    When I set the fuel level of the parked vehicle to 100.0
    Then the fuel level of the parked vehicle should be 100
    When I set the fuel level of the parked vehicle to 99.99
    Then the fuel level of the parked vehicle should be 99

  Scenario: A missing vehicle is never electric
    Then a missing vehicle should not count as electric for fuel

  @world
  Scenario Outline: Listed electric models are classified as electric
    Given I spawn a temporary "<model>" beside me for kora_fuel
    Then the parked vehicle should count as electric for fuel

    Examples:
      | model      |
      | voltic     |
      | neon       |
      | raiden     |
      | khamelion  |
      | surge      |
      | tezeract   |
      | cyclone    |
      | dilettante |
      | imorgon    |
      | caddy      |
      | airtug     |

  @world
  Scenario Outline: Petrol models are classified as petrol
    Given I spawn a temporary "<model>" beside me for kora_fuel
    Then the parked vehicle should count as petrol for fuel

    Examples:
      | model  |
      | blista |
      | sultan |
      | adder  |
      | bison  |

  @world
  Scenario Outline: Legacy fuel exports keep fractional levels and return nothing
    Given I spawn a temporary "blista" beside me for kora_fuel
    When I set the fuel of the parked vehicle through the legacy "<provider>" export to 40.5
    Then the legacy "<provider>" fuel export should read the parked vehicle as 40.5
    And the fuel level of the parked vehicle should be 40
    When I set the fuel of the parked vehicle through the legacy "<provider>" export to 250.0
    Then the legacy "<provider>" fuel export should read the parked vehicle as 100.0
    When I set the fuel of the parked vehicle through the legacy "<provider>" export to -10.0
    Then the legacy "<provider>" fuel export should read the parked vehicle as 0.0

    Examples:
      | provider   |
      | LegacyFuel |
      | qb-fuel    |
      | ps-fuel    |
      | cdn-fuel   |

  @world @rejection
  Scenario Outline: Legacy fuel exports ignore bad levels and non-vehicles
    Given I spawn a temporary "blista" beside me for kora_fuel
    And I set the fuel level of the parked vehicle to 30.0
    Then the legacy "<provider>" fuel export should ignore a non-finite level
    And the legacy "<provider>" fuel export should ignore my own ped
    And the legacy "<provider>" fuel export should ignore a missing vehicle
    And the fuel level of the parked vehicle should be 30

    Examples:
      | provider   |
      | LegacyFuel |
      | qb-fuel    |
      | ps-fuel    |
      | cdn-fuel   |

  # ---------------------------------------------------------------------------
  # Charging at a station: prices (pricePerPercent 1.25, rounded up) and funds
  # ---------------------------------------------------------------------------

  @world @ui @slow
  Scenario Outline: Charging bills whole dollars rounded up
    Given I have 100 in my "cash" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 40 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": <quantity>, "account": "cash" } }
      """
    Then a progress bar labelled "Charging vehicle" should start
    And the progress bar should finish
    And the kora_fuel notice "Vehicle charged for $<price>." should be titled "Charging"
    And my "cash" balance should have decreased by <price>
    And the fuel level of the parked vehicle should be <level>

    Examples:
      | quantity | price | level |
      | 1        | 2     | 41    |
      | 3        | 4     | 43    |
      | 8        | 10    | 48    |
      | 20       | 25    | 60    |

  @world @ui @slow
  Scenario: Charging with exactly enough cash succeeds
    Given I have 5 in my "cash" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 40 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 4, "account": "cash" } }
      """
    Then the progress bar should finish
    And I should see a notification containing "Vehicle charged for $5."
    And my "cash" balance should have decreased by 5
    And the fuel level of the parked vehicle should be 44

  @world @ui @rejection
  Scenario: Charging one dollar short is refused
    Given I have 4 in my "cash" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 40 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 4, "account": "cash" } }
      """
    Then the kora_fuel notice "Insufficient funds." should be titled "Charging"
    And no progress bar should be running
    And my "cash" balance should be unchanged
    And the fuel level of the parked vehicle should stay 40

  @world @ui @rejection
  Scenario: The chosen account must hold the money, not another one
    Given I have 500 in my "cash" account
    And I have 0 in my "bank" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    And I park a "voltic" with fuel level 40 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 4, "account": "bank" } }
      """
    Then I should see a notification containing "Insufficient funds."
    And my "cash" balance should be unchanged
    And my "bank" balance should be unchanged
    And the fuel level of the parked vehicle should stay 40

  @world @ui @slow
  Scenario: Charging the whole free capacity fills the battery and hides the charger
    Given I have 100 in my "cash" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 90 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 10, "account": "cash" } }
      """
    Then the progress bar should finish
    And I should see a notification containing "Vehicle charged for $13."
    And my "cash" balance should have decreased by 13
    And the fuel level of the parked vehicle should be 100
    And no target option should be visible

  @world @ui @slow
  Scenario: A fractional amount is rounded down before it is billed
    Given I have 100 in my "cash" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 40 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 2.7, "account": "cash" } }
      """
    Then the progress bar should finish
    And I should see a notification containing "Vehicle charged for $3."
    And my "cash" balance should have decreased by 3
    And the fuel level of the parked vehicle should be 42

  @world @ui @rejection
  Scenario Outline: The service form refuses amounts outside 1 to the free capacity
    Given I have 200 in my "cash" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 90 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": <quantity>, "account": "cash" } }
      """
    Then I should see a notification containing "Invalid fill amount."
    And no progress bar should be running
    And my "cash" balance should be unchanged
    And the fuel level of the parked vehicle should stay 90

    Examples:
      | quantity |
      | 0        |
      | -5       |
      | 0.5      |
      | 11       |
      | "lots"   |

  @world @ui
  Scenario: The charging app names the station and closing it costs nothing
    Given I have 100 in my "cash" account
    And I remember my "cash" balance
    And I park a "voltic" with fuel level 40 at the charger near -727.31 -906.89 18.05
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    And the fuel app should be titled "Charge vehicle" with the description "Battery charge - Little Seoul"
    When I close the app
    Then no app should be open
    And no progress bar should be running
    And my "cash" balance should be unchanged
    And the fuel level of the parked vehicle should stay 40

  @world @ui @slow
  Scenario Outline: Every charging station offers Charge vehicle for an EV
    Given I park a "voltic" with fuel level 40 at the charger near <x> <y> <z>
    When I target "Charge vehicle"
    Then the app "kora_fuel:pump" should be open
    And the fuel app should be titled "Charge vehicle" with the description "Battery charge - <label>"
    When I close the app
    Then no app should be open

    Examples:
      | label              | x       | y        | z      |
      | Murrieta Heights   | 1194.54 | -1391.44 | 34.40  |
      | La Puerta          | -334.59 | -1455.46 | 29.54  |
      | Little Seoul       | -727.31 | -906.89  | 18.05  |
      | Little Seoul South | -546.88 | -1221.65 | 17.31  |
      | Elysian Island     | -60.77  | -2536.23 | 5.19   |
      | Pacific Bluffs     | -2078.15 | -298.24 | 12.29  |
      | Downtown Vinewood  | 625.68  | 247.43   | 102.06 |
      | Tataviam Mountains | 2555.33 | 347.47   | 107.65 |
      | Route 68 West      | 62.59   | 2788.68  | 56.92  |
      | Route 68 East      | 1017.87 | 2654.75  | 38.74  |
      | Senora Freeway     | 2691.46 | 3267.82  | 54.28  |
      | Grapeseed          | 1697.68 | 4918.80  | 41.11  |
      | Paleto Bay         | -91.02  | 6391.60  | 30.68  |

  # ---------------------------------------------------------------------------
  # Petrol pumps (Config.pricePerUnit.fuel 2.0)
  # ---------------------------------------------------------------------------

  @world @ui @slow
  Scenario Outline: Refuelling bills two dollars a unit
    Given I have 200 in my "cash" account
    And I remember my "cash" balance
    And I park a "blista" with fuel level 40 at the fuel pump near -723.145 -935.051 19.213
    When I target "Service nearby vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": <quantity>, "account": "cash" } }
      """
    Then a progress bar labelled "Refuelling vehicle" should start
    And the progress bar should finish
    And the kora_fuel notice "Vehicle refuelled for $<price>." should be titled "Fuel"
    And my "cash" balance should have decreased by <price>
    And the fuel level of the parked vehicle should be <level>

    Examples:
      | quantity | price | level |
      | 1        | 2     | 41    |
      | 12       | 24    | 52    |
      | 60       | 120   | 100   |

  @world @ui @rejection
  Scenario: Refuelling without the money is refused
    Given I have 0 in my "cash" account
    And I have 0 in my "bank" account
    And I remember my "bank" balance
    And I park a "blista" with fuel level 40 at the fuel pump near -723.145 -935.051 19.213
    When I target "Service nearby vehicle"
    Then the app "kora_fuel:pump" should be open
    When I trigger the app action "fuel-submit" with:
      """
      { "value": { "quantity": 5, "account": "bank" } }
      """
    Then the kora_fuel notice "Insufficient funds." should be titled "Fuel"
    And no progress bar should be running
    And my "bank" balance should be unchanged
    And the fuel level of the parked vehicle should stay 40

  @world @rejection
  Scenario: Refuelling is refused while the engine is running
    Given I park a "blista" with fuel level 40 at the fuel pump near -723.145 -935.051 19.213
    And the engine of the parked vehicle is left running
    When I target "Service nearby vehicle"
    Then the kora_fuel notice "Switch the engine off before servicing the vehicle." should be titled "Fuel"
    And no app should be open

  @world @ui
  Scenario: The pump app shows the petrol header
    Given I park a "blista" with fuel level 40 at the fuel pump near -723.145 -935.051 19.213
    When I target "Service nearby vehicle"
    Then the app "kora_fuel:pump" should be open
    And the fuel app should be titled "Refuel vehicle" with the description "Petrol pump"
    When I close the app
    Then no app should be open
    And the fuel level of the parked vehicle should stay 40

  @world @rejection
  Scenario: An EV at a petrol pump is pointed at the nearest charger
    Given my GPS waypoint is put back afterwards
    And I park a "voltic" with fuel level 40 at the fuel pump near -723.145 -935.051 19.213
    When I target "Service nearby vehicle"
    Then the kora_fuel notice "Nearest: Little Seoul" should be titled "Charging"
    And I should see a notification containing "A GPS waypoint has been set to it."
    And my GPS waypoint should be near -727.31 -906.89
    And no app should be open

  @world @ui @slow
  Scenario Outline: Every fuel station service point has a pump that opens the service app
    Given I park a "blista" with fuel level 40 at the fuel pump near <x> <y> <z>
    When I target "Service nearby vehicle"
    Then the app "kora_fuel:pump" should be open
    And the fuel app should be titled "Refuel vehicle" with the description "Petrol pump"
    When I close the app
    Then no app should be open

    Examples:
      | x         | y         | z       |
      | 49.4187   | 2778.793  | 58.043  |
      | 263.894   | 2606.463  | 44.983  |
      | 1039.958  | 2671.134  | 39.550  |
      | 1207.260  | 2660.175  | 37.899  |
      | 2539.685  | 2594.192  | 37.944  |
      | 2679.858  | 3263.946  | 55.240  |
      | 2005.055  | 3773.887  | 32.403  |
      | 1687.156  | 4929.392  | 42.078  |
      | 1701.314  | 6416.028  | 32.763  |
      | 179.857   | -1562.329 | 29.263  |
      | -94.461   | -1761.405 | 29.534  |
      | -723.145  | -935.051  | 19.213  |
      | -526.019  | -1211.003 | 18.184  |
      | -70.2148  | -1761.792 | 29.534  |
      | 265.648   | -1261.309 | 29.292  |
      | 819.653   | -1028.846 | 26.403  |
      | 1208.951  | -1402.567 | 35.224  |
      | 1181.381  | -330.847  | 69.316  |
      | 620.843   | 269.100   | 103.089 |
      | 2581.321  | 362.039   | 108.468 |
      | 176.631   | -1562.026 | 29.263  |
      | -319.292  | -1471.715 | 30.549  |
      | 1784.324  | 3330.550  | 41.253  |
