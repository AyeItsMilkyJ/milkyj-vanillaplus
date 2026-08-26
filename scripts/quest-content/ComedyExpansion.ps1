# Optional multiplayer survival lessons for people who are competent in ways the
# evidence has not yet revealed. This file is dot-sourced after the published
# chapter definitions exist. Every entry is an additive leaf with a fresh stable
# seed: existing quest IDs, rewards, dependencies and completion remain untouched.

$funnyQuestAdditions = @{
    welcome = @(
        (NewLesson 'controls_survival' 'Your Keyboard Has Been Civilised' @(
            'WHAT IS THIS? MilkyCraft includes overlapping maps, storage, shaders, quests and Create controls. The recommended profile gives the quest book a visible J key, keeps shader actions together on F6 to F8 and separates common backpack and map actions.',
            'DO THIS: Open Controls, search by key and confirm that every red conflict is either intentional or resolved. Test the quest book, backpack, map, shader toggle and Create Ponder while standing somewhere safe.',
            'WHY DO I CARE? Five calm minutes in Controls prevents three hours of announcing that a mod is broken because another screen quietly stole its key.',
            'COMMON FUCK-UP: Do not press Reset All. The updater deliberately preserves personal controls, so change one binding at a time or use the optional recommended-controls tool with its automatic backup.'
        ) -Optional $true -Xp 3 -Parents @('18C0AF7F5C17CAB7') -TaskTitle 'I checked my keys instead of blaming Java'),
        (NewLesson 'polymorph_choice' 'Right Ingredients, Wrong Output?' @(
            'WHAT IS THIS? Several installed mods can register recipes with the same ingredients. Polymorph adds a small output selector when more than one valid result exists.',
            'DO THIS: If a crafting result looks wrong, inspect the result slot for the selector, cycle to the intended item and confirm its namespace before taking it.',
            'WHY DO I CARE? This keeps compatible recipes available without deleting one mod''s item just because another mod had the same idea.',
            'COMMON FUCK-UP: Recrafting the same ingredients twelve times will produce the same confusion. Use the selector and JEI instead of performing an increasingly angry science experiment.'
        ) -Optional $true -Xp 3 -Parents @('381BFADC40CC9BDC') -TaskTitle 'I found the tiny recipe button with my own eyes'),
        (NewLesson 'shader_first_aid' 'If the Sky Becomes the Void, Stop' @(
            'WHAT IS THIS? Shaders replace major parts of Minecraft''s rendering pipeline. A black, mirrored or flashing sky usually means the selected shader or its settings disagree with Oculus, Embeddium, Distant Horizons or the current graphics options.',
            'DO THIS: Disable shaders first, confirm the world is normal, then test one known-good pack with default settings. Change one option at a time and keep Distant Horizons rendering modest during diagnosis.',
            'WHY DO I CARE? A controlled fallback proves whether the world, resource pack or shader is responsible without corrupting anything or reinstalling the pack.',
            'COMMON FUCK-UP: Do not enable ten shaders at once, stack random resource packs and call the combined hallucination a server bug. Only one shader pack is active at a time.'
        ) -Optional $true -Xp 3 -Parents @('controls_survival') -TaskTitle 'I turned the cursed shader off before taking a screenshot'),
        (NewLesson 'restart_etiquette' 'The Three-Hour Bell Tolls for Thee' @(
            'WHAT IS THIS? The dedicated server performs a controlled restart every three hours while it is running. Discord reports starting, online, restarting, offline, crashes and update events.',
            'DO THIS: When the warning appears, finish the dangerous interaction, leave machines in a safe state and wait for the Online message before reconnecting.',
            'WHY DO I CARE? Controlled restarts save every loaded dimension, release memory and are much kinder than discovering the server stopped during a boss fight.',
            'COMMON FUCK-UP: Connection refused during the restart means the server is not listening yet. Spamming Join does not motivate Java; wait for the status message.'
        ) -Optional $true -Xp 3 -Parents @('11A22EDB82B37413') -TaskTitle 'I can survive several minutes without pressing Refresh')
    )

    first_days = @(
        (NewLesson 'corpse_recovery' 'Congratulations, You Made a Corpse' @(
            'WHAT IS THIS? Corpse preserves the dead player''s inventory at the death location. Recovery is still a journey, especially when the corpse is in lava, a dungeon or another dimension.',
            'DO THIS: Mark the location, bring food, blocks, light and disposable equipment, then secure the route before opening the corpse. Ask for help when the danger that killed you is still standing there looking pleased.',
            'WHY DO I CARE? A prepared recovery avoids donating a second inventory to the same hole and makes death a setback rather than a rage quit.',
            'COMMON FUCK-UP: Sprinting back naked with no blocks is not a strategy merely because it occasionally works. Recover deliberately and confirm everything returned before leaving.'
        ) -Optional $true -Xp 3 -Parents @('2E34979BCE044BF5') -TaskTitle 'I resolved one disaster before scheduling its sequel'),
        (NewLesson 'signage' 'Signs: Cheaper Than Telepathy' @(
            'WHAT IS THIS? Signs, item frames, labels, chalk and notice boards turn private knowledge into shared infrastructure.',
            'DO THIS: Label one public chest, one dangerous route and one machine input or shutdown. Use names that still make sense to someone who was not present when you built it.',
            'WHY DO I CARE? Your friends cannot read your beautiful mind, and they should not need Discord archaeology to discover where the iron went.',
            'COMMON FUCK-UP: A sign reading Stuff communicates only that the author surrendered. Name the contents, owner or purpose.'
        ) -Optional $true -Xp 3 -Parents @('341C28816B831FA9') -TaskTitle 'I labelled something before making six more chests'),
        (NewLesson 'lantern_context' 'Why Is My Lantern Doing That?' @(
            'WHAT IS THIS? Amendments and Supplementaries add contextual placement variants. A lantern placed against a wall can become a supported hanging form while remaining part of the same familiar building language.',
            'DO THIS: Read the Jade panel and item tooltip, test the block on floor, ceiling and wall, then use the Wrench or normal interaction shown by the installed mod if you need another state.',
            'WHY DO I CARE? Contextual blocks provide nicer builds without requiring a separate decorative item for every orientation.',
            'COMMON FUCK-UP: Breaking and replacing the lantern from the identical angle will keep producing the identical result. Change the support face or inspect the owning mod''s controls.'
        ) -Optional $true -Xp 3 -Parents @('46CFCE08506A17DA') -TaskTitle 'I accepted that the lantern was not personally attacking me'),
        (NewLesson 'palette_project' 'Build a Palette Before a Palace' @(
            'WHAT IS THIS? Rechiseled, Handcrafted, Macaw''s building sets, FramedBlocks and the smaller decoration mods provide many compatible shapes and material families.',
            'DO THIS: Make a small sample wall with the intended foundation, wall, trim, roof, light and furniture before committing to the full build.',
            'WHY DO I CARE? A palette proves that textures, connected models and resource packs agree while the cost of changing your mind is still six blocks rather than six thousand.',
            'COMMON FUCK-UP: Crafting one stack of every decorative block is not design; it is an exceptionally expensive scrolling problem.'
        ) -Optional $true -Xp 3 -Parents @('46CFCE08506A17DA', '213BA8647E82F355') -TaskTitle 'I built a sample wall instead of flattening another biome')
    )

    travel_storage = @(
        (NewLesson 'void_filter' 'The Void Upgrade Is Not a Personality Test' @(
            'WHAT IS THIS? Storage upgrades that delete overflow are useful only when their filters are exact and their limits have been proven.',
            'DO THIS: Disconnect valuable storage, configure the filter with cheap junk, fill the test inventory deliberately and confirm exactly which items disappear before reconnecting anything important.',
            'WHY DO I CARE? A tested void route prevents cobblestone floods. An untested one converts the group''s rare loot into a short educational memory.',
            'COMMON FUCK-UP: Whitelists and blacklists are opposites. Read the screen, test both accepted and rejected items and never use the main warehouse as the first experiment.'
        ) -Optional $true -Xp 3 -Parents @('28ED3EBB122D102D') -TaskTitle 'I tested deletion with rubbish, not the dragon egg'),
        (NewLesson 'shulker_peek' 'Peek Before You Place' @(
            'WHAT IS THIS? Shulker Box Tooltip lets you inspect portable storage without placing and reopening every box.',
            'DO THIS: Hover a filled shulker, use the configured preview control and give important boxes distinct names or colours before an expedition.',
            'WHY DO I CARE? A quick preview keeps the building blocks, food and emergency gear visible while reducing box clutter around shared paths.',
            'COMMON FUCK-UP: Eight identical unnamed purple boxes are not an organisation system. They are a memory test nobody volunteered for.'
        ) -Optional $true -Xp 3 -Parents @('7471D65394B8D846') -TaskTitle 'I named the box before forgetting what was inside')
    )

    create_projects = @(
        (NewLesson 'off_switch' 'Put an Off Switch on the Damn Thing' @(
            'WHAT IS THIS? A clutch, gearshift or other installed control can disconnect or redirect rotational power without dismantling the machine.',
            'DO THIS: Add one clearly labelled shutdown control, stop the line under normal load and full-output conditions, then show another player how to use it.',
            'WHY DO I CARE? A machine that cannot be stopped safely is not automation; it is a future Discord message with screenshots.',
            'COMMON FUCK-UP: Cutting power may leave items inside Basins, Belts or contraptions. Define a safe stopped state and a restart procedure instead of slapping a lever on the nearest wall.'
        ) -Optional $true -Xp 3 -Parents @('37E135DD266BF9AB') -TaskTitle 'My machine now has a button labelled STOP'),
        (NewLesson 'contraption_clearance' 'It Spun, Therefore It Ate the Wall' @(
            'WHAT IS THIS? Bearings, pistons, gantries and glued assemblies occupy a moving envelope larger than the block that powers them.',
            'DO THIS: Mark the complete travel area, test the contraption empty at low speed and inspect every glued or chassis-selected block before allowing it near storage or buildings.',
            'WHY DO I CARE? Clearance testing prevents a clever door, harvester or elevator from becoming a mobile demolition review.',
            'COMMON FUCK-UP: The fact that it assembled successfully does not mean you selected the intended blocks. Goggles, visible glue and a disposable test frame exist for a reason.'
        ) -Optional $true -Xp 3 -Parents @('1B0AFC1161BEB7D1') -TaskTitle 'I checked what was glued before pressing go'),
        (NewLesson 'station_names' 'Name the Station Something Useful' @(
            'WHAT IS THIS? Create stations and schedules identify destinations by name. Shared rail service also needs safe platforms, signs and a clear route owner.',
            'DO THIS: Give every station a unique place-and-purpose name, complete an empty round trip and verify the schedule from another player''s perspective.',
            'WHY DO I CARE? Home, Home 2 and New Home become performance art once the network reaches four settlements.',
            'COMMON FUCK-UP: Renaming a live station can invalidate a schedule expectation. Park the train safely, update the route and retest before announcing that rail service exists.'
        ) -Optional $true -Xp 3 -Parents @('1A6A991626D30C95') -TaskTitle 'My stations are no longer called Station')
    )

    homestead_mastery = @(
        (NewLesson 'rice_paddy' 'Rice Is Wet, Not Broken' @(
            'WHAT IS THIS? Farmer''s Delight food rice is planted in shallow water as a paddy crop. Other installed mods may also expose similarly named rice or pet-treat ingredients.',
            'DO THIS: Confirm the namespace in JEI, obtain the Farmer''s Delight rice item, prepare the waterlogged planting layout shown by its installed recipe or advancement and harvest one mature test patch.',
            'WHY DO I CARE? Separating names by namespace keeps the kitchen crop and the pet-treat ingredient from becoming the server''s longest-running conspiracy theory.',
            'COMMON FUCK-UP: Dry farmland is not a rice paddy. If the crop refuses placement, inspect its mod name and required block or water state before accusing the recipe.'
        ) -Optional $true -Xp 3 -Parents @('60435D16835B3DCE') -TaskTitle 'I checked which bloody rice I was holding'),
        (NewLesson 'winter_pantry' 'Winter Is Coming; Your Pantry Is Empty' @(
            'WHAT IS THIS? Serene Seasons makes reliable reserves more important than one enormous field that only thrives during part of the calendar.',
            'DO THIS: Store seed stock separately, preserve at least two dependable meals and write the current seasonal plan where the group can see it.',
            'WHY DO I CARE? A pantry turns slow winter growth into atmosphere instead of an emergency expedition for bread.',
            'COMMON FUCK-UP: Eating the seed reserve because it was in the food chest proves why the seed reserve needed its own labelled container.'
        ) -Optional $true -Xp 3 -Parents @('4FD0E91CC974DE62') -TaskTitle 'I stored food before becoming surprised by winter'),
        (NewLesson 'bee_labels' 'Label the Bee or Enjoy Mystery Insects' @(
            'WHAT IS THIS? Productive Bees species can require different nests, flowers, breeding partners and processing plans. Cages make those individuals easy to confuse.',
            'DO THIS: Label each active breeding or production area with the species, required flower and intended resource. Keep quarantine space for an unknown or newly bred bee.',
            'WHY DO I CARE? A readable apiary lets new players help without releasing six mystery bees into the kitchen.',
            'COMMON FUCK-UP: A cage tooltip is evidence, not interior decoration. Read it before opening the cage and verify the enclosure is closed.'
        ) -Optional $true -Xp 3 -Parents @('069B444CF7840537') -TaskTitle 'I know which bee is in the bee box')
    )

    new_horizons = @(
        (NewLesson 'lootr_peace' 'That Chest Is Yours; Stop Fighting' @(
            'WHAT IS THIS? Lootr gives each player an individual inventory from supported world-generated containers, so one person opening a chest does not consume everybody''s copy.',
            'DO THIS: Let two teammates open the same Lootr container and compare what each sees. Leave unsupported ordinary containers alone until the group agrees how to share them.',
            'WHY DO I CARE? Individual loot lets the party explore together without appointing a courtroom every time a dungeon contains one shiny object.',
            'COMMON FUCK-UP: A previously opened Lootr chest may look different for you, and a normal chest is still normal. Read Jade before declaring theft.'
        ) -Optional $true -Xp 3 -Parents @('4F7A5E294B48D343') -TaskTitle 'I inspected my own loot before accusing a friend'),
        (NewLesson 'waystone_names' 'Home Is Not a Useful Waystone Name' @(
            'WHAT IS THIS? Public Waystones are shared navigation infrastructure. Their names need to distinguish place, dimension and purpose.',
            'DO THIS: Rename or document one ambiguous destination using a stable format such as dimension, settlement and landmark. Keep the arrival area lit and unobstructed.',
            'WHY DO I CARE? A clear list prevents expensive travel to the wrong Home and helps new players understand the world without memorising everybody''s personal geography.',
            'COMMON FUCK-UP: Funny names are welcome after the useful location is present. The Arse End of Nowhere should still say which dimension contains it.'
        ) -Optional $true -Xp 3 -Parents @('133E40031AC9FB97') -TaskTitle 'My Waystone name now helps someone besides me'),
        (NewLesson 'chunk_budget' 'Distant Horizons Is Not Free Real Estate' @(
            'WHAT IS THIS? Distant Horizons renders lightweight terrain already known to the client. It does not make the dedicated server simulate or instantly generate every distant chunk.',
            'DO THIS: Explore in one planned direction, let terrain settle before sprinting farther and avoid sending several players into opposite fresh regions while heavy factories or boss fights are active.',
            'WHY DO I CARE? Sensible exploration keeps the view spectacular for weaker PCs without turning world generation into the evening''s main boss.',
            'COMMON FUCK-UP: Raising a client distance slider does not grant the server more CPU. LODs, render distance and simulation distance solve different problems.'
        ) -Optional $true -Xp 3 -Parents @('14EC247DD954A406') -TaskTitle 'I learned that chunks must exist before I can admire them')
    )

    dimension_campaigns = @(
        (NewLesson 'return_trip' 'Test the Return Trip Before Acting Brave' @(
            'WHAT IS THIS? Every dimension campaign needs a proven route home before the party carries unique loot or pushes past the safe arrival zone.',
            'DO THIS: Enter with replaceable equipment, secure and mark both sides, return once successfully, then restock before beginning the real expedition.',
            'WHY DO I CARE? A tested retreat turns a wipe into a recoverable story instead of four people discovering simultaneously that nobody marked the portal.',
            'COMMON FUCK-UP: Seeing the portal behind you is not the same as proving it remains safe, loaded, reachable and correctly linked after exploration.'
        ) -Optional $true -Xp 3 -Parents @('4C2CC01A2E38A3EC') -TaskTitle 'We returned once before pretending to be heroes')
    )

    companions_communities = @(
        (NewLesson 'aquarium_limits' 'The Aquarium Is Not a Mob Farm' @(
            'WHAT IS THIS? Better Fish Tanks, fish displays and the installed aquatic mods let a settlement keep curated exhibits without filling one loaded room with every creature ever discovered.',
            'DO THIS: Choose a small theme, verify tank requirements, keep only purposeful specimens and move surplus catches into food, release or separate storage according to the owning mod.',
            'WHY DO I CARE? A readable exhibit looks better, teaches more and runs better than forty entities clipping through one another behind glass.',
            'COMMON FUCK-UP: More fish does not automatically mean more aquarium. Stop when the display communicates its idea and the client remains smooth.'
        ) -Optional $true -Xp 3 -Parents @('422FDAA56D69D9A6') -TaskTitle 'I built an exhibit, not a wet CPU benchmark'),
        (NewLesson 'village_budget' 'This Is a Town, Not a CPU Benchmark' @(
            'WHAT IS THIS? Villagers, guards, pets and ambient creatures all tick while their chunks are active. Useful roles matter more than raw population.',
            'DO THIS: Count the settlement''s jobs, remove duplicate or unsafe workstations, secure paths and beds, then add only the trader, guard or service the town currently lacks.',
            'WHY DO I CARE? A compact purposeful town welcomes new players and protects weaker computers from the traditional villager convention inside one house.',
            'COMMON FUCK-UP: Breeding more villagers will not fix bad pathfinding, inaccessible beds or an unlit gate. Repair the town before increasing its population.'
        ) -Optional $true -Xp 3 -Parents @('4F1BCDAEDC6ACA1B') -TaskTitle 'Our town has jobs instead of an unexplained crowd')
    )

    endgame = @(
        (NewLesson 'durability_check' 'Durability Check: The Least Sexy Lifesaver' @(
            'WHAT IS THIS? Long campaigns consume armour, weapons, tools, shields and food even when the group wins every individual fight.',
            'DO THIS: Repair the important equipment, carry one humble spare tool and confirm the return kit before crossing the boss threshold.',
            'WHY DO I CARE? Ten seconds at the armoury prevents the legendary endgame strategy of punching the final phase with a nearly broken pickaxe.',
            'COMMON FUCK-UP: The green durability bar was never a legally binding promise. Read the actual remaining durability before the portal.'
        ) -Optional $true -Xp 3 -Parents @('731E73362B4E623D') -TaskTitle 'I checked durability before it became a group problem'),
        (NewLesson 'recovery_chest' 'The Oh-Shit Chest' @(
            'WHAT IS THIS? A recovery chest near a safe portal or outpost holds ordinary food, blocks, light and replaceable tools for the trip back to a failed expedition.',
            'DO THIS: Stock and label one kit, keep it outside the immediate boss arena and tell the team that it is emergency equipment rather than complimentary snacks.',
            'WHY DO I CARE? Recovery supplies shorten corpse runs and stop one death from consuming the group''s remaining good gear.',
            'COMMON FUCK-UP: If the recovery chest travels into the fight with you, it has misunderstood its only job.'
        ) -Optional $true -Xp 3 -Parents @('2D3D21E8896371A7') -TaskTitle 'I prepared for failure without manifesting it')
    )
}
