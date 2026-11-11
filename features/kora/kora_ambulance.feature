@kora @kora_ambulance
Feature: kora_ambulance hospital care, EMS duty and first-aid guards
  Injured players check in at a hospital desk, rest in a bed for 15 seconds
  and are billed 250 (cash first, then bank). EMS staff toggle duty at the
  hospital duty point. Everything runs at Pillbox ("pillbox"). The injury is a
  fixture: the tester's own health is lowered by a few points without a damage
  event, and restored in cleanup. Care sessions are asserted through the
  resource's own server events, the getPatientStatus export and money.

  Real wounds are opened with a small self-inflicted hit (ApplyDamageToPed),
  which the resource's own damage correlator reports; they are closed by
  restoring health and by the fullRevive export. Legacy qb-ambulancejob events
  are fired from the tester's client as any resource could.

  Not covered: anything that needs the tester downed or dead (laststand,
  /respawn, the alert key, death check-in) because going down raises an
  automatic EMS dispatch call; revive, CPR, treating another player, stretcher
  and carry (they act on another player or run a minigame); duty vehicle
  checkout (server-created vehicle); the pharmacy purchase (kora_inventory
  shop UI). /911e, /housecall and painkillers are covered but have in-memory
  cooldowns with no reset, so those scenarios cannot be re-run back to back.

  Background:
    Given resource "kora_ambulance" is running

  # Zone options resolve from the camera ray's hit point, which must lie inside
  # the zone and within the option distance (2.5 m) of the ped. The check-in
  # sphere is Config.hospitals[1].checkIn 307.1 -595.1 43.3 radius 3 and the duty
  # sphere 308.0 -595.0 43.2 radius 2 (shared/hospital_menu.lua); both centres
  # are at standing height, so scenarios aim at the floor (z 42.4) between the
  # tester and the desk. 308.0 -596.0 is on top of the desk (the tester ends
  # up at z 44.2), so duty targeting stands on the lobby floor instead.
  # Config.hospitalCare.requireInjury = true.
  @world @rejection
  Scenario: A healthy player is refused hospital care
    Given I am in full health
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then I should see a notification containing "you do not need hospital care"
    And no hospital check-in should have been recorded for me
    And my "cash" balance should be unchanged

  # Config.hospitalCare.duration = 15000, Config.billing.checkInCost = 250.
  @world @slow
  Scenario: An injured player is treated in a bed and billed
    Given I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I am hurt by 30 health points
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then I should see a notification containing "Resting in your assigned bed"
    And my hospital check-in at "pillbox" should have been recorded
    When I wait 12000 milliseconds
    Then I should see a notification containing "Care completed"
    And my hospital bed should have been released with the reason "completed"
    And my hospital care should have been completed for 250
    And my "cash" balance should have decreased by 250
    And I should be back at full health
    And my patient status should be "alive"
    And I should have no open wounds

  @world
  Scenario: Leaving the bed early ends care without a bill
    Given I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I am hurt by 30 health points
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then my hospital check-in at "pillbox" should have been recorded
    When I wait 2000 milliseconds
    And I press the hospital leave bed key
    Then my hospital bed should have been released with the reason "left-bed"
    And no hospital care should have been completed for me
    And my "cash" balance should be unchanged

  @world
  Scenario: The check-in desk offers care to anyone
    Given my job is "unemployed" at grade 1
    And I stand at 306.3 -595.9 43.3 facing 315.0
    When I aim at 306.9 -595.4 42.4
    Then the target option "Check In for Care" should be visible

  @world
  Scenario: The pharmacy counter offers its shop
    Given I stand at 316.4 -595.7 43.3 facing 0.0
    When I aim at 316.4 -594.7 43.3
    Then the target option "Browse Pharmacy" should be visible

  @world
  Scenario: The duty point offers the duty toggle to EMS staff
    Given I am off duty as "ambulance" at grade 1
    And I stand at 306.3 -595.9 43.3 facing 300.0
    When I aim at 307.3 -595.4 42.4
    Then the target option "Toggle Duty" should be visible

  # The server requires the player within 3 m of a hospital duty point.
  @world
  Scenario: EMS staff go on duty at the hospital duty point
    Given I am off duty as "ambulance" at grade 1
    And I stand at 308.0 -596.0 43.2 facing 0.0
    And I wait 1000 milliseconds
    When I run the command "ems-duty"
    Then I should see a notification containing "You are now on duty."
    And I should be on duty

  @world @rejection
  Scenario: Duty cannot be changed away from a duty point
    Given I am off duty as "ambulance" at grade 1
    And I stand at 316.4 -595.7 43.3 facing 0.0
    And I wait 1000 milliseconds
    When I run the command "ems-duty"
    Then I should see a notification containing "Use a hospital duty point to change duty status."
    And I should be off duty

  @world @rejection
  Scenario: A civilian cannot use the EMS duty command
    Given my job is "unemployed" at grade 1
    And I stand at 308.0 -596.0 43.2 facing 0.0
    And I wait 1000 milliseconds
    When I run the command "ems-duty"
    Then I should see a notification containing "You are not employed as EMS."
    And my job should be "unemployed"

  @server @rejection
  Scenario Outline: First-aid items are kept when there is no wound to treat
    Given I am in full health
    And I should have no open wounds
    And I hold 1 "<item>"
    And I remember how many "<item>" I have
    When I use my "<item>" for first aid
    Then I should see a notification containing "<refusal>"
    And I should have 0 fewer "<item>" than before

    Examples:
      | item    | refusal                      |
      | bandage | No wound a bandage can treat |
      | ifak    | No open wound to treat       |

  @rejection
  Scenario: The house-call queue is closed to civilians
    Given my job is "unemployed" at grade 1
    When I run the command "housecalls"
    Then I should see a notification containing "EMS only."

  @rejection
  Scenario: An off-duty medic cannot accept a house call
    Given I am off duty as "ambulance" at grade 1
    When I run the command "accepthousecall 999999"
    Then I should see a notification containing "You must be on-duty EMS."

  @rejection
  Scenario: An unknown house call cannot be accepted
    Given I am on duty as "ambulance" at grade 1
    When I run the command "accepthousecall 999999"
    Then I should see a notification containing "That request is no longer available."

  # ---------------------------------------------------------------------------
  # Hospital check-in: edges, billing, the legacy bed events, Sandy Shores
  # ---------------------------------------------------------------------------

  # Billing.charge (server/billing.lua): cash first, capped at what is there;
  # the bank carries the remainder. It also sends the legacy bill notice.
  @world @slow
  Scenario Outline: Hospital care is billed from cash first and the bank covers the rest
    Given I have <cash> in my "cash" account
    And I have 1000 in my "bank" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    And I watch my hospital care events
    And I watch my hospital bills
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I am hurt by 30 health points
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then my hospital check-in at "pillbox" should have been recorded
    When I wait 12000 milliseconds
    Then my hospital care should have been completed for 250
    And I should have been billed 250
    And I should see a notification containing "You were billed $250."
    And my "cash" balance should have decreased by <fromCash>
    And my "bank" balance should have decreased by <fromBank>

    Examples:
      | cash | fromCash | fromBank |
      | 250  | 250      | 0        |
      | 100  | 100      | 150      |
      | 0    | 0        | 250      |

  # Config.injuries.healthTolerance = 5: five points below max still counts as healthy.
  @world @rejection
  Scenario: Five points of damage is not enough to need hospital care
    Given I am in full health
    And I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I take 5 damage
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then I should see a notification containing "you do not need hospital care"
    And no hospital check-in should have been recorded for me

  @world
  Scenario: Six points of damage is enough to be given a bed
    Given I am in full health
    And I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I take 6 damage
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then my hospital check-in at "pillbox" should have been recorded
    When I press the hospital leave bed key
    Then my hospital bed should have been released with the reason "left-bed"

  # client/hospital.lua refuses a second check-in while a bed is reserved.
  @world @rejection
  Scenario: A patient with a reserved bed cannot check in again
    Given I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I am hurt by 30 health points
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then my hospital check-in at "pillbox" should have been recorded
    When I stand at 306.3 -595.9 43.3 facing 315.0
    And I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then I should see a notification containing "You already have a bed reserved."
    And only one hospital check-in should have been recorded for me
    When I press the hospital leave bed key
    Then my hospital bed should have been released with the reason "left-bed"
    And my "cash" balance should be unchanged

  # Leaving early skips Hospital.completeBedCare, the only place the wounds close.
  @world
  Scenario: Leaving the bed early leaves a real wound open
    Given I am in full health
    And I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I take 25 damage
    And I should have an open wound of tier 3 or 4
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then my hospital check-in at "pillbox" should have been recorded
    When I press the hospital leave bed key
    Then my hospital bed should have been released with the reason "left-bed"
    And my open wound should still be listed

  # server/compat/hospital.lua: SendToBed only works within
  # Config.hospitalCare.interactionRange (3 m) of a check-in point.
  @world @rejection
  Scenario: The legacy bed request is refused away from a check-in desk
    Given I watch my hospital care events
    And I stand at 316.4 -595.7 43.3 facing 0.0
    And I am hurt by 30 health points
    When I send the legacy hospital event "SendToBed" with 1
    Then I should see a notification containing "Use a hospital check-in desk."
    And no hospital check-in should have been recorded for me

  @world @rejection
  Scenario: The legacy bed request still refuses a healthy player
    Given I am in full health
    And I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    When I send the legacy hospital event "SendToBed" with 1
    Then I should see a notification containing "you do not need hospital care"
    And no hospital check-in should have been recorded for me

  # A legacy bed index is never trusted: the server picks the first free bed.
  @world
  Scenario: The legacy bed request at Sandy Shores ignores the bed index
    Given I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I watch my hospital care events
    And I stand at 1839.5 3672.9 34.3 facing 130.0
    And I am hurt by 30 health points
    When I send the legacy hospital event "SendToBed" with 99
    Then my hospital check-in at "sandy" should have been recorded
    And I should see a notification containing "Resting in your assigned bed"
    When I wait 1000 milliseconds
    And I press the hospital leave bed key
    Then my hospital bed should have been released with the reason "left-bed"
    And no hospital care should have been completed for me
    And my "cash" balance should be unchanged

  @world
  Scenario: The legacy leave bed server event releases the bed
    Given I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I am hurt by 30 health points
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then my hospital check-in at "pillbox" should have been recorded
    When I send the legacy hospital event "LeaveBed"
    Then my hospital bed should have been released with the reason "left-bed"
    And no hospital care should have been completed for me
    And my "cash" balance should be unchanged

  # client/compat.lua forwards hospital:client:leaveBed to the server so a
  # third-party resource can release the bed like the leave key does.
  @world
  Scenario: The legacy leave bed client event releases the bed
    Given I watch my hospital care events
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I am hurt by 30 health points
    When I aim at 306.9 -595.4 42.4
    And I target "Check In for Care"
    Then my hospital check-in at "pillbox" should have been recorded
    When a resource fires the legacy client leave bed event
    Then my hospital bed should have been released with the reason "left-bed"

  # ---------------------------------------------------------------------------
  # Duty: round trips, rate limit, Sandy Shores, legacy events, target options
  # ---------------------------------------------------------------------------

  @world
  Scenario: EMS duty toggles on and off again and the on-duty count follows
    Given I am off duty as "ambulance" at grade 1
    And I stand at 308.0 -596.0 43.2 facing 0.0
    And I remember the on-duty EMS count
    And I wait 1000 milliseconds
    When I run the command "ems-duty"
    Then I should see a notification containing "You are now on duty."
    And I should be on duty
    And the on-duty EMS count should have increased by 1
    When I wait 1200 milliseconds
    And I run the command "ems-duty"
    Then I should see a notification containing "You are now off duty."
    And I should be off duty
    And the on-duty EMS count should be back to what it was

  # server/duty.lua Duty.setDuty: one change per 1000 ms.
  @world @rejection
  Scenario: Duty cannot be changed twice within a second
    Given I am off duty as "ambulance" at grade 1
    And I stand at 308.0 -596.0 43.2 facing 0.0
    And I wait 1000 milliseconds
    When I run the command "ems-duty"
    Then I should see a notification containing "You are now on duty."
    When I run the command "ems-duty"
    Then I should see a notification containing "Wait before changing duty status again."
    And I should be on duty

  # Any configured duty point counts (3 m); the Sandy duty point is 1.9 m from
  # the Sandy pharmacy point.
  @world
  Scenario: EMS staff go on duty at the Sandy Shores duty point
    Given I am off duty as "ambulance" at grade 1
    And I stand at 1836.9 3674.4 34.6 facing 320.0
    And I wait 1000 milliseconds
    When I run the command "ems-duty"
    Then I should see a notification containing "You are now on duty."
    And I should be on duty

  # hospital:server:AddDoctor / RemoveDoctor delegate to Duty.setDuty.
  @world
  Scenario: The legacy doctor events change duty only at a duty point
    Given I am off duty as "ambulance" at grade 1
    And I stand at 308.0 -596.0 43.2 facing 0.0
    And I wait 1000 milliseconds
    When I send the legacy hospital event "AddDoctor"
    And I wait 500 milliseconds
    Then I should be on duty
    When I wait 1000 milliseconds
    And I send the legacy hospital event "RemoveDoctor"
    And I wait 500 milliseconds
    Then I should be off duty

  @world @rejection
  Scenario: The legacy doctor event is refused away from a duty point
    Given I am off duty as "ambulance" at grade 1
    And I stand at 316.4 -595.7 43.3 facing 0.0
    And I wait 1000 milliseconds
    When I send the legacy hospital event "AddDoctor"
    And I wait 1000 milliseconds
    Then I should be off duty

  @world @rejection
  Scenario: The legacy doctor event does not employ a civilian
    Given my job is "unemployed" at grade 1
    And I stand at 308.0 -596.0 43.2 facing 0.0
    And I wait 1000 milliseconds
    When I send the legacy hospital event "AddDoctor"
    And I wait 1000 milliseconds
    Then my job should be "unemployed"

  # The duty zone overlaps the check-in zone; "Toggle Duty" is EMS only.
  @world
  Scenario Outline: The duty point offers the duty toggle only to EMS staff
    Given my job is "<job>" at grade 1
    And I stand at 306.3 -595.9 43.3 facing 300.0
    When I aim at 307.3 -595.4 42.4
    Then the hovered target should offer <options> options

    Examples:
      | job        | options |
      | unemployed | 1       |
      | ambulance  | 2       |

  @world
  Scenario: The EMS stash is offered to EMS staff
    Given I am off duty as "ambulance" at grade 1
    And I stand at 308.6 -597.8 43.3 facing 160.0
    When I aim at 308.6 -598.8 43.3
    Then the target option "EMS Stash" should be visible

  @world @rejection
  Scenario: The EMS stash is hidden from civilians
    Given my job is "unemployed" at grade 1
    And I stand at 308.6 -597.8 43.3 facing 160.0
    When I aim at 308.6 -598.8 43.3
    Then no target option should be visible

  # client/duty.lua: three vehicles and "Return Vehicle", all on-duty only.
  @world
  Scenario: The duty garage offers the fleet to on-duty EMS only
    Given I am on duty as "ambulance" at grade 1
    And I stand at 296.5 -583.5 43.2 facing 90.0
    When I aim at 294.5 -583.5 43.2
    Then the hovered target should offer 4 options

  @world @rejection
  Scenario: The duty garage offers nothing to off-duty EMS
    Given I am off duty as "ambulance" at grade 1
    And I stand at 296.5 -583.5 43.2 facing 90.0
    When I aim at 294.5 -583.5 43.2
    Then no target option should be visible

  # ---------------------------------------------------------------------------
  # Items: real wounds treated, first aid kit, painkillers, defibrillator
  # ---------------------------------------------------------------------------

  # 5 damage is tier 1, or 2 on a vital part; a bandage treats up to tier 2.
  @world
  Scenario: A bandage closes a light wound
    Given I am in full health
    And I hold 1 "bandage"
    And I remember how many "bandage" I have
    And I take 5 damage
    And I should have an open wound of tier 1 or 2
    When I use my "bandage" for first aid
    Then I should see a notification containing "Treated a wound ("
    And I should have 1 fewer "bandage" than before
    And I should have no open wounds

  # 25 damage is tier 3, or 4 on a vital part.
  @world @rejection
  Scenario: A bandage cannot treat a severe wound
    Given I am in full health
    And I hold 1 "bandage"
    And I remember how many "bandage" I have
    And I take 25 damage
    And I should have an open wound of tier 3 or 4
    When I use my "bandage" for first aid
    Then I should see a notification containing "No wound a bandage can treat"
    And I should have 0 fewer "bandage" than before
    And my open wound should still be listed

  @world
  Scenario Outline: An IFAK closes a severe wound
    Given I am in full health
    And I hold 1 "<item>"
    And I remember how many "<item>" I have
    And I take 25 damage
    And I should have an open wound of tier 3 or 4
    When I use my "<item>" for first aid
    Then I should see a notification containing "Treated a wound ("
    And I should have 1 fewer "<item>" than before
    And I should have no open wounds

    Examples:
      | item  |
      | ifak  |
      | ifaks |

  # Config.firstaid: consumed, full health, every wound closed.
  @world
  Scenario: A first aid kit patches the player up
    Given I hold 1 "firstaid"
    And I remember how many "firstaid" I have
    And I am hurt by 30 health points
    When I use my "firstaid" for first aid
    Then I should see a notification containing "You patched yourself up."
    And I should have 1 fewer "firstaid" than before
    And I should be back at full health
    And I should have no open wounds

  # Config.painkillers: +15 HP, then a five-minute in-memory cooldown that has no
  # reset. Re-running this within five minutes fails at the first use.
  @world @slow
  Scenario: Painkillers restore some health and then need a cooldown
    Given I hold 2 "painkillers"
    And I remember how many "painkillers" I have
    And I am hurt by 30 health points
    When I use my "painkillers" for first aid
    Then I should see a notification containing "The pain dulls a little."
    And I should have 1 fewer "painkillers" than before
    And my health should be 15 below maximum
    When I use my "painkillers" for first aid
    Then I should see a notification containing "You took some recently -- wait before taking more."
    And I should have 1 fewer "painkillers" than before

  # server/revive.lua: defibrillator use is on-duty EMS only and needs a downed patient.
  @server @rejection
  Scenario: Only on-duty paramedics can use a defibrillator
    Given I am off duty as "ambulance" at grade 1
    And I hold 1 "defibrillator"
    And I remember how many "defibrillator" I have
    When I use my "defibrillator" for first aid
    Then I should see a notification containing "Only on-duty paramedics can use a defibrillator."
    And I should have 0 fewer "defibrillator" than before

  @world @rejection
  Scenario: A defibrillator needs a downed patient nearby
    Given I am on duty as "ambulance" at grade 1
    And I stand at 306.3 -595.9 43.3 facing 315.0
    And I hold 1 "defibrillator"
    And I remember how many "defibrillator" I have
    When I use my "defibrillator" for first aid
    Then I should see a notification containing "No downed patient nearby to defibrillate."
    And I should have 0 fewer "defibrillator" than before

  # hospital:server:UseFirstAid / UseIfaks run the bandage / ifak useables.
  @server @rejection
  Scenario Outline: The legacy first-aid events run the same wound checks
    Given I am in full health
    And I should have no open wounds
    And I hold 1 "<item>"
    And I remember how many "<item>" I have
    When I send the legacy hospital event "<event>"
    Then I should see a notification containing "<refusal>"
    And I should have 0 fewer "<item>" than before

    Examples:
      | event       | item    | refusal                      |
      | UseFirstAid | bandage | No wound a bandage can treat |
      | UseIfaks    | ifak    | No open wound to treat       |

  # Config.compat.allowDestructiveItemEvents = false.
  @server @rejection
  Scenario Outline: The legacy item removal events never take items
    Given I hold 1 "<item>"
    And I remember how many "<item>" I have
    When I send the legacy hospital event "<event>"
    And I wait 1000 milliseconds
    Then I should have 0 fewer "<item>" than before

    Examples:
      | event             | item        |
      | removeBandage     | bandage     |
      | removeIfaks       | ifak        |
      | removePainkillers | painkillers |

  # ---------------------------------------------------------------------------
  # Legacy compatibility guards
  # ---------------------------------------------------------------------------

  # Death.respawnAtHospital refuses anyone who is not dead, before any bill.
  @server @rejection
  Scenario: A living player cannot respawn at a hospital through the legacy event
    Given I am in full health
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    When I send the legacy hospital event "RespawnAtHospital" with the text "pillbox"
    Then I should see a notification containing "You are not dead."
    When I send the legacy hospital event "RespawnAtHospital" with 1
    And I send the legacy hospital event "RespawnAtHospital" with 99
    And I wait 1000 milliseconds
    Then my "cash" balance should be unchanged
    And my patient status should be "alive"

  # The death/laststand flags are only honoured when the server sees 0 health.
  @server @rejection
  Scenario Outline: A healthy player cannot mark themself down through the legacy events
    Given I am in full health
    When I send the legacy hospital event "<event>" with true
    And I wait 1000 milliseconds
    Then my patient status should be "alive"

    Examples:
      | event              |
      | SetDeathStatus     |
      | SetLaststandStatus |

  # Config.compat.acceptClientInjurySync = false.
  @server @rejection
  Scenario: A client injury sync does not open wounds
    Given I am in full health
    And I should have no open wounds
    When I send a legacy injury sync for my "head" at tier 4
    And I wait 1000 milliseconds
    Then I should have no open wounds

  # hospital:server:SetArmor clamps to 0-100 and the client only ever lowers armour.
  @world
  Scenario Outline: The legacy armour event can only lower armour
    Given I set my armour to 50
    When I send the legacy hospital event "SetArmor" with the text "<requested>"
    And I wait 1000 milliseconds
    Then my armour should be <result>

    Examples:
      | requested | result |
      | 20        | 20     |
      | 80        | 50     |
      | 150       | 50     |
      | -5        | 0      |

  @rejection
  Scenario: The status command is for EMS only
    Given my job is "unemployed" at grade 1
    When I run the command "status"
    Then I should see a notification containing "You are not EMS."

  @server
  Scenario: The status command reports a healthy medic
    Given I am off duty as "ambulance" at grade 1
    And I am in full health
    And I should have no open wounds
    When I run the command "status"
    Then I should see a notification containing "Dead: false | Laststand: false | Open wounds: 0"

  @world
  Scenario: The status command counts an open wound
    Given I am off duty as "ambulance" at grade 1
    And I am in full health
    And I take 5 damage
    And I should have an open wound of tier 1 or 2
    When I run the command "status"
    Then I should see a notification containing "Open wounds: 1"

  # ---------------------------------------------------------------------------
  # Dispatch: /911e and the house-call queue. These push a call to every
  # on-duty medic and have in-memory cooldowns (/911e 30 s per player,
  # /housecall 60 s per character) with no reset; re-running within that
  # window fails at the first request.
  # ---------------------------------------------------------------------------

  # Config.dispatch.closeOnResolve + closeCallerAlerts: a revive closes the
  # patient's own /911e call.
  @global
  Scenario: An emergency call is raised once and closed when the patient is treated
    Given I watch my EMS calls
    When I run the command "911e fft medical test"
    Then an emergency call from me should be open
    When I run the command "911e fft medical test"
    Then I should see a notification containing "Please wait before calling again."
    And only one emergency call from me should be open
    When I am fully revived by the server
    Then no emergency call from me should be open

  @global
  Scenario: A medic accepts a queued house call
    Given I am on duty as "ambulance" at grade 1
    And I watch my EMS calls
    When I run the command "housecall fft house call"
    Then I should see a notification containing "Your request has been queued for EMS."
    And a house call from me should be open with the note "fft house call"
    When I run the command "housecall fft house call"
    Then I should see a notification containing "You already have a pending request."
    When I run the command "housecalls"
    And I accept my house call with the note "fft house call" from the list
    Then I should see a notification containing "accepted."
    And I should see a notification containing "A paramedic is on the way."
    And no house call from me should be open
    When I run the command "housecall fft house call"
    Then I should see a notification containing "Please wait before requesting another visit."
    And no house call from me should be open

  # /accepthousecall without a numeric id is ignored (server/housecall.lua).
  @rejection
  Scenario: A house call id must be a number
    Given I am on duty as "ambulance" at grade 1
    When I run the command "accepthousecall abc"
    Then I should not see a notification containing "That request is no longer available."
