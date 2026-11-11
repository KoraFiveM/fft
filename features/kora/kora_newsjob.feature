@kora @kora_newsjob
Feature: kora_newsjob Weazel News job
  Weazel News staff enter the building through a door target, take equipment
  from an interact point, and take vehicles from the "qb-newsjob:garage"
  AppShell app. Every option is gated on the job name "news", on the client
  (canInteract) and again in the server handlers.

  The job "news" comes from kora_core's static job seeds
  (shared/upstream/jobs.lua: label "Weazel News", one grade, config key '0').

  Not covered: taking the Rumpo van (the spawn creates a "trunk-<plate>"
  inventory that has no delete path); the "text.exit" door inside the
  building (the locale has no such entry, so its label is unverified); the
  camera and microphone props of the usable items (visual only); the garage
  map blip; and storing a vehicle (the resource never offers it).

  Background:
    Given resource "kora_newsjob" is running

  # Door zone is Config.Locations.outside = -598.25, -929.86, 23.86 (1.5 m box).
  # The stand point is 1.6 m east of it and outside the 2 m equipment zone.
  @world
  Scenario: Staff door fades a reporter into the building
    Given my job is "news" at grade 1
    And I stand at -596.65 -929.86 23.86 facing 90.0
    When I aim at -598.25 -929.86 23.86
    And I target "Enter"
    Then I should arrive inside the news building

  @world @rejection
  Scenario: Staff door is not offered to other jobs
    Given my job is "unemployed" at grade 1
    And I stand at -596.65 -929.86 23.86 facing 90.0
    When I aim at -598.25 -929.86 23.86
    Then no target option should be visible

  # Equipment zone is Config.Locations.shop = -595.4, -929.9, 23.86 (2 m box).
  @ui @world
  Scenario Outline: Equipment point hands out news gear
    Given my job is "news" at grade 1
    And I remember how many "<item>" I have
    And I stand at -595.4 -929.9 23.86 facing 90.0
    Then the interact selector should offer "<label>"
    When I choose "<label>" in the interact selector
    Then I should have 1 more "<item>" than before

    Examples:
      | label            | item     |
      | Take news camera | newscam  |
      | Take boom mic    | newsmic  |
      | Take hand mic    | newsbmic |

  @ui @world @rejection
  Scenario: Equipment point offers nothing to other jobs
    Given my job is "unemployed" at grade 1
    And I stand at -595.4 -929.9 23.86 facing 90.0
    Then the news equipment point should not offer "Take news camera"

  @server @rejection
  Scenario: Server refuses equipment for other jobs
    Given my job is "unemployed" at grade 1
    And I remember how many "newscam" I have
    When I ask the news equipment clerk for "newscam" directly
    Then I should have 0 more "newscam" than before

  @server @rejection
  Scenario: Server refuses equipment that is not news gear
    Given my job is "news" at grade 1
    And I remember how many "newscam" I have
    And I remember how many "newsmic" I have
    And I remember how many "newsbmic" I have
    When I ask the news equipment clerk for "fft_no_such_equipment" directly
    Then I should have 0 more "newscam" than before
    And I should have 0 more "newsmic" than before
    And I should have 0 more "newsbmic" than before

  # Garage zone is Config.Locations.vehicle.coords = -552.24, -925.61, 23.86.
  @ui @world
  Scenario: Garage point opens the Weazel News garage
    Given my job is "news" at grade 1
    And I stand at -552.24 -925.61 23.86 facing 242.5
    Then the interact selector should offer "Vehicles"
    When I choose "Vehicles" in the interact selector
    Then the app "qb-newsjob:garage" should be open
    When I close the app
    Then no app should be open

  # Helipad zone is Config.Locations.heli.coords = -583.08, -930.55, 36.83.
  # The stand point is 1.5 m off the spawn point, inside the 4 m zone and the
  # server's 5 m limit.
  @ui @world
  Scenario: Helipad releases the news helicopter
    Given my job is "news" at grade 1
    And I stand at -581.58 -930.55 36.83 facing 89.26
    And any news vehicle I take out is deleted afterwards
    Then the interact selector should offer "Helicopters"
    When I choose "Helicopters" in the interact selector
    Then the app "qb-newsjob:garage" should be open
    When I trigger the app action "qb-newsjob:spawn-vehicle" on "heli:1"
    Then I should be piloting a news "conada"

  # The car garage is about 31 m from the helipad; the server only spawns
  # within 5 m of the garage the vehicle belongs to.
  @ui @world @rejection
  Scenario: Server refuses a helicopter requested from the car garage
    Given my job is "news" at grade 1
    And I stand at -552.24 -925.61 23.86 facing 242.5
    And any news vehicle I take out is deleted afterwards
    Then the interact selector should offer "Vehicles"
    When I choose "Vehicles" in the interact selector
    Then the app "qb-newsjob:garage" should be open
    When I trigger the app action "qb-newsjob:spawn-vehicle" on "heli:1"
    Then the news garage should not have released a vehicle

  @ui @world @rejection
  Scenario: Garage refuses a vehicle that is not in its list
    Given my job is "news" at grade 1
    And I stand at -581.58 -930.55 36.83 facing 89.26
    And any news vehicle I take out is deleted afterwards
    Then the interact selector should offer "Helicopters"
    When I choose "Helicopters" in the interact selector
    Then the app "qb-newsjob:garage" should be open
    When I trigger the app action "qb-newsjob:spawn-vehicle" on "heli:99"
    Then the news garage should not have released a vehicle

  # ---------------------------------------------------------------------------
  # Round 3
  # ---------------------------------------------------------------------------

  # Every scenario that sets the job "news" depends on this seed being loaded.
  @server
  Scenario: The Weazel News job is in the job registry
    Then the job registry should define "news" labelled "Weazel News"
    And the job "news" should have 1 grade

  # server/main.lua grants one item per request with no limit or cooldown.
  @server
  Scenario: Repeated equipment requests each hand out an item
    Given my job is "news" at grade 1
    And I remember how many "newsmic" I have
    When I ask the news equipment clerk for "newsmic" directly
    And I ask the news equipment clerk for "newsmic" directly
    Then I should have 2 more "newsmic" than before

  # The server checks Player.job.name only, never job.onduty.
  @server
  Scenario Outline: An off-duty reporter still receives "<item>"
    Given I am off duty as "news" at grade 1
    And I remember how many "<item>" I have
    When I ask the news equipment clerk for "<item>" directly
    Then I should have 1 more "<item>" than before

    Examples:
      | item     |
      | newscam  |
      | newsmic  |
      | newsbmic |

  @server @rejection
  Scenario Outline: Server refuses equipment to the "<job>" job
    Given my job is "<job>" at grade 1
    And I remember how many "newscam" I have
    And I remember how many "newsbmic" I have
    When I ask the news equipment clerk for "newscam" directly
    And I ask the news equipment clerk for "newsbmic" directly
    Then I should have 0 more "newscam" than before
    And I should have 0 more "newsbmic" than before

    Examples:
      | job       |
      | police    |
      | ambulance |
      | mechanic  |

  @server @rejection
  Scenario Outline: Server refuses the malformed equipment name "<item>"
    Given my job is "news" at grade 1
    And I remember how many "newscam" I have
    And I remember how many "newsmic" I have
    When I ask the news equipment clerk for the malformed item "<item>"
    Then I should have 0 more "newscam" than before
    And I should have 0 more "newsmic" than before

    Examples:
      | item     |
      | NEWSCAM  |
      | Newsmic  |
      |          |

  @server @rejection
  Scenario: Server refuses an equipment name with surrounding spaces
    Given my job is "news" at grade 1
    And I remember how many "newscam" I have
    When I ask the news equipment clerk for the malformed item " newscam"
    And I ask the news equipment clerk for the malformed item "newscam "
    Then I should have 0 more "newscam" than before

  @ui @world @rejection
  Scenario: Equipment point offers no hand mic to other jobs
    Given my job is "police" at grade 1
    And I stand at -595.4 -929.9 23.86 facing 90.0
    Then the news equipment point should not offer "Take hand mic"
    And the news equipment point should not offer "Take boom mic"

  @ui @world
  Scenario: Car garage opens on the vehicles view
    Given my job is "news" at grade 1
    And I stand at -552.24 -925.61 23.86 facing 242.5
    When I choose "Vehicles" in the interact selector
    Then the news garage should open on the "vehicle" view
    When I close the app
    Then no app should be open

  @ui @world
  Scenario: Helipad opens the garage on the helicopters view
    Given my job is "news" at grade 1
    And I stand at -581.58 -930.55 36.83 facing 89.26
    When I choose "Helicopters" in the interact selector
    Then the news garage should open on the "heli" view
    When I close the app
    Then no app should be open

  @ui @world @rejection
  Scenario: Car garage is not offered to other jobs
    Given my job is "unemployed" at grade 1
    And I stand at -552.24 -925.61 23.86 facing 242.5
    Then the news garage point should not offer "Vehicles"
    And no app should be open

  @ui @world @rejection
  Scenario: Helipad is not offered to other jobs
    Given my job is "police" at grade 1
    And I stand at -581.58 -930.55 36.83 facing 89.26
    Then the news garage point should not offer "Helicopters"
    And no app should be open

  # The van garage (-552.24, -925.61) is about 31 m from the helipad; the server
  # only spawns within 5 m of the garage the vehicle belongs to, so nothing is
  # spawned and no trunk inventory is created.
  @ui @world @rejection
  Scenario: Server refuses a van requested from the helipad
    Given my job is "news" at grade 1
    And I stand at -581.58 -930.55 36.83 facing 89.26
    And any news vehicle I take out is deleted afterwards
    When I choose "Helicopters" in the interact selector
    Then the app "qb-newsjob:garage" should be open
    When I trigger the app action "qb-newsjob:spawn-vehicle" on "vehicle:1"
    Then the news garage should not have released a vehicle

  # vehicleChoices only holds ids built from Config.Locations (vehicle:1, heli:1).
  @ui @world @rejection
  Scenario Outline: Garage ignores the unknown vehicle id "<id>"
    Given my job is "news" at grade 1
    And I stand at -581.58 -930.55 36.83 facing 89.26
    And any news vehicle I take out is deleted afterwards
    When I choose "Helicopters" in the interact selector
    Then the app "qb-newsjob:garage" should be open
    When I trigger the app action "qb-newsjob:spawn-vehicle" on "<id>"
    Then the news garage should not have released a vehicle

    Examples:
      | id        |
      | heli:0    |
      | heli:2    |
      | vehicle:2 |
      | boat:1    |
      | heli      |

  # Both spawnReporterVehicle (client) and the spawnVehicle callback (server)
  # re-check the job when the button is pressed.
  @ui @world @rejection
  Scenario: Losing the news job while the garage is open releases nothing
    Given my job is "news" at grade 1
    And I stand at -581.58 -930.55 36.83 facing 89.26
    And any news vehicle I take out is deleted afterwards
    When I choose "Helicopters" in the interact selector
    Then the app "qb-newsjob:garage" should be open
    Given my job is "unemployed" at grade 1
    When I trigger the app action "qb-newsjob:spawn-vehicle" on "heli:1"
    Then the news garage should not have released a vehicle

  # The spawnVehicle callback checks the job name only, not duty.
  @ui @world
  Scenario: An off-duty reporter can still take the helicopter
    Given I am off duty as "news" at grade 1
    And I stand at -581.58 -930.55 36.83 facing 89.26
    And any news vehicle I take out is deleted afterwards
    When I choose "Helicopters" in the interact selector
    Then the app "qb-newsjob:garage" should be open
    When I trigger the app action "qb-newsjob:spawn-vehicle" on "heli:1"
    Then I should be piloting a news "conada"

  # Inside door: Config.Locations.inside = -77.46, -833.77, 243.38 (1.5 m box).
  # East of it is a drop to the floor below, so the tester is placed on
  # whichever side of the door has floor (stand point unverified).
  # The office (bob74_ipl FinanceOffice2) streams its collision only once the
  # player is brought in, so a direct teleport to 243.38 drops the ped about
  # 4 m below the door. Both scenarios enter through the staff door first.
  @world
  Scenario: Exit door fades a reporter back outside
    Given my job is "news" at grade 1
    And I stand at -596.65 -929.86 23.86 facing 90.0
    And I aim at -598.25 -929.86 23.86
    And I target "Enter"
    And I should arrive inside the news building
    When I face the news exit door
    And I use the news exit door
    Then I should arrive outside the news building

  # client/main.lua labels the inside door Kora.lang('text.go_outside'); it used
  # the undefined key text.exit, which showed the raw key.
  @world
  Scenario: Exit door is labelled from the locale
    Given my job is "news" at grade 1
    And I stand at -596.65 -929.86 23.86 facing 90.0
    And I aim at -598.25 -929.86 23.86
    And I target "Enter"
    And I should arrive inside the news building
    When I face the news exit door
    Then the news exit door should be labelled from the locale

  @world @rejection
  Scenario: Exit door is not offered to other jobs
    Given my job is "unemployed" at grade 1
    # The point the Enter door fades a reporter to, facing the way it leaves them.
    And I stand at -77.46 -833.77 243.38 facing 67.5
    When I aim at -77.46 -833.77 242.9
    Then no target option should be visible

  # createNewsUseable in server/main.lua and useEquipment in client/camera.lua.
  @world
  Scenario Outline: Using "<item>" as a reporter puts the prop in hand
    Given my job is "news" at grade 1
    And I hold 1 "<item>"
    And I watch for news item use on the server
    When I use my "<item>" from my inventory
    Then the server should have recorded a use of "<item>"
    And I should be holding the news prop for "<item>"

    Examples:
      | item     |
      | newsmic  |
      | newsbmic |

  # useEquipment toggles: a second use while holding removes the prop.
  @world
  Scenario: Using the hand mic twice puts it away again
    Given my job is "news" at grade 1
    And I hold 1 "newsbmic"
    When I use my "newsbmic" from my inventory
    Then I should be holding the news prop for "newsbmic"
    When I use my "newsbmic" from my inventory
    Then I should not be holding the news prop for "newsbmic"

  @world @rejection
  Scenario: Other jobs get no prop from news equipment
    Given my job is "unemployed" at grade 1
    And I hold 1 "newsmic"
    When I use my "newsmic" from my inventory
    Then I should not be holding the news prop for "newsmic"
    And I should have at least 1 "newsmic"

  # startEquipmentMonitor drops the prop as soon as the job is no longer news.
  @world
  Scenario: Leaving the news job drops the held equipment
    Given my job is "news" at grade 1
    And I hold 1 "newsmic"
    When I use my "newsmic" from my inventory
    Then I should be holding the news prop for "newsmic"
    Given my job is "unemployed" at grade 1
    Then I should not be holding the news prop for "newsmic"
