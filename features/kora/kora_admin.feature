@kora @kora_admin
Feature: kora_admin permission gates and self-service commands
  kora_admin resolves each player to a staff role and gates every command on
  it. The tester's role is whatever this server has configured and these
  scenarios never change it. Scenarios that depend on it first learn the role
  through the resource's own level sync, then assert what the server must do
  for that role: the action for staff, the refusal for everyone else. Run the
  suite once as a plain player and once as a moderator to see both sides.

  Only the tester is targeted and only reversible, self-only effects are used:
  duty, freeze, god mode, invisibility and development mode are switched twice
  and end where they started; armour, health, needs, money, items, gang, job
  duty and position are put back afterwards; a spawned vehicle or entity is
  deleted again; a temporary Moderator grant to an admin tester is revoked.
  Validation scenarios use inputs the command refuses before it acts.

  Outcomes judged on the server for admin-only commands (money, items, gang)
  use kora_admin's canEditConfig export as the admin oracle; it matches while
  Config.configEditor.level is 'admin' (the shipped default).

  Side effects for staff testers: opening the admin menu records report
  delivery receipts in admin_report_reads, and every successful staff command
  appends its normal row to admin_logs (sethunger, givemoney, giveitem, car,
  dv, entity, granttempaccess and the like). No report is created, changed,
  claimed or answered. Spawning a vehicle grants the tester keys for its
  random plate in kora_vehiclekeys.

  Assumes the shipped config: moderation.blockSelfTarget true, dv.nearestRadius
  above 0, developer.requireDevMode false, permissions.mode ace_discord, money
  tax off for crypto (crypto is never taxed by default).

  Not covered: commands that act on another player (only unknown ids are used,
  which every command refuses before acting), kick and ban (a missed self-block
  would remove the tester), kill, revive, selfrevive, health, announcements,
  weather and time changes, resource restarts, permission grants, clearing the
  inventory, givevehicle (writes a garage row), noclip (no readable state),
  coords and vec4 (clipboard), the config editor, the reports screens and menu
  actions, and creating, replying to, claiming or closing real reports.

  Background:
    Given resource "kora_admin" is running

  @server @rejection
  Scenario: Temporary access cannot be granted outside the playground
    Then the playground access bridge should refuse to grant me temporary access

  @server @rejection
  Scenario: Temporary access cannot be revoked outside the playground
    Then the playground access bridge should refuse to revoke my temporary access

  Scenario: The server reports my staff level as a configured role
    When I learn my staff level

  Scenario: Permission lookup answers staff and refuses players
    Given I learn my staff level
    Then asking for my own permission level should report it to staff only

  Scenario: Server info is listed to staff and refused to players
    Given I learn my staff level
    Then asking for the server info should list it to staff only

  Scenario: Admin duty toggles for staff and is refused to players
    Given I remember my admin duty status
    And I learn my staff level
    When I toggle admin duty with the staff command
    And I toggle admin duty with the staff command
    Then my admin duty status should be back to what it was

  Scenario: Self armour is set for staff and refused to players
    Given I learn my staff level
    Then setting my own armour to 37 should work for staff only

  Scenario: Admin menu opens for support staff and explains the refusal to players
    Given I learn my staff level
    Then opening the admin menu should work for support staff only

  # reportstatus takes a numeric id; a non-numeric one is refused before any query.
  @rejection
  Scenario: Status of an unknown report is refused
    When I run the command "reportstatus fft_no_report"
    Then I should see a notification containing "report not found"

  # kora_lib refuses the command before the handler runs, so no report is created.
  @rejection
  Scenario: A report without a category and message is refused
    When I run the command "report"
    Then I should see a notification containing "Missing arguments for /report"

  # ---------------------------------------------------------------------------
  # Command registry: the gate each command is registered behind
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: kora_admin registers /<command> behind the <gate> gate
    Then kora_admin should register the command "<command>" behind the "<gate>" gate

    Examples:
      | command          | gate    |
      | admin            | support |
      | players          | support |
      | reportclaim      | support |
      | reportresolve    | support |
      | aduty            | mod     |
      | goto             | mod     |
      | kick             | mod     |
      | fix              | mod     |
      | setduty          | mod     |
      | noclip           | admin   |
      | ban              | admin   |
      | car              | admin   |
      | givemoney        | admin   |
      | devzone          | admin   |
      | granttempaccess  | admin   |
      | restartresource  | god     |
      | setpermission    | god     |
      | report           | user    |
      | reportstatus     | user    |

  # ---------------------------------------------------------------------------
  # Validation: each command refuses bad input before acting. Players below the
  # gate get the generic refusal instead, because the gate is checked first.
  # ---------------------------------------------------------------------------

  @rejection
  Scenario Outline: Moderator command "/<command>" is refused before it acts
    Given I learn my staff level
    Then the admin command "<command>" should answer "<answer>" to "moderator" staff and be refused to everyone else

    Examples:
      | command                                     | answer                      |
      | goto me                                     | cannot goto yourself        |
      | bring me                                    | cannot bring yourself       |
      | spectate me                                 | cannot spectate yourself    |
      | warn me fft check                           | you cannot warn yourself    |
      | warn me                                     | Missing arguments for /warn |
      | goto 999999                                 | that player is not online   |
      | kick 999999                                 | that player is not online   |
      | kill 999999                                 | that player is not online   |
      | sendback 999999                             | that player is not online   |
      | warnings 999999                             | that player is not online   |
      | permission fft_nobody_has_this_name         | no matching player found    |
      | freeze me maybe                             | state must be on or off     |
      | god me maybe                                | state must be on or off     |
      | invisible me maybe                          | state must be on or off     |
      | devmode me maybe                            | state must be on or off     |
      | setduty me maybe                            | state must be on or off     |
      | tpcoords abc                                | use x y z                   |
      | tpcoords 1 2                                | use x y z                   |
      | tpcoords 1 2 3 4 5                          | use x y z                   |
      | tpcoords 1 2 nan                            | use x y z                   |
      | tpcoords vec3(1, 2)                         | use x y z                   |
      | spectate                                    | Stopped spectating          |

  @rejection
  Scenario: Repairing a vehicle on foot is refused
    Given I am on foot
    And I learn my staff level
    Then the admin command "fix" should answer "you are not in a vehicle" to "moderator" staff and be refused to everyone else

  @rejection
  Scenario Outline: Support command "/<command>" is refused before it acts
    Given I learn my staff level
    Then the admin command "<command>" should answer "<answer>" to "support" staff and be refused to everyone else

    Examples:
      | command                              | answer                             |
      | players fft_nobody_has_this_name     | no players matched                 |
      | reportclaim fft_no_report            | report not found                   |
      | reportresolve fft_no_report          | report not found                   |
      | reportdismiss 0                      | report not found                   |
      | reportreopen -3                      | report not found                   |
      | reportclaim                          | Missing arguments for /reportclaim |

  @rejection
  Scenario Outline: Admin command "/<command>" is refused before it acts
    Given I learn my staff level
    Then the admin command "<command>" should answer "<answer>" to "admin" staff and be refused to everyone else

    Examples:
      | command                                 | answer                                  |
      | sethunger me 101                        | Hunger must be between 0 and 100        |
      | setthirst me -1                         | Thirst must be between 0 and 100        |
      | sethunger me lots                       | Hunger must be between 0 and 100        |
      | sethunger me                            | Missing arguments for /sethunger        |
      | givemoney me crypto                     | account and amount are required         |
      | givemoney me crypto 0                   | amount must be positive                 |
      | removemoney me crypto -5                | account and amount are required         |
      | setmoney me crypto abc                  | account and amount are required         |
      | givemoney me fft_no_account 5           | invalid account                         |
      | giveitem me                             | item name required                      |
      | giveitem me water_bottle 0              | amount must be a positive whole number  |
      | giveitem me water_bottle 1.5            | amount must be a positive whole number  |
      | giveitem me water_bottle 1 5            | item metadata must decode to an object  |
      | removeitem me                           | item name required                      |
      | removeitem me water_bottle -1           | amount must be a positive whole number  |
      | setjob me                               | job name required                       |
      | setjob me fft_no_such_job               | unknown job                             |
      | setgang me                              | gang name required                      |
      | setgang me fft_no_such_gang             | unknown gang                            |
      | time 24                                 | hour must be a whole number from 0-23   |
      | time 7.5                                | hour must be a whole number from 0-23   |
      | time dusk                               | or one of: morning, noon, night         |
      | time 12 60                              | minute must be a whole number from 0-59 |
      | announce                                | Missing arguments for /announce         |
      | weather                                 | Missing arguments for /weather          |
      | entity fft_no_such_model                | unknown ped or prop model               |
      | entity sultan                           | use /car or /veh for vehicle models     |
      | car fft_no_such_model                   | unknown vehicle model                   |
      | car bad-model                           | unknown vehicle model                   |
      | veh 999999 sultan                       | that player is not online               |
      | givevehicle me sultan bad-plate         | plate must be 1-15 letters or numbers   |
      | givevehicle me sultan ABCDEFGHIJKLMNOP  | plate must be 1-15 letters or numbers   |
      | dv abc                                  | radius must be a positive number        |
      | dv 0                                    | radius must be a positive number        |
      | dv -3                                   | radius must be a positive number        |
      | devzone triangle                        | zone type must be box, sphere, or poly  |
      | devplacement bad!                       | model must be a model name or numeric   |
      | adminlog fft_no_such_action             | no matching log entries                 |
      | unban fft_no_such_license               | no active ban matched                   |
      | clothingmenu 999999                     | that player is not online               |
      | entityfor 999999 prop_bench_01a         | that player is not online               |
      | granttempaccess me owner 5              | that temporary role cannot be granted   |
      | granttempaccess me user 5               | that temporary role cannot be granted   |
      | granttempaccess me moderator 0          | duration must be 1-1440 minutes         |
      | granttempaccess me moderator 1441       | duration must be 1-1440 minutes         |
      | revoketempaccess me owner               | that temporary role cannot be revoked   |

  @rejection
  Scenario Outline: Owner command "/<command>" is refused before it acts
    Given I learn my staff level
    Then the admin command "<command>" should answer "<answer>" to "owner" staff and be refused to everyone else

    Examples:
      | command                               | answer                   |
      | restartresource bad!name              | invalid resource name    |
      | restartresource fft_no_such_resource  | no such resource         |
      | setpermission me bogus                | invalid permission level |
      | setpermission me user                 | invalid permission level |
      | revokepermission me bogus             | invalid permission level |

  # Player report commands are open to everyone; these inputs never reach the
  # report table (an unknown type, a missing message or an id that is not a
  # positive whole number).
  @rejection
  Scenario Outline: Report command "/<command>" is refused for every player
    Given I learn my staff level
    Then the admin command "<command>" should answer "<answer>" to "user" staff and be refused to everyone else

    Examples:
      | command                             | answer                        |
      | report fft_bogus_type fft check     | invalid report type           |
      | report bug                          | Missing arguments for /report |
      | reportstatus 0                      | report not found              |
      | reportstatus -3                     | report not found              |
      | reportstatus 1.5                    | report not found              |
      | reportreply fft_no_report hello     | report not found              |

  # ---------------------------------------------------------------------------
  # Self-only round trips
  # ---------------------------------------------------------------------------

  Scenario Outline: Setting my <need> to <value> works for admin staff only
    Given my metadata "<need>" is 50
    And I learn my staff level
    Then setting my "<need>" to "<value>" with the admin command should work for admin staff only

    Examples:
      | need   | value |
      | hunger | 37    |
      | thirst | 0     |
      | hunger | 100   |
      | thirst | 12.5  |

  Scenario: A needs change is listed in the audit log for admin staff
    Given my metadata "hunger" is 50
    And I learn my staff level
    When setting my "hunger" to "41" with the admin command should work for admin staff only
    Then the audit log should list my latest "sethunger" with "41}" for admin staff only

  Scenario: Healing myself restores health and needs for moderators only
    Given my metadata "hunger" is 20
    And my metadata "thirst" is 30
    And I learn my staff level
    Then healing myself should restore my health and needs for moderators only

  Scenario: Armour without a value is filled for staff only
    Given I learn my staff level
    Then setting my own armour without a value should fill it for staff only

  Scenario Outline: Toggling <toggle> twice ends where it started
    Given I learn my staff level
    Then toggling "<toggle>" twice for myself should switch it and switch it back for moderators only

    Examples:
      | toggle    |
      | freeze    |
      | god       |
      | invisible |
      | devmode   |

  Scenario: Job duty is switched off and on again by moderators only
    Given I am on duty as "taxi" at grade 1
    And I learn my staff level
    When the admin command "setduty me off" should answer "is now off duty" to "moderator" staff and be refused to everyone else
    Then my job duty should be "off" for moderator staff and "on" otherwise
    When the admin command "setduty me on" should answer "is now on duty" to "moderator" staff and be refused to everyone else
    Then my job duty should be "on" for moderator staff and "on" otherwise

  Scenario Outline: Teleporting with <form> coordinates and back works for moderators only
    Given I learn my staff level
    Then teleporting 3 metres east with "<form>" coordinates and back should work for moderators only

    Examples:
      | form    |
      | plain   |
      | comma   |
      | vec3    |
      | vector4 |

  @rejection
  Scenario: Teleporting to a missing waypoint is refused
    Given I learn my staff level
    Then teleporting to my waypoint without one should be refused for moderators only

  Scenario: A damaged vehicle is repaired by moderators only
    Given I am driving a temporary "blista"
    And I learn my staff level
    Then repairing my damaged vehicle with the admin command should work for moderators only

  Scenario: A spawned vehicle seats me and is deleted again for admin staff only
    Given I am on foot
    And I learn my staff level
    Then spawning a "sultan" with the admin command and deleting it again should work for admin staff only

  Scenario: A spawned prop is deleted once and only once for admin staff
    Given I learn my staff level
    Then spawning a "prop_bench_01a" entity and deleting it should work for admin staff only

  Scenario Outline: Money command "/<command>" changes my crypto for admin staff only
    Given I have 1000 in my "crypto" account
    And I remember my "crypto" balance
    And I learn my staff level
    When the admin command "<command>" should answer "<answer>" to "admin" staff and be refused to everyone else
    Then my "crypto" balance should <outcome>

    Examples:
      | command                             | answer                                          | outcome                                                      |
      | givemoney me crypto 250             | givemoney 250 crypto (admin:givemoney) for      | have grown by 250 for admin staff and be unchanged otherwise |
      | givemoney me crypto 5 fft audit note| givemoney 5 crypto (fft audit note) for         | have grown by 5 for admin staff and be unchanged otherwise   |
      | removemoney me crypto 400           | removemoney 400 crypto (admin:removemoney) for  | have shrunk by 400 for admin staff and be unchanged otherwise|
      | setmoney me crypto 777              | setmoney 777 crypto (admin:setmoney) for        | be 777 for admin staff and unchanged otherwise               |

  @rejection
  Scenario: Removing more money than I hold is refused and changes nothing
    Given I have 100 in my "crypto" account
    And I remember my "crypto" balance
    And I learn my staff level
    When the admin command "removemoney me crypto 500" should answer "insufficient funds" to "admin" staff and be refused to everyone else
    Then my "crypto" balance should be unchanged

  Scenario: Giving myself an item works for admin staff only
    Given my "water_bottle" count is put back when the scenario ends
    And I remember how many "water_bottle" I have
    And I learn my staff level
    When the admin command "giveitem me water_bottle 2" should answer "Gave 2 x water_bottle to" to "admin" staff and be refused to everyone else
    Then I should have 2 more "water_bottle" for admin staff and the same number otherwise

  Scenario: Removing an item from myself works for admin staff only
    Given I hold 3 extra "water_bottle" until the scenario ends
    And I remember how many "water_bottle" I have
    And I learn my staff level
    When the admin command "removeitem me water_bottle 2" should answer "Removed 2 x water_bottle from" to "admin" staff and be refused to everyone else
    Then I should have 2 fewer "water_bottle" for admin staff and the same number otherwise

  Scenario: Changing my gang grade works for admin staff only
    Given my gang is "ballas" at grade 1
    And I learn my staff level
    When the admin command "setgang me ballas 2" should answer "'s gang to ballas" to "admin" staff and be refused to everyone else
    Then my gang should be "ballas" at grade 2 for admin staff and grade 1 otherwise

  Scenario: An admin's temporary Moderator grant on themselves changes nothing and is revoked
    Given I learn my staff level
    Then granting and revoking myself temporary moderator access should leave my level unchanged for admin staff only

  # Discord exports. dispatch is refused for any caller but kora_admin itself, and
  # the settings publish exactly three keys, none of them the bot token.
  @server @rejection
  Scenario: The Discord dispatch export refuses a call from another resource
    Then the Discord dispatch export should refuse a call from fft

  @server
  Scenario: The Discord settings publish only an enabled flag and public identifiers
    Then the Discord settings should publish only an enabled flag and public identifiers
