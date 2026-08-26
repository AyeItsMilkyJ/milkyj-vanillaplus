# This file is dot-sourced by Build-BeginnerQuestBook.ps1 after the quest
# constructors are defined. It contains only authored chapter data; graph and ID
# validation remain in the generator. Parent names refer to stable lesson keys in
# the same chapter unless a published 16-character quest ID is supplied.

$roadmapChapter = Chapter 'roadmap' 'Pick a Lane Before You Craft Everything' 'minecraft:compass' 'start' $null @(
    (NewLesson 'route_map' 'The Pack Is a Web, Not a Checklist' @(
        'WHAT IS THIS? This chapter is the route map for MilkyCraft Vanilla+. The large chapters are parallel projects, not a single compulsory campaign, and recipes remain available even when a lesson is locked.',
        'DO THIS: Pick one immediate need: survive, feed the group, organise storage, learn Create, improve a settlement, or prepare an expedition. Open that chapter and read its first lesson before spending rare materials.',
        'WHY DO I CARE? Knowing which branch solves which problem stops the classic modpack mistake of crafting random machines with no useful output.',
        'COMMON FUCK-UP: A completed teammate quest can look like skipped teaching. Completed pages are still readable; use the text and installed manuals even when your FTB Team already earned the checkmark.'
    )),
    (NewLesson 'survival_to_home' 'First Days Lead to a Permanent Home' @(
        'WHAT IS THIS? The First Days branch establishes iron tools, sleep, light, portable supplies, landmarks and a healthy base location. It is the common foundation for every later project.',
        'DO THIS: Finish enough shelter and iron work to survive a night away from spawn, then mark home and reserve space for crops, storage, animals and a workshop.',
        'WHY DO I CARE? Homesteads, pets and machines all become frustrating when the base is unsafe, cramped or impossible for friends to find.',
        'COMMON FUCK-UP: Do not flatten an entire biome on day one. Mark expandable zones and build one useful room at a time so the server is not generating chunks while everyone searches for a perfect mega-base.'
    )),
    (NewLesson 'gear_to_armoury' 'Iron Gear Leads to the Public Armoury' @(
        'WHAT IS THIS? The enchanting branch turns early iron, books, lapis and experience into deliberate equipment upgrades. It then leads through Matrix Enchanting, Easy Anvils, safe recovery and Create: Enchantment Industry.',
        'DO THIS: Reserve one shared room for an Enchanting Table, fifteen usable bookshelves, candles, an Anvil, a Grindstone and labelled lapis and book storage.',
        'WHY DO I CARE? A public armoury lets the group improve and repair equipment without every player wasting levels on a separate mystery setup.',
        'COMMON FUCK-UP: Do not spend the group''s only rare book or best tool while learning the interface. Run the entire loop with an ordinary iron item first.'
    )),
    (NewLesson 'hearth_to_harvest' 'Food Leads to Seasons, Kitchens and Bees' @(
        'WHAT IS THIS? The food branch starts with a Farmer''s Delight Knife and Cutting Board, grows into a real kitchen, then forks into seasonal farming, Create food processing and Productive Bees.',
        'DO THIS: Establish two reliable meals before chasing variety. Keep seed stock, label raw ingredients, and use JEI to see which installed cooking station performs each step.',
        'WHY DO I CARE? A stocked kitchen supplies expeditions, recovers hunger efficiently and creates useful work for players who do not want to fight bosses or design factories.',
        'COMMON FUCK-UP: Similar foods from different Delight addons are not automatically interchangeable. Read the namespace in JEI and test one recipe before planting or automating a huge crop.'
    )),
    (NewLesson 'workshop_to_factory' 'Create Leads from Motion to Projects' @(
        'WHAT IS THIS? Create Basics teaches Ponder, rotation, stress and individual machines. Create Projects then combines those parts into maintainable farms, processing lines, contraptions and rail service.',
        'DO THIS: Learn one power source, route a shaft, run a Press or Fan, and build one complete input-to-output line before entering the project chapter.',
        'WHY DO I CARE? The project branch assumes you can diagnose direction, speed and stress. That lets it teach design decisions instead of repeating what a cogwheel is.',
        'COMMON FUCK-UP: More RPM is not automatically better and more machines are not free. Wear Engineer''s Goggles, check stress capacity, add an off switch and test overflow before scaling.'
    )),
    (NewLesson 'storage_to_transport' 'Storage Leads to Logistics and Transport' @(
        'WHAT IS THIS? Backpacks solve personal carrying, Tom''s Storage searches ordinary inventories, drawers hold bulk materials, Create Vaults buffer machines, and Packagers move requested stock.',
        'DO THIS: Give each system one job. Put unique tools in searchable storage, bulk stone or crops in locked drawers, and machine inputs in visible buffers.',
        'WHY DO I CARE? Clear ownership prevents item loops, lost components and factories that silently fill every chest in the base.',
        'COMMON FUCK-UP: Connecting every inventory through several transfer mods can create competing routes. Expand from a small tested network and keep one obvious overflow chest.'
    )),
    (NewLesson 'explorer_to_campaign' 'Exploration Leads to Campaigns' @(
        'WHAT IS THIS? Compasses, Waystones, maps, Lootr and expedition kits form the exploration foundation. Campaign chapters then explain the installed progression inside the Aether, Twilight Forest, Otherside and major overworld adventure systems.',
        'DO THIS: Prove that the group can leave home, share coordinates, recover from death and return with loot before opening a portal or challenging a named boss.',
        'WHY DO I CARE? Modded dimensions punish unmarked portals and unprepared groups far more than an ordinary cave trip does.',
        'COMMON FUCK-UP: A structure or boss from one mod is not automatically progression for another. Check the tooltip namespace, advancement tab and relevant manual before using a rare key or trophy.'
    )),
    (NewLesson 'companion_to_settlement' 'Companions Lead to a Living Settlement' @(
        'WHAT IS THIS? The companion branch connects tameable pets, fishing, aquariums, guarded villages, specialist trades and bounty boards into a peaceful parallel to factories and boss fights.',
        'DO THIS: Choose one responsibility for the shared settlement: pet care, fishing displays, village safety, trade access or public building.',
        'WHY DO I CARE? A multiplayer world feels inhabited when useful community projects exist between expeditions, and new players can contribute without endgame gear.',
        'COMMON FUCK-UP: Too many loose animals, villagers or fish in one loaded base can hurt weaker computers. Prefer small purposeful groups, secured enclosures and compact displays.'
    )),
    (NewLesson 'choose_next_project' 'Choose One Next Project' @(
        'WHAT IS THIS? This is the decision point. The guide offers routes, but the group decides which problem is worth solving now.',
        'DO THIS: Write one sentence in chat or on a sign: "We are building X because it will do Y." Pick an owner, a storage location and a stopping point for the session.',
        'WHY DO I CARE? A concrete outcome turns a huge mod list into a memorable shared build and makes it obvious which tutorial chapter to read next.',
        'COMMON FUCK-UP: Do not start five portals and four factories at once. Finish or safely park one project, record what remains, then choose another branch.'
    ))
)

$enchantingGearChapter = Chapter 'enchanting_gear' 'Wizard Shit Without Wasting 47 Levels' 'minecraft:enchanted_book' 'systems' $null @(
    (Existing '56791EFEB7941CF8' $false @('54C781F3CD01DB25')),
    (NewLesson 'matrix_first_pieces' 'Matrix Enchanting: Generate and Place Pieces' @(
        'WHAT IS THIS? Quark''s Matrix Enchanting is the pack''s primary Enchanting Table interface. Lapis and experience generate enchantment pieces, and the player chooses which compatible pieces to place on the item''s grid.',
        'DO THIS: Insert a disposable iron tool and lapis, generate a small set of pieces, read every tooltip, place one useful piece and commit only after the preview matches the intended result.',
        'WHY DO I CARE? The Matrix replaces the blind three-choice gamble with a visible decision while preserving Minecraft''s bookshelves, lapis and experience progression.',
        'COMMON FUCK-UP: Easy Magic is also installed, but its reroll button belongs to the standard table screen and is not expected inside Quark''s Matrix screen. If the classic three-offer screen appears instead, stop and report the configuration mismatch.'
    )),
    (NewLesson 'matrix_merge_pieces' 'Merge Matching Pieces Instead of Chasing Perfect Rolls' @(
        'WHAT IS THIS? Two Matrix pieces of the same enchantment can merge into a higher-level piece. The tuned pack slightly favours useful repeats and gives five piece charges per lapis without making enchantments free.',
        'DO THIS: Generate pieces on a cheap item until a matching pair appears, merge the pair, compare the level and cost, then decide whether the result is worth committing or saving for a later attempt.',
        'WHY DO I CARE? Merging gives ordinary rolls a purpose and makes a planned equipment set achievable without demanding exact deterministic selection.',
        'COMMON FUCK-UP: Generating forever still consumes resources and rising costs still matter. Set a lapis and experience budget before rolling, and bank the levels needed for the final enchantment.'
    )),
    (NewLesson 'matrix_candle_influence' 'Steer the Matrix with Coloured Candles' @(
        'WHAT IS THIS? Up to four nearby coloured candles influence Matrix piece odds. In this pack each candle applies a meaningful 25 percent weight adjustment; soul sand below the candle or its supporting bookshelf reverses that influence.',
        'DO THIS: Test one colour beside the table and compare several cheap rolls. White favours Unbreaking, yellow favours Looting/Fortune/Luck of the Sea, pink favours Silk Touch/Channeling, and blue favours Efficiency/Sharpness and several ranged enchants.',
        'WHY DO I CARE? A themed enchanting room becomes functional preparation: colour nudges the table toward the job while randomness, cost and compatibility still preserve balance.',
        'COMMON FUCK-UP: Candle influence changes odds; it does not guarantee an enchantment. Do not stack more than four, and do not place soul sand underneath unless the goal is to suppress that colour''s enchantments.'
    )),
    (NewLesson 'enchanting_books_treasure' 'Books, Treasure Enchantments and Honest Limits' @(
        'WHAT IS THIS? Matrix Enchanting accepts ordinary books, but treasure and undiscoverable enchantments remain disabled in the table. Mending, Swift Sneak and other special results still come from their intended loot, trade or exploration sources.',
        'DO THIS: Enchant one ordinary book for a reusable upgrade, then use JEI, Enchantment Descriptions and the owning mod''s advancement or loot path to research one treasure enchantment the group actually needs.',
        'WHY DO I CARE? Books separate rolling from committing gear, while the treasure boundary keeps exploration, structures and useful villagers relevant.',
        'COMMON FUCK-UP: A missing treasure enchantment is not a broken table. Do not enable every hidden enchantment or follow an Apotheosis tutorial; that overhaul is not installed in MilkyCraft.'
    )),
    (Existing '063A59CCA4DD3620' $false @('enchanting_books_treasure')),
    (NewLesson 'anvil_order' 'Combine Books in a Sensible Order' @(
        'WHAT IS THIS? Easy Anvils removes the hard Too Expensive cap, halves enchanted-book application costs and uses a fixed prior-work penalty. Operations can still consume many levels, so order remains important.',
        'DO THIS: Plan the final enchantments first, combine equal-level books in balanced pairs, preview each Anvil operation and apply the most expensive combined books to the target only after testing the sequence.',
        'WHY DO I CARE? A planned order spends fewer levels, keeps the result readable and avoids repeatedly handling the group''s best tool.',
        'COMMON FUCK-UP: No Too Expensive message does not mean no cost. Incompatible enchantments still reject each other, curses remain dangerous, and clicking the output commits the operation immediately.'
    )),
    (NewLesson 'armoury_recovery' 'Grindstone First, Disenchanter Later' @(
        'WHAT IS THIS? A vanilla Grindstone removes ordinary enchantments and returns some experience, but it does not preserve the enchantments as books. Create: Enchantment Industry later turns unwanted enchantment work and experience into a controlled workshop process.',
        'DO THIS: Test a Grindstone with a disposable enchanted item and inspect the preview before taking the output. Later, Ponder and JEI the Enchantment Industry Disenchanter and test it on another cheap item inside a contained line.',
        'WHY DO I CARE? Knowing the destructive early option and the advanced recovery path prevents valuable gear from being fed into the wrong station.',
        'COMMON FUCK-UP: Never assume a Grindstone, Disenchanter or Printer will return the exact enchanted book you imagine. Preview or test the installed recipe with rubbish gear before touching named, borrowed or irreplaceable equipment.'
    )),
    (NewLesson 'public_armoury_project' 'Project: Build a Public Armoury' @(
        'WHAT IS THIS? The armoury capstone connects the Matrix table, candle controls, book storage, Easy Anvils, Grindstone and the tested Create experience line into one safe shared service.',
        'DO THIS: Label inputs and destructive stations, provide ordinary test gear, store treasure books separately, document the candle colours, contain experience outputs and ask a teammate to enchant and repair one cheap item unaided.',
        'WHY DO I CARE? A teammate-proof armoury turns scattered levels and loot into durable expedition equipment without creating another confusing private machine room.',
        'COMMON FUCK-UP: Do not automate the final input for valuable gear. Keep a manual confirmation step, an obvious shutdown and enough empty output space that the line cannot consume or eject items unexpectedly.'
    ) $true 5 @('armoury_recovery', '5A53AAEC0E3B4B96'))
)

$homesteadMasteryChapter = Chapter 'homestead_mastery' 'Farm, Kitchen, Bees: Feed the Damn Server' 'farmersdelight:cooking_pot' 'systems' $null @(
    (NewLesson 'home_mastery_map' 'Three Homestead Loops' @(
        'WHAT IS THIS? A mature homestead has three linked loops: fields supply the kitchen, the kitchen supplies players, and bees or machines turn surplus into useful materials.',
        'DO THIS: Walk from crop storage to cooking stations and back. Decide where raw ingredients, prepared meals, compostable waste and bee products belong before automating anything.',
        'WHY DO I CARE? Short, labelled routes are easier for new players to understand and much easier to connect to Create later.',
        'COMMON FUCK-UP: One giant chest for every ingredient becomes unusable quickly. Separate seed reserve, harvest buffer, pantry and finished meals.'
    )),
    (NewLesson 'season_clock' 'Read the Season Before Planting' @(
        'WHAT IS THIS? Serene Seasons changes crop fertility through the year in the Overworld. Season HUD reports the current season, while JEI and crop tooltips help identify what is worth planting.',
        'DO THIS: Check the current season, plant a short labelled test row, and compare its growth with a crop known to be fertile now.',
        'WHY DO I CARE? Seasonal planning prevents players from blaming lag or a broken farm when an out-of-season crop is simply growing slowly.',
        'COMMON FUCK-UP: A planted crop is not proof that it is fertile. Observe growth over time and keep more than one food source instead of betting the pantry on a single field.'
    )),
    (NewLesson 'seasonal_fields' 'Build Fields That Survive the Calendar' @(
        'WHAT IS THIS? Crop rotation means growing different seasonal staples and keeping seed stock so the farm can change without another exploration trip.',
        'DO THIS: Divide the farm into labelled plots, store at least one replanting batch, and add a protected fallback plot. The installed configuration also gives underground Overworld farms a useful fallback at low Y levels.',
        'WHY DO I CARE? Several small dependable plots feed a server better than one enormous field that stalls for part of the year.',
        'COMMON FUCK-UP: Glass cover, underground placement and dimension rules are version-sensitive. Test a few plants in the actual build before enclosing hundreds of crop blocks.'
    )),
    (NewLesson 'kitchen_network' 'Cooking for Blockheads Is a Kitchen Network' @(
        'WHAT IS THIS? Cooking for Blockheads connects compatible kitchen inventories and workstations around a Cooking Table so ingredients can be used without opening every cabinet.',
        'DO THIS: Build a compact table, oven, fridge and storage arrangement. Put one recipe''s ingredients in the network and confirm the table can see them before decorating the room.',
        'WHY DO I CARE? The network makes a shared kitchen readable and keeps ingredients close to the station that consumes them.',
        'COMMON FUCK-UP: Blocks that only look connected may not share inventory. Test recipe visibility after every expansion and keep the exact installed layout guide or JEI open.'
    )),
    (NewLesson 'farmers_toolkit' 'The Farmer''s Delight Toolkit' @(
        'WHAT IS THIS? The Knife, Cutting Board, Stove, Cooking Pot, Skillet and Basket solve different preparation, cooking and collection jobs. They are a workflow, not six copies of a crafting table.',
        'DO THIS: Search Farmer''s Delight in JEI, inspect uses for each station, and choose one meal that demonstrates cutting plus cooking.',
        'WHY DO I CARE? Learning the station roles makes every installed Delight addon easier because their recipes reuse the same kitchen language.',
        'COMMON FUCK-UP: Right-click interactions on a Cutting Board differ from ordinary crafting. Place the ingredient, use the required tool, and leave room for the output.'
    )),
    (NewLesson 'cutting_board_workflow' 'Prep Ingredients on the Cutting Board' @(
        'WHAT IS THIS? Cutting Board recipes convert a placed ingredient with a specified tool and may return portions or secondary products that ordinary crafting does not.',
        'DO THIS: Pin one installed recipe in JEI, place the ingredient on the board, use the displayed tool and route every output to a labelled pantry slot.',
        'WHY DO I CARE? A clean preparation stage is the bridge between harvest storage and both manual cooking and Slice and Dice automation.',
        'COMMON FUCK-UP: A similarly named knife or ingredient from another namespace may not match. Use the exact JEI input and check the mod name in the tooltip.'
    )),
    (NewLesson 'cooking_pot_workflow' 'Cook a Repeatable Team Meal' @(
        'WHAT IS THIS? A Cooking Pot combines ingredients over heat and stores the result until it is served into the correct container.',
        'DO THIS: Choose a meal with renewable local ingredients, place the pot over a valid heat source, provide bowls or the shown container, and cook enough for one group trip.',
        'WHY DO I CARE? Repeatable food is more valuable than a chest of random high-quality dishes nobody knows how to replace.',
        'COMMON FUCK-UP: Missing heat, container or one exact ingredient can make a correct-looking pot do nothing. Recheck the full JEI recipe instead of throwing in substitutes.'
    )),
    (NewLesson 'pantry_rotation' 'Run a Pantry, Not a Dump Chest' @(
        'WHAT IS THIS? A pantry rotation keeps a small ready supply of meals while raw and rare ingredients remain available for future recipes.',
        'DO THIS: Label seed reserve, fresh harvest, dry staples, containers and ready meals. Set a minimum stock for the group''s everyday food.',
        'WHY DO I CARE? Players can take expedition food without accidentally consuming every seed, bowl or rare ingredient.',
        'COMMON FUCK-UP: Automating all harvest into cooked food can starve breeding, planting and quest recipes. Preserve raw stock and provide overflow.'
    )),
    (NewLesson 'slicer_automation' 'Slice and Dice: Automate the Cutting Board' @(
        'WHAT IS THIS? The installed Slice and Dice Slicer brings Farmer''s Delight cutting recipes into a Create-powered line.',
        'DO THIS: Ponder or inspect the Slicer, confirm its JEI recipe category, and automate one cheap ingredient from input buffer to collected output.',
        'WHY DO I CARE? It removes repetitive preparation without replacing the kitchen or inventing a separate food system.',
        'COMMON FUCK-UP: Build direction, held tool and recipe can all matter. Prove one item at low speed before feeding a whole crop harvest into the machine.'
    )),
    (NewLesson 'sprinkler_fertilizer' 'Sprinklers and Fertilizer Need Limits' @(
        'WHAT IS THIS? Slice and Dice also provides a Sprinkler block plus liquid Fertilizer for crop support. Their exact installed recipes, fluid handling and valid inputs are shown in JEI.',
        'DO THIS: Test the Sprinkler over a small plot, supply only the installed liquid Fertilizer recipe shown in JEI, and measure whether it helps before expanding.',
        'WHY DO I CARE? A bounded test separates useful farm support from a resource-hungry machine running across unloaded or out-of-season crops.',
        'COMMON FUCK-UP: Do not assume every fluid, crop or season is accepted. Use the installed recipe category and keep a shutoff for the supply line.'
    )),
    (NewLesson 'central_kitchen' 'Central Kitchen: Heat and Compatibility' @(
        'WHAT IS THIS? Create: Central Kitchen connects Create processing with Farmer''s Delight, including the Blaze Stove, Cooking Guide and installed fluid-food integrations.',
        'DO THIS: Search Central Kitchen in JEI and inspect the Blaze Stove and Cooking Guide. Choose one recipe already supported by your farm rather than designing around a video''s mod list.',
        'WHY DO I CARE? It turns a working manual kitchen into a factory branch while keeping the food recognisably Minecraft-like.',
        'COMMON FUCK-UP: Old showcases may contain recipes or addons not installed here. The current JEI page is the authority for heat, fluid amount, container and output.'
    )),
    (NewLesson 'food_factory_project' 'Project: One Meal from Field to Crate' @(
        'WHAT IS THIS? This project joins harvest, preparation, cooking, storage and safe shutdown into one understandable production chain.',
        'DO THIS: Pick one team meal. Draw its inputs, automate only the repetitive steps, preserve seed stock, provide overflow and label the manual recovery point.',
        'WHY DO I CARE? A small reliable meal line teaches every factory habit needed for larger Create projects.',
        'COMMON FUCK-UP: A line that works only while watched is unfinished. Fill the output, remove an ingredient and stop the power to prove it fails safely.'
    )),
    (NewLesson 'bee_safety' 'Beekeeping Starts with Vanilla Safety' @(
        'WHAT IS THIS? Vanilla bees establish the basic rules: flowers support bees, hives store honey, and a lit campfire beneath a hive allows safer harvesting.',
        'DO THIS: Build a small enclosed apiary away from busy doors, provide flowers, shelter the bees and collect one honey product without angering the colony.',
        'WHY DO I CARE? Productive Bees extends these ideas; it does not make careless hive placement or bee loss harmless.',
        'COMMON FUCK-UP: Open apiaries near chunk borders, portals or machinery lose bees. Keep the first colony compact and avoid hundreds of free-flying entities.'
    ) -Parents @('home_mastery_map')),
    (NewLesson 'find_solitary_bees' 'Productive Bees: Nests, Cages and Roles' @(
        'WHAT IS THIS? Productive Bees has solitary bees that live in natural nests and hive bees that work in Advanced Hives. Solitary bees are discovery and breeding stock; they do not produce resource combs in an Advanced Hive.',
        'DO THIS: Use the Nest Locator, JEI and the installed bees guide to find one suitable nest. Catch carefully with a Bee Cage and record the bee''s required flower or breeding use.',
        'WHY DO I CARE? Knowing the two roles prevents hours spent waiting for the wrong bee to make combs.',
        'COMMON FUCK-UP: Do not break every nest or release rare bees beside an open portal. Preserve habitat and carry spare cages.'
    )),
    (NewLesson 'advanced_hive' 'Advanced Hives Need the Right Flower' @(
        'WHAT IS THIS? An Advanced Beehive can receive an expansion box and house productive hive bees, but each bee still needs its configured flowering block.',
        'DO THIS: Build one Advanced Oak Beehive with an Expansion Box, place the exact JEI-listed flower nearby, add one proven hive bee and observe a complete work cycle.',
        'WHY DO I CARE? A single verified hive is the foundation for comb processing, breeding and upgrades.',
        'COMMON FUCK-UP: A bee inside a hive is not proof the setup works. Check weather, access, flowering block and hive output before adding more bees.'
    )),
    (NewLesson 'breeding_traits' 'Breed One Useful Bee Deliberately' @(
        'WHAT IS THIS? Honey Treats, the Feeding Slab and Breeding Chamber support controlled Productive Bees progression. Genetics and upgrades are deeper tools, not a requirement for the first working hive.',
        'DO THIS: Choose one useful offspring shown in JEI, obtain both parents, provide the specified breeding item and document the resulting bee''s flower.',
        'WHY DO I CARE? One deliberate breeding target teaches the system without filling the base with mystery cages.',
        'COMMON FUCK-UP: Similar bee names can have different roles or parents. Pin the exact installed recipe and label cages before starting.'
    )),
    (NewLesson 'centrifuge_bottler' 'Turn Combs into Stored Resources' @(
        'WHAT IS THIS? The Centrifuge processes resource combs into their outputs, while the Bottler handles compatible fluids and containers. JEI shows the installed result chances and container rules.',
        'DO THIS: Process one batch manually, identify every output, then route solids and fluids to separate labelled storage with overflow.',
        'WHY DO I CARE? The useful product is not the comb itself; a tidy processing stage makes the apiary part of the shared supply chain.',
        'COMMON FUCK-UP: Random outputs and full containers can jam automation. Test the worst case and never let loose items pile up beside a constantly loaded apiary.'
    )),
    (NewLesson 'apiary_project' 'Project: A Compact Responsible Apiary' @(
        'WHAT IS THIS? A responsible apiary produces one chosen resource, keeps bee counts bounded and stores every output without littering entities or items.',
        'DO THIS: Build one shared Advanced Hive line, a safe cage cabinet, one Centrifuge route, locked bulk storage and a visible off switch. Add upgrades only after the base loop works.',
        'WHY DO I CARE? Compact hives are friendlier to weak PCs and easier for the whole server to maintain than many scattered experimental colonies.',
        'COMMON FUCK-UP: Simulator and productivity upgrades are not excuses for uncontrolled scaling. Watch output demand, loaded chunks and storage before duplicating the setup.'
    ))
)

$createProjectsChapter = Chapter 'create_projects' 'Create: Build Machines With a Point' 'create:mechanical_arm' 'systems' $null @(
    (NewLesson 'project_map' 'Build Outcomes, Not Machine Collections' @(
        'WHAT IS THIS? This chapter turns Create 6.0.8 and the exact installed addons into projects with inputs, outputs, controls and maintenance paths.',
        'DO THIS: Complete the first production line and diagnostic lessons, then choose one project whose output the group actually needs.',
        'WHY DO I CARE? Create becomes approachable when every machine has a reason to exist and a player can explain the material flow.',
        'COMMON FUCK-UP: Do not copy a showcase block-for-block until you compare its Minecraft, Create and addon versions with this pack.'
    )),
    (NewLesson 'measure_first' 'Measure Rotation Before Expanding' @(
        'WHAT IS THIS? Engineer''s Goggles expose speed, stress impact and stress capacity. These measurements tell you whether a design can accept another machine.',
        'DO THIS: Inspect a running network at the source and at its busiest machine. Write down RPM, used stress and available capacity before changing ratios.',
        'WHY DO I CARE? A measured baseline makes overstress and backwards rotation quick to diagnose.',
        'COMMON FUCK-UP: Increasing RPM can increase a machine''s stress use. If the network stops, restore the known working ratio before adding more generators.'
    )),
    (NewLesson 'power_room' 'Design a Serviceable Power Room' @(
        'WHAT IS THIS? Water, wind and steam are different Create power projects. A serviceable power room exposes the source, main shaft, gauges and shutoff instead of burying them inside decoration.',
        'DO THIS: Ponder the chosen source, reserve maintenance access and connect one labelled main line with spare stress capacity.',
        'WHY DO I CARE? Shared factories survive updates and player mistakes when the power source can be understood without dismantling the wall.',
        'COMMON FUCK-UP: Do not upgrade to steam merely because it is later in progression. Use the smallest stable source that meets measured demand.'
    )),
    (NewLesson 'machine_contract' 'Every Machine Needs a Contract' @(
        'WHAT IS THIS? A machine contract states accepted inputs, promised outputs, power source, overflow behaviour and safe shutdown.',
        'DO THIS: Put signs or a book beside one line naming those five facts. Then test an invalid input, full output and loss of power.',
        'WHY DO I CARE? The contract lets another player operate or repair the line without asking its builder to log in.',
        'COMMON FUCK-UP: A filter is not overflow protection. Provide somewhere for rejected and excess items to go.'
    )),
    (NewLesson 'ore_line' 'Project: Wash or Crush One Ore Stream' @(
        'WHAT IS THIS? Presses, Crushing Wheels and Encased Fans can form ore-processing chains whose exact yields are defined by installed JEI recipes.',
        'DO THIS: Choose one common material, compare the available recipes, then build the shortest line that produces a useful improvement and captures secondary outputs.',
        'WHY DO I CARE? A focused ore line supplies the workshop without turning every mined item into an opaque mega-factory.',
        'COMMON FUCK-UP: Fan processing needs correct air direction and space. Test one item on a Depot or Belt before enclosing the stream.'
    ) -Parents @('machine_contract')),
    (NewLesson 'tree_farm' 'Project: A Tree Farm You Can Stop' @(
        'WHAT IS THIS? Mechanical Saws on a bearing, piston, gantry or other contraption can harvest trees and deliver logs to storage.',
        'DO THIS: Start with one tree type, a bounded planting area, collection, overflow and a manual stop. Ponder every moving component before assembly.',
        'WHY DO I CARE? Renewable wood supports building, charcoal, packages and rail infrastructure.',
        'COMMON FUCK-UP: Super Glue and chassis include exactly the blocks you selected. Preview the contraption and keep it away from homes, Waystones and other players'' builds.'
    ) -Parents @('machine_contract')),
    (NewLesson 'food_line' 'Project: Connect the Kitchen Carefully' @(
        'WHAT IS THIS? Central Kitchen and Slice and Dice allow Create motion to prepare compatible Farmer''s Delight recipes while the manual kitchen remains useful.',
        'DO THIS: Automate one repetitive cutting or mixing step, pull from a limited ingredient buffer and return the result to the pantry.',
        'WHY DO I CARE? The kitchen gains convenience without surrendering every crop to a permanently running factory.',
        'COMMON FUCK-UP: Never connect the seed reserve or the entire Tom''s network as an unrestricted input. Filter exact ingredients and cap the batch.'
    ) -Parents @('machine_contract')),
    (NewLesson 'contraption_safety' 'Moving Contraptions Need Boundaries' @(
        'WHAT IS THIS? Bearings, Mechanical Pistons, Gantries and Minecart Assemblies turn a selection of blocks into a moving contraption with its own collision and storage behaviour.',
        'DO THIS: Build a disposable test rig, mark its travel envelope, move it once empty and once loaded, then disassemble it with the Wrench.',
        'WHY DO I CARE? Understanding assembly and disassembly prevents a clever door or harvester from becoming a lost machine.',
        'COMMON FUCK-UP: A contraption can grab more blocks than expected or stop on an obstruction. Keep backups, use deliberate glue selection and never test through irreplaceable builds.'
    ) -Parents @('machine_contract')),
    (NewLesson 'chassis_glue' 'Chassis and Super Glue Define the Machine' @(
        'WHAT IS THIS? Super Glue joins selected blocks, while chassis can collect blocks according to their configured range and orientation.',
        'DO THIS: Wear Goggles, practise gluing a visible three-block assembly and use the Wrench or controls to inspect the selected area.',
        'WHY DO I CARE? Precise selection makes harvesters, doors and elevators predictable and cheap to repair.',
        'COMMON FUCK-UP: Hidden glue and excessive chassis range are hard to diagnose. Build the first frame in contrasting blocks and test away from storage networks.'
    ) -Parents @('contraption_safety')),
    (NewLesson 'gantry_elevator' 'Gantry and Elevator Projects' @(
        'WHAT IS THIS? Gantry Shafts provide controlled linear travel. Create''s elevator components provide named floors and repeatable vertical transport when built as shown by Ponder.',
        'DO THIS: Choose either a two-stop freight lift or a short gantry carriage, then Ponder every required block and add physical guards around the travel path.',
        'WHY DO I CARE? Controlled movement is useful infrastructure and a safer learning target than a roaming quarry.',
        'COMMON FUCK-UP: Reversing rotation, missing contacts or obstructed shafts can strand a platform. Include an accessible manual recovery route.'
    ) -Parents @('chassis_glue')),
    (NewLesson 'arm_logistics' 'Mechanical Arms Need Clear Destinations' @(
        'WHAT IS THIS? A Mechanical Arm transfers items among selected inputs and outputs, while Funnels, Chutes and Filters define what can enter each route.',
        'DO THIS: Bind one input Depot and two labelled outputs, apply a simple filter and test with cheap items before connecting machine storage.',
        'WHY DO I CARE? Arms make compact readable routing when each destination has one purpose.',
        'COMMON FUCK-UP: Overlapping valid outputs can make behaviour look random. Start with exclusive filters and confirm the Arm''s selected points.'
    ) -Parents @('machine_contract', '6C2795B621514EE3')),
    (NewLesson 'stock_network' 'Packagers Turn Stock into Deliveries' @(
        'WHAT IS THIS? Create 6 Packagers, Stock Links and Stock Tickers advertise inventory, form packages and fulfil requests through a physical delivery route.',
        'DO THIS: Ponder the three blocks in order, attach a Packager to a test chest, bind a Stock Link and request a cheap item at a clearly labelled destination.',
        'WHY DO I CARE? A stock network is a multiplayer warehouse project: searchable demand becomes visible parcels that belts or trains can move.',
        'COMMON FUCK-UP: The network can find stock without having a valid path for the package. Separate lookup, packaging, transport and unpacking when diagnosing failure.'
    ) -Parents @('machine_contract', '0AD1A0CD97148618')),
    (NewLesson 'connected_controls' 'Connected and Components Add Control Blocks' @(
        'WHAT IS THIS? Create: Connected and Create: Components and Additions extend the familiar kinetic language with blocks such as the Brake, Centrifugal Clutch, Brass Gearbox, inverted controls and adjustable brass chain gearshift.',
        'DO THIS: Search each installed addon in JEI, Ponder supported blocks, and test one control block on an isolated shaft with a visible input and output.',
        'WHY DO I CARE? These parts can simplify control rooms without introducing an unrelated energy system.',
        'COMMON FUCK-UP: A block name from a newer showcase may not exist in the installed 1.20.1 release. Use the current JEI list and tooltip namespace as the boundary.'
    ) -Parents @('machine_contract')),
    (NewLesson 'copycat_finish' 'Copycats, Deco and Rechiseled Are the Finish Layer' @(
        'WHAT IS THIS? Copycats+, Create Deco and Rechiseled: Create add shapes, railings, catwalks and material variants that visually match Create machinery.',
        'DO THIS: Finish one machine room with safe walkways, guards and readable colour coding while leaving shafts, gauges and shutoffs accessible.',
        'WHY DO I CARE? Decoration can teach flow and safety instead of hiding how the factory works.',
        'COMMON FUCK-UP: Do not cover moving or interactive faces before maintenance testing. Function first, finish layer second.'
    ) -Parents @('machine_contract')),
    (NewLesson 'aquatic_materials' 'Aquatic Ambitions Starts with Prismarine Materials' @(
        'WHAT IS THIS? Create: Aquatic Ambitions adds Create-style processing around prismarine, nautilus materials and the Conduit Cage. Installed items include Prismarine Alloy, rods and Nautilus Shards.',
        'DO THIS: Filter JEI by Aquatic Ambitions, trace one material recipe backwards and collect only enough resources for a small dry-land test rig.',
        'WHY DO I CARE? The addon creates an ocean-engineering branch that connects exploration rewards to useful Create processing.',
        'COMMON FUCK-UP: Do not assume ordinary Create alloy recipes or a video''s datapack matches this build. Pin the exact installed sequence.'
    ) -Parents @('machine_contract')),
    (NewLesson 'conduit_cage' 'The Conduit Cage Is an Environmental Processor' @(
        'WHAT IS THIS? The installed Aquatic Ambitions guide describes pumping fluid into the bottom of a Conduit Cage and using an Encased Fan through an awakened cage to create a channeling stream.',
        'DO THIS: Read the installed Ponder or project guide, awaken a Conduit correctly, build the cage with guarded fluid handling and test one listed processing recipe.',
        'WHY DO I CARE? The stream can provide Conduit Power in water and perform installed channeling processes such as prismarine work, copper ageing or coral revival.',
        'COMMON FUCK-UP: An unawakened Conduit, wrong fan direction or missing fluid makes a convincing-looking build do nothing. Verify each state separately.'
    ) -Parents @('aquatic_materials')),
    (NewLesson 'cei_experience' 'Enchantment Industry: Handle Liquid Experience' @(
        'WHAT IS THIS? Create: Enchantment Industry 1.4.1 adds liquid experience and hyper experience processing through its installed machines, including the Disenchanter, Experience Rotor and transformed Blaze Enchanter.',
        'DO THIS: Inspect the installed Ponder scenes and JEI categories. Build a contained test with a tank, explicit input, explicit output and no exposed player trap.',
        'WHY DO I CARE? Experience becomes a material stream that can be stored and used deliberately instead of scattered as orbs.',
        'COMMON FUCK-UP: This legacy 1.20.1 build does not contain every machine shown in newer CEI videos. It also can emit XP orbs from an open pipe, so guard outlets and avoid entity buildup.'
    ) -Parents @('machine_contract')),
    (NewLesson 'cei_printing' 'Disenchant, Guide, Enchant and Print' @(
        'WHAT IS THIS? The installed CEI path uses the Disenchanter, Enchanting Guide, Blaze Enchanter and Printer to move enchantment information and results through Create-style processing.',
        'DO THIS: Choose a cheap disposable item, follow its exact JEI/Ponder sequence, and confirm every fluid, guide and output requirement before using treasured equipment.',
        'WHY DO I CARE? A documented small test teaches the addon without gambling the group''s best gear.',
        'COMMON FUCK-UP: Do not look for the newer Blaze Forger, Experience Hatch or other features absent from CEI 1.4.1. If JEI cannot find the block, it is not part of this pack.'
    ) -Parents @('cei_experience')),
    (NewLesson 'railway_service' 'Project: A Railway Is a Service' @(
        'WHAT IS THIS? Tracks and carriages become a useful railway only when stations, signals, schedules, safe platforms and cargo handling work together.',
        'DO THIS: Build two named stations, assemble an empty test train, complete a round trip, then add one schedule and one signalled conflict point. Use Steam ''n'' Rails parts only where JEI confirms them.',
        'WHY DO I CARE? A reliable shared route moves players and bulk cargo while creating a reason to connect distant builds.',
        'COMMON FUCK-UP: Long unsignalled lines and unnamed stations are difficult to recover. Prove the route near home before extending into newly generated terrain.'
    ) -Parents @('machine_contract', '579F2C00A9B13FE7')),
    (NewLesson 'factory_audit' 'Graduation: Audit the Shared Workshop' @(
        'WHAT IS THIS? The branch endpoints merge here. A shared workshop is finished when players who did not build it can understand the production, contraption, logistics, control, decoration, aquatic, experience and railway services from their documentation.',
        'DO THIS: Ask teammates to operate and stop one representative system from each completed branch without voice instructions. Fix every unclear label, inaccessible component, unsafe edge and unhandled overflow they find.',
        'WHY DO I CARE? The audit converts a collection of personal machines into durable server infrastructure and proves the separate branches work together without hiding their boundaries.',
        'COMMON FUCK-UP: Passing one successful batch is not the same as safe operation. Test full output, empty input, chunk reload, controlled shutdown and recovery by someone other than the builder.'
    ) -Parents @('ore_line', 'tree_farm', 'food_line', 'gantry_elevator', 'arm_logistics', 'stock_network', 'connected_controls', 'copycat_finish', 'conduit_cage', 'cei_printing', 'railway_service'))
)

$dimensionCampaignsChapter = Chapter 'dimension_campaigns' 'Portals, Bosses and Poor Decisions' 'aether:bronze_dungeon_key' 'adventure' $null @(
    (NewLesson 'campaign_map' 'Campaign Rules: Portal, Outpost, Return' @(
        'WHAT IS THIS? A campaign is a connected expedition with a marked entrance, local shelter, shared supplies, recovery plan and known progression target.',
        'DO THIS: Before entering any major adventure, carry food, blocks, spare tools, a map or waypoint method and materials for a secure outpost. Agree how the group will retreat.',
        'WHY DO I CARE? The installed dimensions and boss systems reward preparation and can separate players from ordinary Overworld recovery routes.',
        'COMMON FUCK-UP: Never assume a Waystone, bed or portal behaves identically in every modded dimension. Test the return path before carrying unique loot deeper.'
    )),
    (NewLesson 'aether_portal' 'Aether: Build and Mark the Sky Gate' @(
        'WHAT IS THIS? The Aether is a sky dimension reached through its glowstone-and-water portal. Its materials, gravity hazards and dungeon order form a self-contained adventure path.',
        'DO THIS: Build the portal in a protected public room, mark both sides, carry blocks and a recovery chest, then enter with ordinary replaceable equipment.',
        'WHY DO I CARE? A safe gate turns repeated falls or deaths into recoverable trips and gives the group a stable campaign base.',
        'COMMON FUCK-UP: The Aether is not the Nether with different colours. Watch edges, carry fall recovery and do not move the only return portal without testing a replacement.'
    ) -Parents @('campaign_map')),
    (NewLesson 'aether_survival' 'Aether: Skyroot, Holystone and the Book of Lore' @(
        'WHAT IS THIS? Skyroot and Holystone are the local starter materials. The Book of Lore identifies Aether items and is the installed reference for unfamiliar drops.',
        'DO THIS: Establish a lit shelter around the arrival point, gather renewable basic materials and read several discoveries in the Book of Lore before roaming between islands.',
        'WHY DO I CARE? Local tools and knowledge reduce the cost of failure and prepare the workstation progression.',
        'COMMON FUCK-UP: Do not discard unfamiliar drops because their use is unclear. Read the Lore entry and JEI uses first; dungeon keys and materials can be progression-critical.'
    )),
    (NewLesson 'aether_workstations' 'Aether: Altar Path and Side Workstations' @(
        'WHAT IS THIS? The exact dungeon chain uses Zanite -> Altar -> Enchanted Gravitite. The Freezer is a sibling workstation branch from the Altar stage, while the Incubator belongs to the separate Blue Aercloud -> Moa Egg -> incubation branch.',
        'DO THIS: Build the Altar and test its Enchanted Gravitite path first. Then use JEI and the Book of Lore to explore one Freezer recipe and the Moa Incubator branch as separate side systems.',
        'WHY DO I CARE? The Altar prepares dungeon progression, while cold processing and Moa mounts add useful optional goals without pretending all three stations are one linear gate.',
        'COMMON FUCK-UP: Building a Freezer or Incubator does not replace the Altar milestone. Confirm each station''s fuel, input, output and advancement parent rather than treating them like interchangeable furnaces.'
    )),
    (NewLesson 'aether_bronze' 'Aether: Enchanted Gravitite and the Bronze Dungeon' @(
        'WHAT IS THIS? In the installed advancement chain, crafting an Altar leads to Enchanted Gravitite, which then leads to the Bronze Dungeon. The Bronze boss is the Slider.',
        'DO THIS: Enchant Gravitite at the Altar and test the resulting equipment, then find a Bronze Dungeon, establish a nearby recovery point and enter with food, blocks and spare gear.',
        'WHY DO I CARE? This follows the exact 1.5.2 advancement order and makes the Slider the group''s first dungeon threshold before Silver and Gold progression.',
        'COMMON FUCK-UP: Do not skip the Enchanted Gravitite milestone or lose dungeon loot casually. Keep the party together and preserve a clear route back to the entrance.'
    )),
    (NewLesson 'aether_silver' 'Aether: Silver Dungeon and the Valkyrie Queen' @(
        'WHAT IS THIS? After the Bronze Dungeon and its intermediate Lance milestone, the installed advancement chain leads to the Silver Dungeon and Valkyrie Queen.',
        'DO THIS: Secure the Bronze rewards, locate the Silver Dungeon and prepare for the Valkyrie challenge using the Book of Lore and observed mechanics.',
        'WHY DO I CARE? This tier supplies the mobility and combat confidence needed for the final dungeon campaign.',
        'COMMON FUCK-UP: Strong gear does not replace understanding the challenge. Store spare equipment outside and avoid carrying every dungeon reward into the next attempt.'
    )),
    (NewLesson 'aether_gold' 'Aether: Gold Dungeon and a Safe Return' @(
        'WHAT IS THIS? The Gold Dungeon and Sun Spirit are the final major Aether dungeon tier in the installed advancement chain, after the Silver path and Regen Stone milestone.',
        'DO THIS: Verify the current advancement state, prepare heat-resistant supplies and fight as a coordinated group. Return unique loot to the outpost before further exploration.',
        'WHY DO I CARE? Completing the tier gives the campaign a clear ending without requiring the group to strip every island or structure.',
        'COMMON FUCK-UP: Do not treat a boss win as permission to abandon the portal route. Restock the outpost and confirm everyone can return to the Overworld.'
    )),
    (NewLesson 'twilight_portal_map' 'Twilight Forest: Portal, Magic Map, First Camp' @(
        'WHAT IS THIS? Twilight Forest uses an advancement-enforced boss progression. A Magic Map helps identify major landmarks and a marked portal camp anchors the campaign.',
        'DO THIS: Create the portal, secure both sides, obtain the Magic Map materials shown in JEI and reveal nearby structures before choosing a direction.',
        'WHY DO I CARE? Progression protection and dense landmarks make a map-led expedition much safer than wandering until a biome rejects you.',
        'COMMON FUCK-UP: A structure visible on the horizon may still be locked by earlier progression. Read the Twilight advancement tab instead of forcing entry.'
    ) -Parents @('campaign_map')),
    (NewLesson 'twilight_naga' 'Twilight Forest: Naga First' @(
        'WHAT IS THIS? The installed advancement chain places the Naga as the first major Twilight boss and the first trophy needed for later progression.',
        'DO THIS: Locate the hedge arena with the Magic Map, clear the approach, establish a recovery chest and defeat the Naga without leaving teammates outside the fight.',
        'WHY DO I CARE? The Naga trophy opens the route to the Lich and teaches the dimension''s arena style.',
        'COMMON FUCK-UP: Keep the trophy and scales labelled. Progression items are not generic decoration until the group has used them where required.'
    )),
    (NewLesson 'twilight_lich' 'Twilight Forest: Lich and the Three Branches' @(
        'WHAT IS THIS? The Lich follows the Naga. After that victory the installed progression divides toward the swamp, dark forest and snowy forest branches.',
        'DO THIS: Prepare ranged and melee options, climb the Lich Tower together, learn the shield phase and store the trophy after the fight.',
        'WHY DO I CARE? Defeating the Lich is the branch point for most of the dimension''s middle campaign.',
        'COMMON FUCK-UP: Hitting visual decoys or ignoring reflected projectiles wastes supplies. Observe the phase change and use the arena rather than panic-breaking the tower.'
    )),
    (NewLesson 'twilight_labyrinth_hydra' 'Twilight Branch: Labyrinth, Minoshroom, Hydra' @(
        'WHAT IS THIS? The swamp branch uses Meef Stroganoff and Labyrinth progression before opening the Fire Swamp and Hydra encounter.',
        'DO THIS: Map the Labyrinth, mark exits, defeat the Minoshroom, keep the required food milestone and then prepare ranged damage and fire safety for the Hydra.',
        'WHY DO I CARE? The branch supplies one of the three boss completions required for the later progression merge.',
        'COMMON FUCK-UP: Mazes destroy unplanned groups. Use shared markers, leave breadcrumbs that cannot be confused with natural blocks and retreat before food or inventory space runs out.'
    )),
    (NewLesson 'twilight_dark_forest' 'Twilight Branch: Knights and Ur-Ghast' @(
        'WHAT IS THIS? The dark forest branch moves from trophy access to the Knight Stronghold, Knight Phantoms, Dark Tower traps and the Ur-Ghast.',
        'DO THIS: Bring the required trophy, map stronghold junctions, complete the Knight encounter, then learn the tower''s ghast-trap tools before the rooftop fight.',
        'WHY DO I CARE? Ur-Ghast completion is the second major requirement for the final branch merge.',
        'COMMON FUCK-UP: Rushing vertically through the Dark Tower strands teammates and skips recovery routes. Secure each section and understand a trap before relying on it.'
    ) -Parents @('twilight_lich')),
    (NewLesson 'twilight_snow' 'Twilight Branch: Alpha Yeti and Snow Queen' @(
        'WHAT IS THIS? The snowy branch progresses through the Yeti Lair and Alpha Yeti before the Aurora Palace and Snow Queen.',
        'DO THIS: Pack cold-region navigation supplies, defeat the Alpha Yeti, preserve its progression loot and then map a safe route through the palace.',
        'WHY DO I CARE? Snow Queen completion is the third boss requirement in the installed progression merge.',
        'COMMON FUCK-UP: Bright palace blocks and vertical rooms make regrouping difficult. Agree on one staircase or marker pattern and do not split the party across floors.'
    ) -Parents @('twilight_lich')),
    (NewLesson 'twilight_highlands' 'Twilight Forest: Merge at the Highlands' @(
        'WHAT IS THIS? Installed advancement data requires Hydra, Ur-Ghast and Snow Queen progress before the troll caves, giants and Final Plateau route.',
        'DO THIS: Confirm all three branch advancements, regroup at the portal camp, restock, then follow the highlands progression without pretending the unfinished Final Castle has a completed boss.',
        'WHY DO I CARE? The merge gives the whole server a clear shared milestone even if different teams handled each middle branch.',
        'COMMON FUCK-UP: Do not claim the mod has a finished final boss because an old showcase implies one. Treat the plateau and castle as exploration after the verified progression chain.'
    ) -Parents @('twilight_labyrinth_hydra', 'twilight_dark_forest', 'twilight_snow')),
    (NewLesson 'otherside_city' 'Otherside: Ancient City Before the Portal' @(
        'WHAT IS THIS? Deeper and Darker begins through Ancient City and Warden progression in the Overworld before entry to the Otherside becomes available.',
        'DO THIS: Practise wool placement, vibration control and retreat routes. Locate a city, mark a safe staging point outside the Deep Dark and carry only replaceable gear on the first survey.',
        'WHY DO I CARE? The portal campaign is deliberately later and more dangerous than ordinary cave exploration.',
        'COMMON FUCK-UP: Opening containers, sprinting or fighting ordinary mobs can create vibrations. Plan for stealth first and combat only when the objective requires it.'
    ) -Parents @('campaign_map')),
    (NewLesson 'otherside_warden' 'Otherside: Warden and Heart of the Deep' @(
        'WHAT IS THIS? The installed Deeper and Darker advancement path requires defeating a Warden before entering the Otherside path, with the Heart of the Deep tied to portal activation.',
        'DO THIS: Treat the Warden as a group boss objective, build a remote recovery route and bank spare supplies. A non-creative player consumes the Heart when the portal is created, so activate it only when the site and whole group are ready.',
        'WHY DO I CARE? This is the explicit difficulty gate between Ancient City exploration and the new dimension.',
        'COMMON FUCK-UP: Do not test the Heart casually or assume it will be returned. The installed 1.3.3 item code consumes the held stack for a non-creative player after spawning the portal.'
    )),
    (NewLesson 'otherside_enter' 'Otherside: Secure the Arrival Zone' @(
        'WHAT IS THIS? The Otherside is a separate Deeper and Darker dimension with its own biomes, mobs, Echo Wood, Resonarium and later temple content.',
        'DO THIS: Enter as a group, secure and mark the portal, create a small outpost and test the return journey before exploring beyond sight of the entrance.',
        'WHY DO I CARE? A working arrival zone makes deaths and dimension transitions recoverable.',
        'COMMON FUCK-UP: Do not move or decorate the portal before confirming how it relights. Keep spare blocks, food and ordinary tools on both sides.'
    )),
    (NewLesson 'otherside_resources' 'Otherside: Learn the Biomes and Materials' @(
        'WHAT IS THIS? Echo Wood, Resonarium, sculk creatures and biome discoveries form the middle Otherside progression; the exact installed uses appear in JEI and advancements.',
        'DO THIS: Choose one biome target, collect a small labelled sample, observe one local mob safely and return to the outpost to research uses.',
        'WHY DO I CARE? Targeted trips reduce needless generation and teach the dimension without turning every expedition into an inventory dump.',
        'COMMON FUCK-UP: Unfamiliar sculk blocks may react to sound or be progression materials. Do not mine an entire structure until you understand its triggers and uses.'
    )),
    (NewLesson 'otherside_temple' 'Otherside: Three Late-Game Branches' @(
        'WHAT IS THIS? The installed advancements split here: Ancient Temple discovery leads to the Sculk Transmitter; entering the Otherside leads toward the Sonorous Staff; killing the Warden leads through Reinforced Echo Shards toward Warden equipment.',
        'DO THIS: Read the advancement tab as three parallel projects. Establish a Temple recovery point for its branch, research the Staff from the entry branch, and inspect Reinforced Echo recipes before spending Warden drops.',
        'WHY DO I CARE? The three branches provide distinct exploration, utility and equipment goals without inventing one false linear prerequisite chain.',
        'COMMON FUCK-UP: Temple completion does not unlock every late item. Do not carry every Heart, shard and resonarium component into one expedition; bank rare materials between branches.'
    )),
    (NewLesson 'alex_cave_book' 'Alex''s Caves: Tablet, Codex, Book and Maps' @(
        'WHAT IS THIS? The installed main advancement path is Cave Tablet -> Cave Codex -> Cave Map -> six biome discoveries. The Cave Book is a sibling reference branch directly from the Tablet, not an alternative prerequisite for Maps.',
        'DO THIS: Find the Tablet in an Underground Cabin, follow the Codex path to craft one targeted Cave Map, and obtain or read the Cave Book separately as the mod''s reference manual.',
        'WHY DO I CARE? The Codex and Maps drive discovery, while the Book explains systems; keeping those roles separate prevents random digging across new chunks.',
        'COMMON FUCK-UP: Do not expect the Cave Book alone to satisfy the Codex/Map advancement path, and do not expect one Map to reveal every cave biome.'
    ) -Parents @('campaign_map')),
    (NewLesson 'alex_targeted_expeditions' 'Alex''s Caves: Six Parallel Expeditions' @(
        'WHAT IS THIS? Primordial Caves, Toxic Caves, Abyssal Chasm, Candy Cavity, Forlorn Hollows and Magnetic Caves are parallel discoveries with biome-local resources and threats.',
        'DO THIS: Pick one map, research its hazards in the Cave Book, prepare a matching kit, mark the entry and return with a small documented sample.',
        'WHY DO I CARE? Parallel goals let the group explore at its own pace and avoid forcing all six rare biomes before other progression.',
        'COMMON FUCK-UP: Armour and tactics that work in one cave may fail badly in another. Never treat a compilation video as universal preparation.'
    )),
    (NewLesson 'aquamirae_ice_maze' 'Frozen Sea Campaign: Ice Maze and Ship Graveyard' @(
        'WHAT IS THIS? Aquamirae is an overworld Deep Frozen Ocean campaign, not a separate dimension. Installed advancements begin around the Ice Maze and branch through fins, esca, Shell Horn, Frozen Key and equipment tiers.',
        'DO THIS: Use a ship, map and cold-ocean supplies to locate the region, establish a shoreline or vessel recovery point and follow one advancement branch at a time.',
        'WHY DO I CARE? It gives sea travel a dangerous destination and connects exploration to distinctive equipment without blocking other campaigns.',
        'COMMON FUCK-UP: Do not call every icy structure the same dungeon or assume a key opens the first door you see. Read the item namespace and advancement clue.'
    ) -Parents @('campaign_map')),
    (NewLesson 'mowzie_encounters' 'Mowzie''s Mobs: Independent Encounters' @(
        'WHAT IS THIS? Wroughtnaut, Frostmaw, Umvuthi, Naga and other Mowzie encounters have their own mechanics and rewards. Installed advancements treat the main encounters as parallel, not one mandatory boss ladder.',
        'DO THIS: Choose one discovered encounter, observe it from safety, research its cues and establish a recovery chest before committing to the fight.',
        'WHY DO I CARE? Each fight becomes a memorable optional expedition instead of an arbitrary gate between dimensions.',
        'COMMON FUCK-UP: Do not invent a universal boss order or attack a sleeping creature because it resembles a vanilla mob. Learn the arena and reward branch first.'
    ) -Parents @('campaign_map')),
    (NewLesson 'campaign_return_log' 'Campaign Debrief: Bring Knowledge Home' @(
        'WHAT IS THIS? A campaign is complete when its route, hazards, progression items and useful discoveries are documented for the next group.',
        'DO THIS: Return unique loot, restock the outpost, update maps or signs and record the next verified milestone. Keep trophies and keys in labelled shared storage.',
        'WHY DO I CARE? Future players can join the story instead of repeating every mistake or losing progression items in private chests.',
        'COMMON FUCK-UP: Do not tear down portals or empty outposts after a boss win. The world remains multiplayer infrastructure after your personal advancement fires.'
    ) -Parents @('aether_gold', 'twilight_highlands', 'otherside_temple', 'alex_targeted_expeditions', 'aquamirae_ice_maze', 'mowzie_encounters'))
)

$companionsCommunitiesChapter = Chapter 'companions_communities' 'Pets, Fish and Villagers With Jobs' 'minecraft:lead' 'systems' $null @(
    (NewLesson 'community_map' 'A Peaceful Progression Lane' @(
        'WHAT IS THIS? Pets, fishing and village projects form a parallel progression lane for players who prefer caring, collecting, trading or building to machinery and bosses.',
        'DO THIS: Choose one public project and place it near the settlement without crowding the busiest loaded chunk.',
        'WHY DO I CARE? A good multiplayer pack needs useful goals for different play styles and a reason to return home after expeditions.',
        'COMMON FUCK-UP: Decorative entity collections can become a performance problem. Start small and give every animal, villager or display a purpose.'
    )),
    (NewLesson 'dog_first' 'Doggy Talents: Train One Companion' @(
        'WHAT IS THIS? Doggy Talents Next turns a tamed wolf into a trainable dog with its own menu, levels, modes and care items.',
        'DO THIS: Read the installed Doggy Talents guide, use the required Training Treat on one wolf, open its menu and set a safe mode before travelling.',
        'WHY DO I CARE? One understood companion is safer and more useful than a pack of unmanaged pets.',
        'COMMON FUCK-UP: Do not test combat modes beside villagers, machines or portals. Name the dog, establish a bed or home area and learn recall controls first.'
    )),
    (NewLesson 'dog_commands' 'Modes, Talents and Recall' @(
        'WHAT IS THIS? Dog modes control behaviour while talent points specialise the companion. Commands and recall tools matter more than raw level.',
        'DO THIS: Spend one earned talent point, test sit or passive behaviour, then test recall and follow at home before an expedition.',
        'WHY DO I CARE? Predictable behaviour prevents pets from chasing bosses, entering portals or becoming lost in unloaded terrain.',
        'COMMON FUCK-UP: Keybinds and command items can differ by version. Check Controls and the installed guide rather than copying a newer tutorial''s keys.'
    )),
    (NewLesson 'pet_equipment' 'Domestication Innovation Is a Separate Layer' @(
        'WHAT IS THIS? Domestication Innovation adds pet beds, collar tags, enchantments and group-control tools for supported tameable animals. It complements Doggy Talents but is not the same progression system.',
        'DO THIS: Inspect collar and bed recipes in JEI, apply only a cheap tested enchantment, and verify respawn or command behaviour with a safe vanilla tameable first.',
        'WHY DO I CARE? Keeping the systems conceptually separate prevents a guide for one mod from damaging or misconfiguring a pet from the other.',
        'COMMON FUCK-UP: Do not stack every collar enchantment or assume both bed systems are interchangeable. Back up valuables and test the exact pet interaction manually.'
    )),
    (NewLesson 'shared_animal_care' 'Feed Troughs and Bounded Animal Care' @(
        'WHAT IS THIS? Animal Feeding Trough and ordinary breeding tools reduce repetitive feeding, but loaded animals still consume space and server time.',
        'DO THIS: Build one secure pen, test the trough with the exact accepted food, keep breeding stock bounded and provide a gate players cannot accidentally leave open.',
        'WHY DO I CARE? A small reliable herd supplies food and materials without turning the base into an entity farm.',
        'COMMON FUCK-UP: Automatic feeding can create more animals than expected. Count the herd, limit food supply and separate decorative pets from breeding pens.'
    )),
    (NewLesson 'fishing_basics' 'Fishing Is an Expedition Tool' @(
        'WHAT IS THIS? Vanilla fishing remains the baseline, while Aquaculture expands catches, tackle and materials. Water biome and installed loot rules determine what appears.',
        'DO THIS: Make a safe fishing point, catch several ordinary samples and use JEI to inspect every unfamiliar fish before cooking or displaying it.',
        'WHY DO I CARE? Fishing supplies food, collection goals and a low-risk reason to explore rivers, coasts and oceans.',
        'COMMON FUCK-UP: A fish item is not automatically placeable or accepted by every recipe. Read its namespace and uses before emptying the whole catch into the kitchen.'
    ) -Parents @('community_map')),
    (NewLesson 'aquaculture_catch' 'Aquaculture: Tackle and Useful Catches' @(
        'WHAT IS THIS? Aquaculture adds fish, equipment and processing choices whose exact recipes and loot vary with the installed version.',
        'DO THIS: Choose one rod or tackle improvement visible in JEI, fish in a known biome and label the resulting food, material and trophy catches separately.',
        'WHY DO I CARE? A documented catch table helps the group decide what to cook, keep, trade or display.',
        'COMMON FUCK-UP: Do not trust a generic fishing chart from another modpack. Confirm every item and biome claim against this client''s JEI and actual catches.'
    )),
    (NewLesson 'fish_display' 'Aquariums Are Small Curated Displays' @(
        'WHAT IS THIS? Better Fishtanks and Fish Display provide ways to exhibit aquatic finds, but item fish, bucketed fish and living entities are not automatically interchangeable.',
        'DO THIS: Pick one display system, follow its installed recipe and add a single common specimen before building a public aquarium.',
        'WHY DO I CARE? A curated exhibit turns exploration into shared world history without requiring a huge entity collection.',
        'COMMON FUCK-UP: Do not release dozens of fish into a decorative tank and assume the block manages them. Test containment and performance with one specimen.'
    )),
    (NewLesson 'village_defence' 'Guard Villagers: Secure Before Expanding' @(
        'WHAT IS THIS? Guard Villagers helps defend settlements, but walls, lighting, safe beds and controlled entrances still matter.',
        'DO THIS: Survey paths, roofs and dark corners, close obvious gaps and learn the installed guard conversion or recruitment method before adding more villagers.',
        'WHY DO I CARE? Physical safety protects trades and reduces chaotic fights in the centre of the shared base.',
        'COMMON FUCK-UP: More guards do not fix an open ravine or permanent spawnable roof. Repair the settlement first and keep defenders away from contraption paths.'
    ) -Parents @('community_map')),
    (NewLesson 'specialist_villagers' 'More Villagers: Add Trades with Purpose' @(
        'WHAT IS THIS? More Villagers adds specialist professions and workstations. Each workstation belongs to a specific installed trade path, not just decoration.',
        'DO THIS: Search the mod in JEI, choose one profession whose trades solve a current need, place its workstation in a safe accessible area and verify the first trade tier.',
        'WHY DO I CARE? Purposeful specialists make a settlement useful without creating a packed hall of redundant entities.',
        'COMMON FUCK-UP: Villagers can claim the wrong workstation across walls or floors. Isolate the first test and label the profession before expanding.'
    )),
    (NewLesson 'trading_post_bounties' 'Trading Post and Bountiful Solve Different Jobs' @(
        'WHAT IS THIS? Trading Post gathers nearby villager trade access into one interface, while Bountiful boards offer separate objectives and rewards. Neither system creates good trades by itself.',
        'DO THIS: Build each in a public safe area, inspect its range or board rules, and complete one low-risk interaction without moving rare villagers or bounty items.',
        'WHY DO I CARE? Central access reduces wandering through private houses and gives new players clear settlement tasks.',
        'COMMON FUCK-UP: A bounty item, villager trade and archaeology artifact may share a theme but are not interchangeable. Always check the owning namespace.'
    )),
    (NewLesson 'settlement_project' 'Project: A Useful Low-Lag Town Square' @(
        'WHAT IS THIS? The town-square project combines one pet-care point, one fish or museum display, safe trade access, a bounty board and clear paths without concentrating excessive entities.',
        'DO THIS: Build readable zones, count loaded animals and villagers, provide lighting and signs, then ask a new player to find food, trades and the return route unaided.',
        'WHY DO I CARE? The result is a welcoming social hub that still runs well on your friends'' weaker PCs.',
        'COMMON FUCK-UP: Do not add entities until frame time drops. Improve layout with blocks, signs and curated exhibits first; spread heavy farms away from the social centre.'
    ) -Parents @('shared_animal_care', 'fish_display', 'trading_post_bounties'))
)
