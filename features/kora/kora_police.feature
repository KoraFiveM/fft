@kora @kora_police
Feature: kora_police duty, station access, citations and impound lot
  Covers what one officer can do alone: clocking on at the duty point, the job,
  duty and rank gates on the armoury, evidence locker and fleet garage, paying a
  citation, and the impound lot dialog. Coordinates come from
  kora_police/config.lua (Mission Row) and are unverified until run live.

  Nothing here acts on another player or raises a dispatch call. While a
  scenario has the tester on duty as police, the server-wide police count is one
  higher, which other resources (robberies) read.

  Officer actions are only aimed at the tester. A citation issued that way is
  real and lands in the tester's own citations, which the fixture restores. Plate
  flags, road props and spike strips are only sent where the server must refuse
  them, because an accepted one writes a kora_mdt row or places a prop in the world.

  Background:
    Given resource "kora_police" is running

  # ----- Duty -----

  @world
  Scenario: Officer clocks on and off at the duty point
    Given I am off duty as "police" at grade 1
    And I stand at 441.5 -980.0 30.7 facing 90.0
    When I look around the police station for "Police Duty"
    And I target "Police Duty"
    Then I should see a notification containing "You are now on duty."
    And I should be on duty
    When I wait 1500 milliseconds
    And I look around the police station for "Police Duty"
    And I target "Police Duty"
    Then I should see a notification containing "You are now off duty."
    And I should be off duty

  @world @rejection
  Scenario: Duty point is hidden from other jobs
    Given my job is "mechanic" at grade 1
    And I stand at 441.5 -980.0 30.7 facing 90.0
    Then the police station should not offer "Police Duty" here

  @rejection
  Scenario: Duty command is refused for other jobs
    Given my job is "mechanic" at grade 1
    And I stand at 441.5 -980.0 30.7 facing 90.0
    When I run the command "police-duty"
    Then I should see a notification containing "You are not employed by this police service."
    And my job should be "mechanic"

  @rejection
  Scenario: Duty command is refused away from a duty point
    Given I am off duty as "police" at grade 1
    And I stand at 408.0 -1626.0 29.3 facing 230.0
    When I run the command "police-duty"
    Then I should see a notification containing "Use a police duty point to change duty status."
    And I should be off duty

  @rejection
  Scenario: Backup request is refused off duty
    Given I am off duty as "police" at grade 1
    When I run the command "backup"
    Then I should see a notification containing "You must be on duty to request backup."

  # ----- Armoury, evidence locker and fleet -----

  @world
  Scenario: On-duty cadet is offered the patrol armoury
    Given I am on duty as "police" at grade 1
    And I stand at 452.43 -980.19 30.69 facing 273.74
    Then I look around the police station for "Patrol Armory"

  @world @rejection
  Scenario: Off-duty officer is not offered the patrol armoury
    Given I am off duty as "police" at grade 1
    And I stand at 452.43 -980.19 30.69 facing 273.74
    Then the police station should not offer "Patrol Armory" here

  @world @rejection
  Scenario: Cadet is not offered the sergeant armoury
    Given I am on duty as "police" at grade 1
    And I stand at 443.8 -981.2 30.7 facing 90.0
    Then the police station should not offer "Sergeant Armory" here

  @world
  Scenario: Sergeant is offered the sergeant armoury
    Given I am on duty as "police" at grade 3
    And I stand at 443.8 -981.2 30.7 facing 90.0
    Then I look around the police station for "Sergeant Armory"

  @rejection
  Scenario Outline: Server refuses an armoury request the option would have hidden
    Given I am <duty> duty as "police" at grade 1
    And I stand at <x> <y> <z> facing 90.0
    When I ask the police server to open the armoury "<armoury>"
    Then I should see a notification containing "<reason>"

    Examples:
      | duty | x      | y       | z     | armoury            | reason                 |
      | on   | 443.8  | -981.2  | 30.7  | pd-armory-sergeant | insufficient rank      |
      | on   | 441.5  | -980.0  | 30.7  | pd-armory-patrol   | too far away           |
      | off  | 452.43 | -980.19 | 30.69 | pd-armory-patrol   | not an on-duty officer |
      | on   | 441.5  | -980.0  | 30.7  | fft-no-such-armory | unknown armory         |

  @world
  Scenario: Evidence locker is offered only on duty
    Given I am off duty as "police" at grade 1
    And I stand at 441.9 -984.5 30.7 facing 90.0
    Then the police station should not offer "Evidence Locker" here
    Given I am on duty as "police" at grade 1
    Then I look around the police station for "Evidence Locker"

  @world
  Scenario: Fleet garage offers a cruiser on duty
    Given I am on duty as "police" at grade 1
    And I stand at 454.6 -1017.7 28.7 facing 90.0
    Then I look around the police station for "Take Out Police Cruiser"

  @rejection
  Scenario: Fleet vehicle is refused away from the garage
    Given I am on duty as "police" at grade 1
    And I stand at 441.5 -980.0 30.7 facing 90.0
    When I ask the police server for fleet vehicle "POLICE01"
    Then I should see a notification containing "too far from the fleet garage"

  # ----- Citations (the tester's own) -----

  @server @rejection
  Scenario: Nothing to pay without a citation
    Given I have no unpaid police citations
    Then I should have 0 unpaid police citations
    And paying police citation 1 through the export should be refused with "You have no unpaid citations."

  @rejection
  Scenario: Citation list reports when there is nothing to pay
    Given I have no unpaid police citations
    When I run the command "citations"
    Then I should see a notification containing "You have no unpaid citations."

  Scenario: Unpaid citation is listed and paid from the bank
    Given I have 5000 in my "bank" account
    And I have an unpaid police citation of 150 for "FFT test citation"
    And I remember my "bank" balance
    Then my unpaid police citation 1 should be 150 for "FFT test citation"
    When I run the command "citations"
    Then I should see a notification containing "#1: $150 - FFT test citation"
    When I run the command "paycitation 1"
    Then I should see a notification containing "You paid citation #1 ($150)."
    And my "bank" balance should have decreased by 150
    And I should have 0 unpaid police citations

  @rejection
  Scenario: Paying an unknown citation number changes nothing
    Given I have 5000 in my "bank" account
    And I have an unpaid police citation of 150 for "FFT test citation"
    And I remember my "bank" balance
    When I run the command "paycitation 99"
    Then I should see a notification containing "No unpaid citation with that number."
    And my "bank" balance should be unchanged
    And I should have 1 unpaid police citations

  # ----- Impound lot (any player) -----

  @world @ui @rejection
  Scenario: Impound lot refuses an unknown plate without charging
    Given I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I stand at 408.0 -1626.0 29.3 facing 230.0
    When I look around the police station for "Retrieve From Mission Row Impound ($500)"
    And I target "Retrieve From Mission Row Impound ($500)"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "plate": "FFTNOPE1" }
      """
    Then I should see a notification containing "unknown vehicle"
    And my "cash" balance should be unchanged

  # ----- More citations (server/bill.lua) -----

  Scenario: Paying without a number pays the oldest citation
    Given I have 5000 in my "bank" account
    And I have an unpaid police citation 1 of 100 for "FFT first citation"
    And I have an unpaid police citation 2 of 200 for "FFT second citation"
    And I remember my "bank" balance
    When I run the command "paycitation"
    Then I should see a notification containing "You paid citation #1 ($100)."
    And my "bank" balance should have decreased by 100
    And I should have 1 unpaid police citations
    And my unpaid police citation 2 should be 200 for "FFT second citation"

  Scenario: Paying a later citation by number keeps the older one
    Given I have 5000 in my "bank" account
    And I have an unpaid police citation 1 of 100 for "FFT first citation"
    And I have an unpaid police citation 2 of 200 for "FFT second citation"
    And I remember my "bank" balance
    When I run the command "paycitation 2"
    Then I should see a notification containing "You paid citation #2 ($200)."
    And my "bank" balance should have decreased by 200
    And I should have no unpaid police citation 2
    And my unpaid police citation 1 should be 100 for "FFT first citation"

  @server
  Scenario: The pay export without a number pays the oldest citation
    Given I have 5000 in my "bank" account
    And I have an unpaid police citation 3 of 120 for "FFT older citation"
    And I have an unpaid police citation 7 of 80 for "FFT newer citation"
    And I remember my "bank" balance
    Then paying my oldest police citation through the export should succeed
    And my "bank" balance should have decreased by 120
    And I should have no unpaid police citation 3
    And my unpaid police citation 7 should be 80 for "FFT newer citation"

  Scenario: Citation list shows every citation and how to pay
    Given I have an unpaid police citation 1 of 100 for "FFT first citation"
    And I have an unpaid police citation 2 of 200 for "FFT second citation"
    When I run the command "citations"
    Then I should see a notification containing "#1: $100 - FFT first citation"
    And I should see a notification containing "#2: $200 - FFT second citation"
    And I should see a notification containing "Pay with /paycitation [number]."

  Scenario: A citation without a reason is listed without one
    Given I have an unpaid police citation of 150 without a reason
    When I run the command "citations"
    Then I should see a notification containing "#1: $150"
    And I should not see a notification containing "#1: $150 -"

  @rejection
  Scenario: A citation the bank cannot cover stays unpaid
    Given I have 0 in my "bank" account
    And I have an unpaid police citation of 150 for "FFT test citation"
    And I remember my "bank" balance
    When I run the command "paycitation 1"
    Then I should see a notification containing "insufficient funds"
    And my "bank" balance should be unchanged
    And I should have 1 unpaid police citations

  @server @rejection
  Scenario: A damaged citations record reads as no citations
    Given my police citations record is not a list
    Then I should have 0 unpaid police citations
    And paying police citation 1 through the export should be refused with "You have no unpaid citations."
    When I run the command "citations"
    Then I should see a notification containing "You have no unpaid citations."

  # ----- Issuing a citation (the tester is the only player in reach) -----

  Scenario: On-duty officer issues a citation that can be listed
    Given I am on duty as "police" at grade 1
    And I have no unpaid police citations
    When I ask the police server to fine me "250" for "FFT speeding"
    Then I should see a notification containing "Citation #1 of $250 issued."
    And I should see a notification containing "You received citation #1: $250 for FFT speeding. Type /paycitation 1 to pay it (/citations lists them)."
    And my unpaid police citation 1 should be 250 for "FFT speeding"

  Scenario: An issued citation reason is cut to 120 characters
    Given I am on duty as "police" at grade 1
    And I have no unpaid police citations
    When I ask the police server to fine me "40" for "FFT long citation reason xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    Then I should see a notification containing "Citation #1 of $40 issued."
    And my unpaid police citation 1 should have a reason of 120 characters

  Scenario: A new citation beyond the limit drops the oldest
    Given I am on duty as "police" at grade 1
    And I have 25 unpaid police citations of 10 each
    When I ask the police server to fine me "20" for "FFT over the limit"
    Then I should see a notification containing "Citation #26 of $20 issued."
    And I should have 25 unpaid police citations
    And I should have no unpaid police citation 1
    And my unpaid police citation 26 should be 20 for "FFT over the limit"

  @rejection
  Scenario Outline: The server refuses a fine of an invalid amount
    Given I am on duty as "police" at grade 1
    And I have no unpaid police citations
    When I ask the police server to fine me "<amount>" for "FFT invalid fine"
    Then I should see a notification containing "invalid fine amount"
    And I should have 0 unpaid police citations

    Examples:
      | amount |
      | 0      |
      | -5     |
      | 12.5   |
      | 100001 |
      | abc    |

  @rejection
  Scenario: The server refuses a fine from an off-duty officer
    Given I am off duty as "police" at grade 1
    And I have no unpaid police citations
    When I ask the police server to fine me "250" for "FFT off duty"
    Then I should see a notification containing "You must be an on-duty police officer to do that."
    And I should have 0 unpaid police citations

  @rejection
  Scenario: The server refuses a fine for a player who is not there
    Given I am on duty as "police" at grade 1
    When I ask the police server to fine an unknown player
    Then I should see a notification containing "That player could not be found."

  # ----- Officer actions aimed at the tester (all refused) -----

  @rejection
  Scenario Outline: An on-duty officer cannot use police actions on themselves
    Given I am on duty as "police" at grade 1
    And I remember my driver licence
    When I send the police event "<event>" with myself as the target
    Then I should see a notification containing "<reason>"
    And kora_police should not hold me in cuffs
    And my driver licence should not have been seized

    Examples:
      | event                                 | reason                    |
      | kora_police:server:cuff               | You cannot cuff yourself. |
      | kora_police:server:uncuff             | They are not cuffed.      |
      | kora_police:server:escort             | target is not cuffed      |
      | kora_police:server:deEscort           | not being escorted        |
      | kora_police:server:startDrag          | cannot drag yourself      |
      | kora_police:server:rob                | cannot rob yourself       |
      | kora_police:server:search             | target is not restrained  |
      | kora_police:server:seizeCash          | target is not restrained  |
      | kora_police:server:seizeDriverLicense | target is not restrained  |
      | kora_police:server:putInVehicle       | target is not cuffed      |
      | police:server:SetTracker              | target not found          |

  @rejection
  Scenario Outline: Officer actions are refused off duty
    Given I am off duty as "police" at grade 1
    When I send the police event "<event>" with myself as the target
    Then I should see a notification containing "<reason>"
    And kora_police should not hold me in cuffs

    Examples:
      | event                           | reason                                            |
      | kora_police:server:cuff         | You must be an on-duty police officer to do that. |
      | kora_police:server:search       | not an on-duty officer                            |
      | kora_police:server:escort       | not an on-duty officer                            |
      | kora_police:server:seizeCash    | not an on-duty officer                            |
      | kora_police:server:putInVehicle | not an on-duty officer                            |

  @rejection
  Scenario Outline: Officer actions on a player who is not there are refused
    Given I am on duty as "police" at grade 1
    When I send the police event "<event>" with no such player as the target
    Then I should see a notification containing "<reason>"

    Examples:
      | event                        | reason                          |
      | kora_police:server:cuff      | That player could not be found. |
      | kora_police:server:rob       | target not found                |
      | kora_police:server:startDrag | target not found                |

  # ----- Read-only server answers about the tester -----

  @server
  Scenario: Cuff callbacks report a free tester
    Given I am on duty as "police" at grade 1
    Then asking the police server "kora_police:server:getCuffed" should answer "false"
    And asking the police server "police:GetCuffed" should answer "false"
    And asking the police server "kora_police:server:resyncCuff" should answer "false, false"
    And asking the police server "kora_police:server:beginBreakCuffs" should answer "nil, not soft-cuffed"
    And kora_police should not hold me in cuffs

  @server
  Scenario: An on-duty officer is counted and listed
    Given I am on duty as "police" at grade 3
    Then the police server should count at least 1 officer on duty
    And the police server should list me among the on-duty officers
    And the police duty roster should show my grade as 3
    And asking the police server "police:server:IsPoliceForcePresent" should answer "true"
    And my own police status record should show me free and untracked

  @server @rejection
  Scenario: Police-only callbacks give other jobs nothing
    Given my job is "mechanic" at grade 1
    Then asking the police server "kora_police:server:getCops" should answer an empty list
    And asking the police server "police:GetImpoundedVehicles" should answer an empty list
    And asking the police server "kora_police:server:getPlayerStatus" should answer "nil"
    And asking the police server "police:IsPlateFlagged" about "FFTNOFLG" should answer "false"

  @server
  Scenario: Armoury access answers follow rank
    Given I am on duty as "police" at grade 1
    And I stand at 452.43 -980.19 30.69 facing 273.74
    Then asking the police server "kora_police:server:canAccessArmory" about "pd-armory-patrol" should answer "true"
    And asking the police server "kora_police:server:canAccessArmory" about "pd-armory-sergeant" should answer "false, insufficient rank"
    And asking the police server "kora_police:server:canAccessArmory" about "fft-no-such-armory" should answer "false, unknown armory"

  # ----- Impairment statuses -----

  @server
  Scenario: A reported impairment status is visible to the police
    Given I am on duty as "police" at grade 1
    When I report the impairment status "gunpowder" for 30 seconds
    Then I should see a notification containing "Gunpowder in clothing"
    And the police server should list my status "Gunpowder in clothing"
    When I report the impairment status "gunpowder" for 0 seconds
    Then the police server should list no status for me

  @server @rejection
  Scenario: An unknown impairment status is ignored
    Given I am on duty as "police" at grade 1
    When I report the impairment status "fft-not-a-status" for 30 seconds
    Then I should not see a notification containing "fft-not-a-status"
    And the police server should list no status for me

  # ----- Plate flags (refusals only: an accepted flag writes a kora_mdt row) -----

  @rejection
  Scenario Outline: The server refuses an invalid plate flag
    Given I am <duty> duty as "police" at grade 1
    When I ask the police server to flag plate "<plate>"
    Then I should see a notification containing "<reason>"
    And asking the police server "kora_police:server:isPlateFlagged" about "<plate>" should answer "false"

    Examples:
      | duty | plate            | reason                 |
      | on   |                  | invalid plate          |
      | on   | FFTPLATE12345678 | invalid plate          |
      | off  | FFTFLAG1         | not an on-duty officer |

  @rejection
  Scenario: Unflagging a plate that was never flagged is refused
    Given I am on duty as "police" at grade 1
    When I ask the police server to unflag plate "FFTNOFLG"
    Then I should see a notification containing "plate is not flagged"
    And asking the police server "police:server:IsPlateFlagged" about "FFTNOFLG" should answer "false"

  # ----- Road props and spike strips (refusals only: accepted ones are world props) -----

  @rejection
  Scenario Outline: The server refuses a road prop it should not place
    Given I am <duty> duty as "police" at grade 1
    And I stand at 441.5 -980.0 30.7 facing 90.0
    When I ask the police server to place a "<prop>" road prop
    Then I should see a notification containing "<reason>"

    Examples:
      | duty | prop             | reason                 |
      | off  | cone             | not an on-duty officer |
      | on   | fft-no-such-prop | unknown object type    |

  @rejection
  Scenario: Removing road props refuses when there is nothing to remove
    Given I am on duty as "police" at grade 1
    And I stand at 441.5 -980.0 30.7 facing 90.0
    When I ask the police server to remove the nearest road prop
    Then I should see a notification containing "no object nearby"
    When I ask the police server to remove road prop 1
    Then I should see a notification containing "unknown object"

  @rejection
  Scenario Outline: The server refuses a spike strip it should not deploy
    Given I am <duty> duty as "police" at grade 1
    When I ask the police server for a spike strip 20 metres ahead
    Then I should see a notification containing "<reason>"

    Examples:
      | duty | reason                               |
      | off  | not an on-duty officer               |
      | on   | deployment position is too far away  |

  @rejection
  Scenario: The server refuses a spike strip without a position
    Given I am on duty as "police" at grade 1
    When I ask the police server for a spike strip without a position
    Then I should see a notification containing "invalid coords"

  # ----- Duty and fleet edge cases -----

  @world @rejection
  Scenario: Duty cannot be toggled again straight away
    Given I am off duty as "police" at grade 1
    And I stand at 441.5 -980.0 30.7 facing 90.0
    When I run the command "police-duty"
    Then I should see a notification containing "You are now on duty."
    When I run the command "police-duty"
    Then I should see a notification containing "Wait before changing duty status again."
    And I should be on duty

  @rejection
  Scenario Outline: The server refuses a fleet vehicle request
    Given I am <duty> duty as "police" at grade 1
    And I stand at 454.6 -1017.7 28.7 facing 90.0
    When I ask the police server for fleet vehicle "<plate>"
    Then I should see a notification containing "<reason>"

    Examples:
      | duty | plate    | reason                 |
      | off  | POLICE01 | not an on-duty officer |
      | on   | POLICE99 | not a fleet vehicle    |

  @rejection
  Scenario Outline: The server refuses to store a vehicle that is not a nearby fleet car
    Given I am <duty> duty as "police" at grade 1
    And I stand at 441.5 -980.0 30.7 facing 90.0
    When I ask the police server to store fleet vehicle "<plate>"
    Then I should see a notification containing "<reason>"

    Examples:
      | duty | plate    | reason                      |
      | off  | POLICE01 | not an on-duty officer      |
      | on   | FFTNOPE1 | not a fleet vehicle         |
      | on   | POLICE01 | fleet vehicle is not nearby |

  # ----- Impound edge cases -----

  @rejection
  Scenario Outline: The server refuses an impound it cannot carry out
    Given I am <duty> duty as "police" at grade 1
    And I stand at 441.5 -980.0 30.7 facing 90.0
    When I ask the police server to impound plate "<plate>"
    Then I should see a notification containing "<reason>"

    Examples:
      | duty | plate    | reason                 |
      | off  | FFTNOPE1 | not an on-duty officer |
      | on   |          | invalid plate          |
      | on   | FFTNOPE1 | vehicle is not nearby  |

  @rejection
  Scenario Outline: The legacy impound take-out refuses without charging
    Given I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I stand at 441.5 -980.0 30.7 facing 90.0
    When I ask the police server to take plate "<plate>" out of impound lot <lot>
    Then I should see a notification containing "<reason>"
    And my "cash" balance should be unchanged

    Examples:
      | plate             | lot | reason                       |
      | FFTPLATETOOLONG17 | 1   | invalid plate                |
      | FFTNOPE1          | 99  | unknown impound lot          |
      | FFTNOPE1          | 1   | too far from the impound lot |

  # ----- Usable items -----

  @ui
  Scenario: Putting on body armour uses one vest
    Given I hold 1 "armor"
    And I remember how many "armor" I have
    And I set my armour to 0
    And I wait 500 milliseconds
    When I start putting on my "armor"
    Then a progress bar labelled "Putting on body armour..." should start
    And the progress bar should finish
    And my armour use should succeed
    And I should have 1 fewer "armor" than before
    When I wait 500 milliseconds
    Then my armour should be 50

  @rejection
  Scenario: Body armour is kept when already fully armoured
    Given I hold 1 "armor"
    And I remember how many "armor" I have
    And I set my armour to 100
    And I wait 500 milliseconds
    Then putting on my "armor" now should be refused
    And I should see a notification containing "You are already wearing enough armour."
    And I should have 0 fewer "armor" than before
    And my armour should be 100

  Scenario: A moneybag is paid out as cash
    Given I have 0 in my "cash" account
    And I hold a moneybag worth 250
    And I remember my "cash" balance
    Then using my moneybag should succeed
    And I should see a notification containing "You deposited $250 in cash."
    And my "cash" balance should have increased by 250
    And I should have no "moneybag"

  @rejection
  Scenario: An empty moneybag pays nothing and is kept
    Given I have 0 in my "cash" account
    And I hold a moneybag worth 0
    And I remember my "cash" balance
    Then using my moneybag should be refused
    And my "cash" balance should be unchanged
    And I should have at least 1 "moneybag"

  # ----- Security cameras and legacy client events -----

  @rejection
  Scenario: An unknown security camera is refused
    Given I am on duty as "police" at grade 1
    And I wait 1000 milliseconds
    When I ask to view security camera 999
    Then I should see a notification containing "Camera does not exist."

  @rejection
  Scenario: An offline security camera is refused
    Given I am on duty as "police" at grade 1
    And every security camera is offline on my client
    And I wait 1000 milliseconds
    When I ask to view security camera 1
    Then I should see a notification containing "Pacific Bank CAM#1 is offline."

  @rejection
  Scenario: Security cameras are not opened off duty
    Given I am off duty as "police" at grade 1
    And I wait 1000 milliseconds
    When I ask to view security camera 999
    Then I should not see a notification containing "Camera does not exist."

  @rejection
  Scenario Outline: Legacy client events that would bypass the server are refused
    When a script sends me the legacy police event "<event>"
    Then I should see a notification containing "<event> is not supported by kora_police."
    And kora_police should not hold me in cuffs

    Examples:
      | event                     |
      | police:client:GetCuffed   |
      | police:client:SendToJail  |
      | police:client:PutInVehicle |

  # Ballistic evidence and legacy handcuff exports. Refusals and unknown ids
  # only: a created casing is a durable row that no export deletes.

  @server @rejection
  Scenario: Ballistic casing lookups refuse a malformed id and find nothing for an unknown one
    Then looking up the ballistic casing "fft_no_such_casing" should find nothing
    And looking up the ballistic casing "" should find nothing
    And looking up a ballistic casing id of 65 characters should be refused as an invalid case id

  @server @rejection
  Scenario: A ballistic casing is not created without a complete round record
    Then creating a ballistic casing from no round record should find nothing
    And creating a ballistic casing from a round missing its weapon serial should find nothing

  Scenario: The legacy and upstream handcuff exports always agree
    Then the handcuff exports should agree
