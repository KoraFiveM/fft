@kora @kora_mining
Feature: kora_mining pickaxe shop, rock gating and smelting stations
  Players buy a pickaxe from the quarry vendor, mine rocks that need a Mining
  level and an enabled pickaxe, and smelt ore at stations. Vendor, rock and
  station positions are read from the live GlobalState, so these scenarios
  follow whatever the mining creator saved.

  Not covered: a completed mine and a completed smelt. Both award Mining XP
  through kora_skills, which has no delete API, and a mined rock is removed
  for every player until it respawns. The /miningCreator editing tools are not
  covered (they rewrite shared DB rows); opening and refusing it are, as
  preconditions on the tester's `command` ACE, so one of those two scenarios
  always fails its precondition. The
  purchase confirmation is a DOM prompt; app actions here are sent at the
  NUI-callback level, so the server rules are what these scenarios prove.

  Background:
    Given resource "kora_mining" is running

  @server
  Scenario: Pickaxe shop publishes its vendor and prices
    Then the mining pickaxe shop should publish a vendor and a price for every pickaxe

  @server
  Scenario: Rock registry publishes every rock type
    Then the mining rock registry should publish every rock type with settings and spots

  @server
  Scenario: Smelting stations are published
    Then the mining smelting stations should be published with a target label and locations

  @world @ui
  Scenario: Vendor opens the pickaxe shop
    Given I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I close the app
    Then no app should be open

  @world @ui
  Scenario: Buying a bronze pickaxe charges the published price
    Given my mining level should be at least 1
    And I should have no "bronze_pickaxe"
    And any "bronze_pickaxe" bought from the mining shop is handed back afterwards
    And I carry enough cash for the mining shop price of "bronze_pickaxe"
    And I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I trigger the app action "pickaxe:buy:bronze_pickaxe"
    Then the app should answer with a "success" notice containing "Pickaxe purchased."
    And I should have 1 "bronze_pickaxe"
    And my cash should have dropped by the mining shop price of "bronze_pickaxe"
    And a money change should have been recorded for "cash"

  @world @ui @rejection
  Scenario: Pickaxe shop refuses a buyer without enough cash
    Given my mining level should be at least 1
    And I should have no "bronze_pickaxe"
    And any "bronze_pickaxe" bought from the mining shop is handed back afterwards
    And I carry less cash than the mining shop price of "bronze_pickaxe"
    And I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I trigger the app action "pickaxe:buy:bronze_pickaxe"
    Then the app should answer with a "destructive" notice containing "You do not have enough cash."
    And I should have no "bronze_pickaxe"
    And my "cash" balance should be unchanged

  @world @ui @rejection
  Scenario: Pickaxe shop refuses a second pickaxe of the same kind
    Given my mining level should be at least 1
    And I hold 1 "bronze_pickaxe"
    And I carry enough cash for the mining shop price of "bronze_pickaxe"
    And I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I trigger the app action "pickaxe:buy:bronze_pickaxe"
    Then the app should answer with a "destructive" notice containing "You already own this pickaxe."
    And I should have 1 "bronze_pickaxe"
    And my "cash" balance should be unchanged

  # MiningConfig.pickaxes: obsidian_pickaxe needs Mining level 80.
  @world @ui @rejection
  Scenario: Pickaxe shop refuses a pickaxe above the buyer's Mining level
    Given my mining level should be below 80
    And any "obsidian_pickaxe" bought from the mining shop is handed back afterwards
    And I carry enough cash for the mining shop price of "obsidian_pickaxe"
    And I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I trigger the app action "pickaxe:buy:obsidian_pickaxe"
    Then the app should answer with a "destructive" notice containing "Mining level 80 is required."
    And I should have no "obsidian_pickaxe"
    And my "cash" balance should be unchanged

  # Seeded copper rock: levelRequired 1, item copper_ore (server/schema.lua).
  @world @rejection
  Scenario: A rock cannot be mined without a pickaxe
    Given my mining level should be at least 1
    And I should carry no mining pickaxe
    And I face a free "copper" rock in the mining field
    When I try to mine the rock I am facing
    Then I should see a notification containing "You need an enabled pickaxe"
    And no progress bar should be running
    And I should have no "copper_ore"

  # With no ore in the inventory no recipe card declares a smelt action.
  @world @ui @rejection
  Scenario: Smelting station offers no recipe without ingredients
    Given I should have no "copper_ore"
    And I face a mining smelting station
    When I open the mining smelting station I am facing
    Then the app "kora_mining:smelting" should be open
    And the app action "smelt:copper_bar" should be unavailable
    When I close the app
    Then no app should be open

  # ---------------------------------------------------------------------------
  # Round 3: shop edges, rock gating per seeded rock, smelting sections,
  # blips and the creator gate.
  # ---------------------------------------------------------------------------

  @world @ui
  Scenario: The pickaxe shop shows a card for every pickaxe
    Given I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the mining pickaxe shop should list every pickaxe
    When I close the app
    Then no app should be open

  @world @ui
  Scenario: A buyer with exactly the price can buy a bronze pickaxe
    Given my mining level should be at least 1
    And I should have no "bronze_pickaxe"
    And any "bronze_pickaxe" bought from the mining shop is handed back afterwards
    And I carry exactly the mining shop price of "bronze_pickaxe"
    And I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I trigger the app action "pickaxe:buy:bronze_pickaxe"
    Then the app should answer with a "success" notice containing "Pickaxe purchased."
    And I should have 1 "bronze_pickaxe"
    And my cash should have dropped by the mining shop price of "bronze_pickaxe"

  @world @ui @rejection
  Scenario: Buying the same pickaxe twice charges only once
    Given my mining level should be at least 1
    And I should have no "bronze_pickaxe"
    And any "bronze_pickaxe" bought from the mining shop is handed back afterwards
    And I carry enough cash for the mining shop price of "bronze_pickaxe"
    And I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I trigger the app action "pickaxe:buy:bronze_pickaxe"
    Then the app should answer with a "success" notice containing "Pickaxe purchased."
    When I trigger the app action "pickaxe:buy:bronze_pickaxe"
    Then the app should answer with a "destructive" notice containing "You already own this pickaxe."
    And I should have 1 "bronze_pickaxe"
    And my cash should have dropped by the mining shop price of "bronze_pickaxe"

  @world @ui @rejection
  Scenario: A buyer with no cash at all is refused
    Given my mining level should be at least 1
    And I should have no "bronze_pickaxe"
    And any "bronze_pickaxe" bought from the mining shop is handed back afterwards
    And I have 0 in my "cash" account
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I trigger the app action "pickaxe:buy:bronze_pickaxe"
    Then the app should answer with a "destructive" notice containing "You do not have enough cash."
    And I should have no "bronze_pickaxe"

  # MiningConfig.pickaxes (shared/config.lua): iron 20, steel 40, titanium 60.
  @world @ui @rejection
  Scenario Outline: Each pickaxe tier above the buyer's Mining level is refused
    Given my mining level should be below <level>
    And any "<item>" bought from the mining shop is handed back afterwards
    And I carry enough cash for the mining shop price of "<item>"
    And I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I trigger the app action "pickaxe:buy:<item>"
    Then the app should answer with a "destructive" notice containing "Mining level <level> is required."
    And I should have no "<item>"
    And my "cash" balance should be unchanged

    Examples:
      | item             | level |
      | iron_pickaxe     | 20    |
      | steel_pickaxe    | 40    |
      | titanium_pickaxe | 60    |

  # server/pickaxe_shop.lua buy: the level check runs before the ownership check.
  @world @ui @rejection
  Scenario: The level requirement is reported before ownership
    Given my mining level should be below 80
    And I hold 1 "obsidian_pickaxe"
    And I carry enough cash for the mining shop price of "obsidian_pickaxe"
    And I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I trigger the app action "pickaxe:buy:obsidian_pickaxe"
    Then the app should answer with a "destructive" notice containing "Mining level 80 is required."
    And I should have 1 "obsidian_pickaxe"
    And my "cash" balance should be unchanged

  @world @ui @rejection
  Scenario: The shop does not accept an action for a pickaxe it does not sell
    Given I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    And the app action "pickaxe:buy:fft_no_such_pickaxe" should be unavailable
    And the app action "pickaxe:buy:" should be unavailable
    And my "cash" balance should be unchanged

  # server/pickaxe_shop.lua isAtVendor: 5.0 metres, checked again on every buy.
  @world @ui @rejection
  Scenario: Walking away from the vendor with the shop open refuses the purchase
    Given my mining level should be at least 1
    And I should have no "bronze_pickaxe"
    And any "bronze_pickaxe" bought from the mining shop is handed back afterwards
    And I carry enough cash for the mining shop price of "bronze_pickaxe"
    And I remember my "cash" balance
    And I face the mining pickaxe vendor
    When I target "Buy Pickaxes"
    Then the app "kora_mining:pickaxeShop" should be open
    When I step 20 metres away from the mining pickaxe vendor
    And I trigger the app action "pickaxe:buy:bronze_pickaxe"
    Then the app should answer with a "destructive" notice containing "You are too far from the pickaxe shop."
    And I should have no "bronze_pickaxe"
    And my "cash" balance should be unchanged

  # Seeded rows in server/schema.lua (kora_mining_rockspawns).
  @server
  Scenario Outline: Seeded rock types publish their level, reward and target label
    Then the "<rock>" rock type should need Mining level <level> and yield "<item>" under "<label>"

    Examples:
      | rock        | level | item           | label            |
      | amethyst    | 92    | amethyst_shard | Mine Amethyst    |
      | basalt      | 5     | basalt         | Mine Basalt      |
      | bauxite     | 10    | bauxite        | Mine Bauxite     |
      | carbon      | 30    | carbon         | Mine Carbon      |
      | carbonatite | 70    | carbonatite    | Mine Carbonatite |
      | copper      | 1     | copper_ore     | Mine Copper      |
      | diamond     | 75    | uncut_diamond  | Mine Diamond     |
      | emerald     | 65    | uncut_emerald  | Mine Emerald     |
      | gold        | 40    | gold_ore       | Mine Gold        |
      | iron        | 15    | iron_ore       | Mine Iron        |
      | obsidian    | 80    | obsidian       | Mine Obsidian    |
      | opal        | 40    | opal_shard     | Mine Opal        |
      | quartz      | 50    | quartz_shard   | Mine Quartz      |
      | ruby        | 70    | uncut_ruby     | Mine Ruby        |
      | sandstone   | 35    | sandstone      | Mine Sandstone   |
      | sapphire    | 60    | uncut_sapphire | Mine Sapphire    |
      | silver      | 20    | silver_ore     | Mine Silver      |
      | tin         | 1     | tin_ore        | Mine Tin         |
      | topaz       | 50    | topaz_shard    | Mine Topaz       |
      | zinc        | 50    | zinc_ore       | Mine Zinc        |

  @server
  Scenario Outline: Hard rocks refuse the weaker pickaxes
    Then the "<rock>" rock type should refuse the pickaxe "<pickaxe>"

    Examples:
      | rock     | pickaxe |
      | gold     | pick1   |
      | sapphire | pick2   |
      | ruby     | pick2   |
      | diamond  | pick3   |
      | obsidian | pick3   |
      | amethyst | pick3   |

  # server/main.lua mineProfile: the level is checked before any pickaxe.
  @world @rejection
  Scenario Outline: A rock above the miner's level is refused
    Given my mining level should be below <level>
    And I face a free "<rock>" rock in the mining field
    When I try to mine the rock I am facing
    Then I should see a notification containing "You need Mining level <level> to mine this rock."
    And no progress bar should be running
    And I should have no "<item>"

    Examples:
      | rock      | level | item          |
      | basalt    | 5     | basalt        |
      | sandstone | 35    | sandstone     |
      | gold      | 40    | gold_ore      |
      | diamond   | 75    | uncut_diamond |
      | obsidian  | 80    | obsidian      |

  # findPickaxe only counts a pickaxe the miner's level can use (iron needs 20).
  @world @rejection
  Scenario: A pickaxe above the miner's level does not count
    Given my mining level should be below 20
    And I hold 1 "iron_pickaxe"
    And I face a free "copper" rock in the mining field
    When I try to mine the rock I am facing
    Then I should see a notification containing "You need an enabled pickaxe"
    And no progress bar should be running
    And I should have no "copper_ore"
    And I should have 1 "iron_pickaxe"

  @server
  Scenario: Mining map blips are published with valid settings
    Then the mining map blips should be published with valid settings
    And the mining map blip "mine_shaft" should be named "Mine Shaft"
    And the mining map blip "pickaxe_vendor" should be named "Pickaxe Vendor"

  # Seeded station "test" (bars, materials, jewellery; server/schema.lua) and
  # the level-1 recipes copper_bar, bronze_bar (bars) and material_copper.
  @world @ui
  Scenario: The smelter lists level-one bar and material recipes but no gemstones
    Given I face the mining smelting station "test"
    When I open the mining smelting station I am facing
    Then the app "kora_mining:smelting" should be open
    And the mining smelting menu should have a section for every category
    And the mining smelting section "bars" should list at least 2 recipes
    And the mining smelting section "materials" should list at least 1 recipes
    And the mining smelting section "gemstones" should list no recipes
    When I close the app
    Then no app should be open

  # Seeded station "cutter" only offers the gemstones category.
  @world @ui
  Scenario: The gem cutter offers no bar or material recipes
    Given I face the mining smelting station "cutter"
    When I open the mining smelting station I am facing
    Then the app "kora_mining:smelting" should be open
    And the mining smelting section "bars" should list no recipes
    And the mining smelting section "materials" should list no recipes
    And the mining smelting section "jewellery" should list no recipes
    When I close the app
    Then no app should be open

  # bronze_bar needs 2 copper_ore and 2 tin_ore. If the card wrongly declared
  # its action, kora_mining:smelting:begin would still refuse without tin.
  @world @ui @rejection
  Scenario Outline: Bronze cannot be smelted with only part of its ingredients
    Given I should have no "tin_ore"
    And I hold <copper> "copper_ore"
    And I hold <tin> "tin_ore"
    And I face the mining smelting station "test"
    When I open the mining smelting station I am facing
    Then the app "kora_mining:smelting" should be open
    And the app action "smelt:bronze_bar" should be unavailable
    And I should have <copper> "copper_ore"
    And I should have <tin> "tin_ore"
    And no progress bar should be running

    Examples:
      | copper | tin |
      | 2      | 1   |
      | 1      | 1   |

  @ui
  Scenario: An admin can open the mining creator
    Given I have the mining creator permission
    When I run the command "miningCreator"
    Then the app "kora_mining:creator" should be open
    When I close the app
    Then no app should be open

  @ui @rejection
  Scenario: A player without the command ACE is refused the mining creator
    Given I lack the mining creator permission
    When I run the command "miningCreator"
    Then the mining creator should have refused to open
