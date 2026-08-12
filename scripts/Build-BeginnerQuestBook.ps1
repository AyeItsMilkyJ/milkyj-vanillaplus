[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Deploy
)

$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$sourceRoot = Join-Path $projectRootResolved 'audit\questbook-legacy-1.8.0'
$stageRoot = Join-Path $projectRootResolved 'build\beginner-questbook'
$chapterRoot = Join-Path $stageRoot 'chapters'

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Missing preserved quest source: $sourceRoot"
}

function Get-StableId([string]$Seed) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes("milkyj-beginner-guide-v1|$Seed")
        $hash = $sha.ComputeHash($bytes)
        $hash[0] = $hash[0] -band 0x7F
        return (([BitConverter]::ToString($hash)).Replace('-', '').Substring(0, 16)).ToUpperInvariant()
    }
    finally { $sha.Dispose() }
}

function Escape-Snbt([string]$Value) {
    return $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", '\n')
}

function Existing([string]$Id, [bool]$Optional = $false) {
    return [pscustomobject]@{ Kind = 'existing'; Id = $Id; Optional = $Optional }
}

function NewLesson([string]$Key, [string]$Title, [string[]]$Description, [bool]$Optional = $false, [int]$Xp = 5) {
    return [pscustomobject]@{
        Kind = 'new'; Key = $Key; Title = $Title; Description = @($Description); Optional = $Optional; Xp = $Xp
    }
}

function ReplacementLesson([string]$Key, [string]$SourceId, [bool]$Optional = $false) {
    return [pscustomobject]@{
        Kind = 'replacement'; Key = $Key; SourceId = $SourceId; Optional = $Optional
    }
}

function Chapter([string]$Key, [string]$Title, [string]$Icon, [string]$Group, [string]$SourceChapter, [object[]]$Entries) {
    return [pscustomobject]@{
        Key = $Key; Title = $Title; Icon = $Icon; Group = $Group; SourceChapter = $SourceChapter; Entries = @($Entries)
    }
}

$groups = @(
    [pscustomobject]@{ Key = 'start'; Title = 'Learn the Pack' },
    [pscustomobject]@{ Key = 'systems'; Title = 'Build Useful Systems' },
    [pscustomobject]@{ Key = 'adventure'; Title = 'Explore and Survive' }
)

# These are the useful quests shown to players. Existing blocks retain their
# quest/task/reward IDs. The generator also compares every generated ID with the
# local v1.0.0 Git tag, so it never needs to read the production world.
$chapters = @(
    (Chapter 'welcome' 'WHERE THE FUCK DO I START?' 'minecraft:writable_book' 'start' 'welcome' @(
        (Existing '7DA1925406767A08'),
        (Existing '381BFADC40CC9BDC'),
        (Existing '4B260074BFD1BB0C'),
        (Existing '72BE3B6573EDF96E'),
        (Existing '2E34979BCE044BF5'),
        (Existing '044BBAC4BEC5CA7F'),
        (Existing '31CF2E051B43098D'),
        (Existing '18C0AF7F5C17CAB7'),
        (Existing '5466319B4BC86D8B'),
        (Existing '11A22EDB82B37413'),
        (Existing '34B44EE7DDB53F36'),
        (Existing '6352A5D038F9A58D'),
        (Existing '3522AB4192F75013'),
        (Existing '1885CF9658AB663D' $true)
    )),
    (Chapter 'first_days' 'Surviving the First Night' 'minecraft:campfire' 'start' 'first_days' @(
        (Existing '3BC686C3FBF1D35F'),
        (Existing '54C781F3CD01DB25'),
        (Existing '472E57FDA26EA8F4'),
        (Existing '1E4FFC70B08D7689'),
        (Existing '71F06FC804030460'),
        (Existing '2C1F26BCE19B7C54'),
        (Existing '6A4A0BB2F9D111AB'),
        (Existing '341C28816B831FA9'),
        (Existing '46CFCE08506A17DA' $true),
        (Existing '213BA8647E82F355' $true)
    )),
    (Chapter 'homestead' "Food That Isn't Raw Chicken" 'farmersdelight:cooking_pot' 'start' 'homestead' @(
        (Existing '1725341D3243AFDD'),
        (Existing '4CE08428A26650E2'),
        (Existing '60435D16835B3DCE'),
        (Existing '2AD044CDEA61410E'),
        (Existing '3C9A949E21E73BD7'),
        (Existing '36D9A2651A27AA32'),
        (Existing '000927068CCE0DB0'),
        (Existing '0D4B75EF5618911F'),
        (Existing '7F45F36FB147AD0A'),
        (Existing '64AC9DE8013767BD' $true),
        (Existing '71BB70B3127ECE00' $true),
        (Existing '519A57FD0FD737F9' $true),
        (Existing '22B69CA315389C48' $true)
    )),
    (Chapter 'create_basics' 'Create Without Having a Brain Aneurysm' 'create:large_cogwheel' 'systems' 'create_basics' @(
        (Existing '4201CE5BFBBC062D'),
        (Existing '1AC77EEB81F556DC'),
        (Existing '09CB7E54442B5B87'),
        (Existing '2250D40C885B51F2'),
        (ReplacementLesson 'power_after_water_wheel' '1885CF9658AB663D'),
        (Existing '0D9196F06BAA6EB5'),
        (Existing '653A5307BAFA7BE8'),
        (Existing '4164748FA85EDE6A'),
        (Existing '3119C51ADD982ABF'),
        (Existing '449599EDF06A1DB9'),
        (ReplacementLesson 'create_food_addons' '22B69CA315389C48'),
        (NewLesson 'crushing_wheels' 'Crushing Wheels: Make Them Face Each Other' @(
            'What this is: two Crushing Wheels grind items more effectively than the early Millstone. Both wheels must spin inward toward the gap.',
            'Why it matters: the pair unlocks higher-throughput crushing recipes and useful secondary outputs shown in JEI.',
            'How to begin: hover a Crushing Wheel and hold W. Build the Ponder layout openly, power both sides, and drop one test item through the top before adding chutes or belts.',
            'What comes next: once direction, output, and overflow are proven, connect it to the filtered logistics line.'
        )),
        (NewLesson 'saw_and_drill' 'Saws Cut; Drills Break' @(
            'What this is: a Mechanical Saw processes recipes or cuts trees, while a Mechanical Drill breaks blocks directly in front of it. Rotation speed changes how quickly they work.',
            'Why it matters: these blocks turn a powered line or moving contraption into a wood processor, quarry head, tunnel machine, or automated harvest tool.',
            'How to begin: Ponder each block separately. Test a stationary upward-facing Saw recipe and a guarded Drill on ordinary stone before attaching either to a contraption.',
            'What comes next: add filters, collection, an obvious shutdown, and guards so the machine cannot eat a build or a teammate.'
        )),
        (Existing '7B0C1910CB444EA6'),
        (Existing '1A354ABA1BE5171F'),
        (Existing '4EAA9A43A9020901'),
        (Existing '3C8A246AFBC5BCB3'),
        (Existing '6C2795B621514EE3'),
        (Existing '40B5E1218A0226CD'),
        (Existing '579F2C00A9B13FE7'),
        (Existing '5A53AAEC0E3B4B96'),
        (Existing '71CEDD5D336CCB38')
    )),
    (Chapter 'travel_storage' 'Stop Living Out of 46 Chests' 'toms_storage:ts.storage_terminal' 'systems' 'travel_storage' @(
        (Existing '2993B4E786D1E3C6'),
        (Existing '34B78045A3F1DA78'),
        (Existing '74ACDA0161CB4F07'),
        (Existing '5630715FB28AA469'),
        (Existing '7471D65394B8D846'),
        (Existing '28ED3EBB122D102D'),
        (Existing '2D0F242D77ABDD04'),
        (Existing '4130E2674DF6828B'),
        (Existing '145EE14BCE66ADC0'),
        (NewLesson 'create_vaults' 'Create Item Vaults Are Machine Buffers' @(
            'What this is: Item Vaults combine into larger multiblock inventories. They are accessed through funnels, chutes, belts, hoppers, or other transfer blocks rather than opened like a chest.',
            'Why it matters: a vault is excellent high-throughput input or output storage for a Create line, but it is a poor replacement for a searchable personal storeroom.',
            'How to begin: hover an Item Vault and hold W. Build a small vault, insert and extract one stack through visible transfer blocks, then test what happens when the output is full.',
            'What comes next: put the vault behind a filter or connect its surrounding inventories to Tom''s Storage without creating competing loops.'
        )),
        (NewLesson 'packaged_stock' 'Packages, Stock Links and Stock Tickers' @(
            'What this is: a Packager attaches to an inventory and makes or opens packages. A Stock Link advertises linked stock, and a Stock Ticker lets a seated mob or Blaze Burner act as a keeper who accepts requests.',
            'Why it matters: this is Create 6 logistics already inside the core Create mod; no Crafts and Additions mod is required. The network finds items, but physical packages still need a safe route.',
            'How to begin: Ponder Packager, Stock Link, and Stock Ticker in that order. Bind links before placement, attach a Packager to a test chest, and request cheap blocks before using the main warehouse.',
            'What comes next: add package addresses, filters, overflow storage, and a clearly labelled delivery point only after the one-chest test works.'
        ))
    )),
    (Chapter 'new_horizons' 'Exploration Without Getting Completely Lost' 'explorerscompass:explorerscompass' 'adventure' 'new_horizons' @(
        (Existing '6851604085D9D68D'),
        (Existing '133E40031AC9FB97'),
        (Existing '41EBD1EB56456B34'),
        (Existing '44731C0D67C0988E' $true),
        (Existing '6D639F2689D82CE0' $true),
        (Existing '76F0EC09B27BCF82' $true),
        (Existing '08B4FE3DADF6D411'),
        (Existing '14EC247DD954A406'),
        (Existing '4F7A5E294B48D343'),
        (Existing '3A8709849D637D3D'),
        (Existing '6416430518B427C3' $true),
        (Existing '5A57FC5CEB08D333' $true),
        (Existing '1CA7ED993BDE8D70' $true),
        (Existing '5FCB22913E016C22'),
        (Existing '53986E1D3385AA38' $true)
    )),
    (Chapter 'archaeology' 'Fossils, Archaeology and Dinosaurs' 'betterarcheology:archeology_table' 'adventure' 'archaeology' @(
        (Existing '03AC335757DE4153'),
        (Existing '702A4062FE9B512F'),
        (Existing '2ECFF275EF74DA42'),
        (Existing '576F3B9264ED1F4B' $true),
        (Existing '498034AF9E844D56' $true),
        (Existing '25F3FCF01504F899' $true),
        (Existing '776257DFD6C8B0B7' $true),
        (Existing '6D04014F7539F025'),
        (Existing '196B3D194E777B25'),
        (Existing '6ECE72BD1001A433')
    )),
    (Chapter 'vehicles' 'Vehicles and Transport' 'immersive_aircraft:biplane' 'adventure' 'creative_expeditions' @(
        (NewLesson 'hand_cart' 'Hand Carts and Supply Carts' @(
            'What this is: AstikorCarts Redux adds wood-specific Hand Carts that a player pulls and Supply Carts that attach to a mount and carry much more cargo.',
            'Why it matters: these are early overland storage vehicles with no fuel system. They are useful for building runs and farm hauling before aircraft or rail infrastructure exists.',
            'How to begin: inspect the oak_hand_cart and oak_supply_cart recipes in JEI, then find the Attach/Detach Cart keybind. Test steering and unloading on flat ground beside home.',
            'What comes next: add roads and a labelled parking area, or move to specialist farm carts when hauling alone is no longer enough.'
        )),
        (NewLesson 'farm_carts' 'Animal and Farm Carts' @(
            'What this is: Animal Carts carry riders, while Plows, Reapers, and Seed Drills perform different farm jobs. Each wood family has its own item, but the behaviour is shared.',
            'Why it matters: a cart can make a large farm pleasant without becoming an unexplained machine. Tool, seed, mount, and rider requirements still matter.',
            'How to begin: choose one job, read its tooltip and JEI recipe, and test a short row. Learn the slow-mode and attach controls before entering crops, pens, or narrow village streets.',
            'What comes next: keep spare tools or seeds nearby and document which cart is safe for passengers, harvest, planting, or path work.'
        )),
        (Existing '46592A2E4AB8D605' $true),
        (Existing '22F6D8A7A571B2DF' $true),
        (Existing '1C6ED7E70D63D294' $true),
        (Existing '62E98CDAA6C60AB7' $true),
        (Existing '46DC220D84558D7B' $true),
        (Existing '554A5FE4B4E51ACC' $true),
        (NewLesson 'train_network' 'Create Trains Are Shared Infrastructure' @(
            'What this is: Create trains join tracks, stations, schedules, signals, carriages, and cargo into a persistent transport network.',
            'Why it matters: trains move groups and bulk cargo safely between known places, while ships and aircraft are better for flexible exploration.',
            'How to begin: finish the track and schedule lessons in the Create chapter, then build two clearly named stations with safe platforms and an empty test train.',
            'What comes next: add signals, cargo loading, maps, and written schedules only after the basic round trip works without manual rescue.'
        ) $true)
    )),
    (Chapter 'endgame' 'Dangerous Shit and Endgame' 'minecraft:dragon_egg' 'adventure' 'nether_end' @(
        (Existing '731E73362B4E623D'),
        (Existing '2FF22EE22B1363FC'),
        (Existing '3CFD689EF13FCBC8'),
        (Existing '4EDB912AD92FF62F'),
        (Existing '2D3D21E8896371A7'),
        (Existing '2A603B486882AE2E'),
        (Existing '4181D1295E6AA537'),
        (Existing '2839A2A2D207C7DB'),
        (Existing '3A45B4D48F3CEBD6'),
        (Existing '3F4DB5EEDFFAC808'),
        (Existing '13E186E1D8309D38'),
        (Existing '4C84F99D2AF7535A'),
        (Existing '51F9F47AB21426BA' $true),
        (Existing '668CB4B502BECE63')
    ))
)

$titleOverrides = @{
    '1885CF9658AB663D' = 'Power Beyond the First Water Wheel'
    '22B69CA315389C48' = 'Create Food Addons: Kitchen to Factory'
}

$descriptionOverrides = @{
    '18C0AF7F5C17CAB7' = @(
        'What this is: the Field Guide explains progression, JEI explains recipes, Jade identifies the block in front of you, and Patchouli manuals provide the deep reference written by a mod author.',
        'Why it matters: hover an item and read the mod name in its tooltip before searching. In JEI, type an at-sign followed by that mod name to isolate its items and avoid mixing similarly named systems.',
        'How to begin: open a Patchouli manual like the Aether Book of Lore or Alex''s Caves Cave Book from your inventory and use its contents or search page. Manuals are ordinary items, not another keybind-only screen.',
        'What comes next: use the quest book for order, JEI for exact recipes, Patchouli for reference, Jade for live state, and Create Ponder for animated machinery.'
    )
    '4201CE5BFBBC062D' = @(
        'WHAT IS THIS? Ponder is Create''s animated in-game manual. Hover a supported Create item in JEI or an inventory and hold W; scroll through the scenes instead of guessing from a video made for another version.',
        'DO THIS: Ponder a Water Wheel, Mechanical Press and Encased Fan. Pause on each scene and identify its power connection, input, processing position and output before building anything expensive.',
        'WHY DO I CARE? Create 6 machines communicate through visible motion. Ponder teaches the exact arrangement installed here and makes the later machine quests much less painful.',
        'COMMON FUCK-UP: W does nothing when the cursor is not actually over a supported item, W is bound twice, or a search box owns the keyboard. Check Controls, resolve the conflict and hover the item again.'
    )
    '1AC77EEB81F556DC' = @(
        'WHAT IS THIS? Andesite Alloy is the common construction material for early Create shafts, cogs, casings and machines. JEI shows every installed recipe; pin the cheapest one your current resources support.',
        'DO THIS: Make a small batch, label a drawer or chest for it, and keep zinc, copper, iron and andesite nearby rather than scattering components across the base.',
        'WHY DO I CARE? A stocked component shelf turns Create from repeated scavenger hunts into a system you can actually learn and repair.',
        'COMMON FUCK-UP: Searching only for "alloy" can mix several mods. Use JEI''s at-sign Create filter and confirm the tooltip says Create before crafting a look-alike.'
    )
    '09CB7E54442B5B87' = @(
        'WHAT IS THIS? Engineer''s Goggles reveal rotational speed and stress information. The Wrench rotates, configures and safely removes most Create blocks without smashing the layout.',
        'DO THIS: Wear the goggles, look at a powered shaft, then practise rotating and wrench-removing a cheap cogwheel. Use sneak-use when an ordinary click opens a machine interface.',
        'WHY DO I CARE? These are diagnostic tools, not decoration. They tell you whether power reaches a machine and let you correct a backwards face without rebuilding the room.',
        'COMMON FUCK-UP: A Wrench is not a power source and goggles do not fix overstress. If the machine is still silent, trace the network from its actual source.'
    )
    '2250D40C885B51F2' = @(
        'WHAT IS THIS? A Water Wheel converts flowing water into rotational power. Rotation is Create''s equivalent of mechanical power: shafts carry it and machines consume its capacity.',
        'DO THIS: Ponder the wheel, place it where flowing water contacts its paddles, connect a visible shaft and verify movement with goggles before attaching a machine.',
        'WHY DO I CARE? It is a safe, dependable first source for presses, fans, mixers and small processing lines. The next lessons teach how to route and measure that power.',
        'COMMON FUCK-UP: Still water, blocked paddles or a shaft connected on the wrong axis produces no useful rotation. Copy the Ponder orientation exactly for the first test.'
    )
    '1885CF9658AB663D' = @(
        'WHAT IS THIS? Water Wheels are only the beginning. Windmills provide scalable passive rotation, while a Create steam engine can provide much more capacity after you understand boilers, heat and water supply.',
        'DO THIS: Ponder Windmill Bearings and Steam Engines. Build a small windmill before attempting steam, and treat a boiler as a later system with a dependable water feed, heat source, tank volume and readable gauges.',
        'WHY DO I CARE? Different sources trade cost, size and capacity. A larger source lets several machines share one network without every workshop owning a separate wheel.',
        'COMMON FUCK-UP: More revolutions per minute does not magically create more capacity. A badly supplied boiler or undersized source will stop a network even when part of it visibly spins.'
    )
    '0D9196F06BAA6EB5' = @(
        'WHAT IS THIS? Shafts carry rotation straight. Meshed Cogwheels transfer it sideways and reverse direction; a large cog meshed with a small one changes the gear ratio, meaning the relationship between input and output speed.',
        'DO THIS: Build an exposed line with a shaft, two same-size cogs, one large-to-small pair and a gearbox. Use goggles to compare direction and RPM (revolutions per minute) at each stage.',
        'WHY DO I CARE? Direction and speed determine whether a machine works and how quickly. This unlocks deliberate routing instead of a wall full of mystery cogs.',
        'COMMON FUCK-UP: Cogs only mesh at valid positions, and every mesh reverses direction. If one axis is motionless, inspect the teeth and connection rather than adding random gearboxes.'
    )
    '653A5307BAFA7BE8' = @(
        'WHAT IS THIS? RPM means rotational speed. Stress capacity is how much machinery a source can support; stress impact is how much each attached machine consumes. An overstressed network stops completely.',
        'DO THIS: Read a working network with goggles, add one cheap machine, then compare its speed and remaining capacity. Learn the difference before installing a speed controller or a large factory line.',
        'WHY DO I CARE? Speed controls throughput, while capacity controls how many machines can run. Diagnosing the correct number prevents a faster but weaker disaster.',
        'COMMON FUCK-UP: Raising RPM often raises stress use. When the goggles say overstressed, add or improve power capacity, disconnect load, or slow the network; do not just gear it faster.'
    )
    '4164748FA85EDE6A' = @(
        'WHAT IS THIS? A Mechanical Press uses rotation from a shaft. It presses an item placed on a Depot or moving Belt; with a Basin below it, it performs compacting recipes instead.',
        'DO THIS: Ponder the Press, power its shaft, place one JEI-confirmed input on a Depot and watch for the downward stroke. Test Basin compacting separately before connecting bulk input.',
        'WHY DO I CARE? Pressing unlocks plates, compacted materials and several later Create recipes. A Depot test becomes the foundation of an automated belt line.',
        'COMMON FUCK-UP: A Press above empty floor has nowhere to work, and a Basin recipe is not a Depot recipe. Check the JEI category, vertical spacing and output room.'
    )
    '3119C51ADD982ABF' = @(
        'WHAT IS THIS? An Encased Fan receives rotation through its shaft and pushes or pulls an air stream. Air passing through water, fire, soul fire or lava performs washing, smoking, haunting or blasting recipes where JEI says it is supported.',
        'DO THIS: Ponder the Fan, aim it across a Depot or Belt, add exactly one processing medium and test one cheap item. Keep the output side open and collected before feeding stacks.',
        'WHY DO I CARE? One powered fan processes many loose items at once and becomes the pack''s first useful bulk ore or food step.',
        'COMMON FUCK-UP: The Fan can spin while blowing the wrong direction, the medium can block the air stream, or the item can sit outside the stream. Use goggles and visible particles before rebuilding.'
    )
    '449599EDF06A1DB9' = @(
        'WHAT IS THIS? A Mechanical Mixer receives rotation from above and works in the Basin directly beneath it. JEI marks recipes that need no heat, normal heat or stronger heated Blaze Burner conditions.',
        'DO THIS: Ponder the Mixer, place a Basin at the shown height, insert one complete JEI recipe and power the Mixer. Add a Blaze Burner only when the recipe page explicitly requests heat.',
        'WHY DO I CARE? Mixing unlocks alloys, dough, fluids and ingredients used by Create, Farmer''s Delight integrations and later brass progression.',
        'COMMON FUCK-UP: Missing one ingredient, wrong Basin spacing, insufficient heat or blocked output leaves the Mixer hovering uselessly. Check the Basin contents and JEI heat label first.'
    )
    '22B69CA315389C48' = @(
        'WHAT IS THIS? Slice & Dice adds Create-powered food tools, and Create Central Kitchen connects Create processing with installed cooking recipes. They extend Farmer''s Delight; they do not replace knives, boards or Cooking Pots.',
        'DO THIS: Search JEI separately with the Slice & Dice and Central Kitchen mod filters. Ponder supported slicers or food machines, then automate one cheap ingredient from input chest to finished food.',
        'WHY DO I CARE? The same belts, funnels, depots, basins and rotation used for ore can prepare kitchen ingredients without inventing a second logistics system.',
        'COMMON FUCK-UP: Similar foods from different namespaces are not automatically interchangeable. Confirm the exact input, tool and container on the installed JEI recipe before blaming the machine.'
    )
    '1F2F7FDA97C0DC94' = @(
        'WHAT IS THIS? Two Crushing Wheels grind items that fall between them. Both receive rotational power and must spin inward toward the gap; JEI lists outputs and possible secondary drops.',
        'DO THIS: Ponder a Crushing Wheel, build the open pair, power both sides and drop one cheap test item through the top. Collect underneath before adding chutes or a belt.',
        'WHY DO I CARE? Crushing Wheels provide high-throughput ore and material processing and feed directly into fan washing or filtered storage.',
        'COMMON FUCK-UP: Wheels spinning the same way throw or jam items instead of crushing them. Reverse one side and make sure the output has somewhere to land.'
    )
    '0868E133B828D769' = @(
        'WHAT IS THIS? A Mechanical Saw cuts recipes and trees; a Mechanical Drill breaks blocks in front of its working face. Both require rotational power and can be stationary or attached to a moving contraption.',
        'DO THIS: Ponder each block. Test a guarded stationary Saw over its correct input and a Drill against ordinary stone, with a collection chest and obvious shutdown nearby.',
        'WHY DO I CARE? They unlock renewable wood processing, farms, tunnels and controlled block harvesting when combined with movement and item collection.',
        'COMMON FUCK-UP: The cutting face can point the wrong way, or a moving machine can chew through the build that carries it. Test one block at low speed before trusting a contraption.'
    )
    '7B0C1910CB444EA6' = @(
        'WHAT IS THIS? Belts carry items, Depots hold one processing position, Funnels insert or extract, Chutes move vertically, and Filters restrict what may pass. Mechanical Arms move selected items between marked points.',
        'DO THIS: Build a short powered Belt from a labelled input chest to a labelled output. Add one Funnel at a time, set a cheap Filter, then Ponder Mechanical Arms before marking their inputs and outputs.',
        'WHY DO I CARE? Predictable movement connects every machine in this chapter. Brass Funnels, Brass Tunnels and smarter components later add counting, splitting and routing.',
        'COMMON FUCK-UP: A Funnel''s arrow faces the wrong way, a Filter is set opposite to your intention, or an Arm was never taught valid points. Test with cobblestone before valuable items.'
    )
    '1A354ABA1BE5171F' = @(
        'WHAT IS THIS? This is your first complete automation: power source, visible transport, one processing step, filtered output, overflow storage and an obvious shutdown. A crop farm or ore-crushing line both count.',
        'DO THIS: Choose one cheap JEI recipe. For crops, use a guarded Saw or Harvester arrangement; for ore, use crushing then fan washing. Run a full stack and show another player how to stop it.',
        'WHY DO I CARE? A complete small line teaches more than a chest of disconnected machines and unlocks the confidence to scale safely.',
        'COMMON FUCK-UP: Building without overflow makes items despawn or jam the Belt. Fill the output deliberately during testing and make sure the machine fails safely.'
    )
    '4EAA9A43A9020901' = @(
        'WHAT IS THIS? A silent Create machine is usually disconnected, reversed, under-speed, overstressed, missing a supporting block, blocked at its output or holding the wrong recipe.',
        'DO THIS: Start at the power source and follow every visible shaft with goggles. Verify direction, RPM, stress, machine face, Depot or Basin position, exact JEI input and free output, in that order.',
        'WHY DO I CARE? A repeatable diagnostic order repairs factories faster than tearing down random components and preserves machines built by teammates.',
        'COMMON FUCK-UP: Testing five changes at once hides the real cause. Disconnect the factory, prove one machine operation in the open, then reconnect stages one by one.'
    )
    '3C8A246AFBC5BCB3' = @(
        'WHAT IS THIS? Brass is made from heated copper and zinc in a powered Mixer and Basin. It unlocks precision components plus Brass Funnels and Tunnels that can count, split and route items more intelligently.',
        'DO THIS: Confirm the brass recipe and heat level in JEI, prepare a safely captured Blaze Burner, mix a small batch and Ponder one Brass Funnel and Brass Tunnel before replacing basic logistics.',
        'WHY DO I CARE? Brass is the bridge from simple motion to controlled factories, train parts and sequenced assembly.',
        'COMMON FUCK-UP: An empty, unheated or incorrectly positioned Blaze Burner cannot satisfy the recipe. Also check that the Basin contains copper and zinc from compatible tags, not look-alike mod items.'
    )
    '6C2795B621514EE3' = @(
        'WHAT IS THIS? Mechanical Crafters reproduce a shaped crafting grid at machine scale. Sequenced Assembly is different: one item must pass through specified Deployer, Press, Saw or other operations in order, often several times.',
        'DO THIS: Ponder Mechanical Crafters and a Precision Mechanism recipe. Build the crafting grid against a visible back wall, then make a separate Belt loop for one sequenced item with ordered operations and a safe return path.',
        'WHY DO I CARE? These systems unlock large shaped components, Precision Mechanisms and much of later Create and train progression.',
        'COMMON FUCK-UP: Crafters face or connect incorrectly, while sequenced items leave the line before every step. Read the JEI sequence and chance display; do not replace it with a normal crafting assumption.'
    )
    '40B5E1218A0226CD' = @(
        'WHAT IS THIS? Create train tracks define the route, a Train Station marks an assembly point, and glued blocks on bogeys become carriages. Steam ''n'' Rails extends the rail system with additional track and train parts already installed.',
        'DO THIS: Ponder Train Tracks and Stations. Build a gentle test loop, place a Station on the track, enter assembly mode, align bogeys and carriage blocks, glue the carriage, assemble it and drive one empty lap.',
        'WHY DO I CARE? A proven train moves groups and cargo between permanent bases more safely than everyone flying alone.',
        'COMMON FUCK-UP: A Station that is not correctly bound to track cannot assemble, and unglued carriage blocks stay behind. Test the bare minimum train before decorating it.'
    )
    '579F2C00A9B13FE7' = @(
        'WHAT IS THIS? A Schedule tells an assembled train which named Stations to visit and what conditions allow departure. Signals divide busy railways into protected sections so trains do not enter the same space.',
        'DO THIS: Name two Stations clearly, drive the route manually, then create a simple two-stop Schedule and give it to the train driver. Add cargo conditions and Steam ''n'' Rails features only after the loop succeeds.',
        'WHY DO I CARE? Schedules turn a cool vehicle into shared infrastructure for passengers, building supplies and remote outposts.',
        'COMMON FUCK-UP: A schedule references a station name that does not match, waits on an impossible condition, or has no valid driver. Simplify to two unconditional stops when debugging.'
    )
    '5A53AAEC0E3B4B96' = @(
        'WHAT IS THIS? Create: Enchantment Industry turns experience into a fluid that can be collected, stored and used by its installed machines. The Disenchanter can separate unwanted enchantment work from gear.',
        'DO THIS: Inspect every machine recipe in JEI, build a tiny labelled experience line, and test with disposable low-value gear. Provide an Experience Hatch or other documented player access point.',
        'WHY DO I CARE? Stored experience makes enchanting and salvage a shared workshop service instead of levels stranded on one player.',
        'COMMON FUCK-UP: Feeding named, borrowed or irreplaceable gear into an untested machine can destroy the wrong item. Lock and label inputs before automation.'
    )
    '71CEDD5D336CCB38' = @(
        'WHAT IS THIS? The installed Create family is core Create 6.0.8 plus Steam ''n'' Rails, Enchantment Industry, Slice & Dice, Central Kitchen, Create Connected, Create Deco, Rechiseled Create and Create Ultimine. Each addon serves a different job.',
        'DO THIS: Use JEI''s at-sign mod filter to inspect one addon at a time. Use Connected and Deco for factory building, the food addons in a kitchen line, Enchantment Industry for experience and Steam ''n'' Rails for rail work.',
        'WHY DO I CARE? Knowing the owner mod tells you which manual, Ponder scene, recipe namespace and troubleshooting path applies.',
        'COMMON FUCK-UP: Tutorials for Crafts & Additions, Diesel Generators, Bells & Whistles, Contraption Terminals or Immersive Engineering describe mods not installed here. If JEI cannot find the item, stop following that tutorial.'
    )
    '702A4062FE9B512F' = @(
        'What this is: Better Archeology is the only installed mod in this pack that provides a fossil and archaeology crafting progression. It adds brushes, fossiliferous dirt, artifact shards, unidentified artifacts, and the Archeology Table.',
        'Why it matters: there is no installed dinosaur breeding, DNA extraction, incubator, or revival system. Old fossil configs and unrelated Relics or Artifacts items must not be treated as one technology tree.',
        'How to begin: use JEI with at-betterarcheology, inspect the valid brush and Archeology Table recipes, then brush suspicious blocks or fossiliferous dirt without destroying the dig site.',
        'What comes next: assemble fossil displays and identify artifacts, while treating Bountiful, Artifacts, and Relics as separate optional systems.'
    )
    '3CBF571C33BA4578' = @(
        'What this is: the installed Create family is Create 6 plus Central Kitchen, Slice and Dice, Enchantment Industry, Steam n Rails, Connected, Deco, Rechiseled Create, and Create Ultimine.',
        'Why it matters: each addon extends a different part of the same rotational system. Create Crafts and Additions and Immersive Engineering are not installed.',
        'How to begin: search JEI by each installed mod name, use Ponder where available, and test one addon block beside a known-good Create power source.',
        'What comes next: connect cooking, experience, rail, decoration, or logistics only after the base machine is stable.'
    )
}

# Index every legacy quest block and chapter ID.
$legacyBlocks = @{}
$legacyChapterIds = @{}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'chapters') -Filter '*.snbt' -File) {
    $text = [IO.File]::ReadAllText($file.FullName).Replace("`n", "`n")
    $chapterMatch = [regex]::Match($text, '(?m)^\tid:\s*"([0-9A-F]{16})"')
    if ($chapterMatch.Success) { $legacyChapterIds[$file.BaseName] = $chapterMatch.Groups[1].Value }
    foreach ($blockMatch in [regex]::Matches($text, '(?ms)^\t\t\{\r?\n.*?^\t\t\}')) {
        $idMatch = [regex]::Match($blockMatch.Value, '(?m)^\t\t\tid:\s*"([0-9A-F]{16})"')
        if ($idMatch.Success) { $legacyBlocks[$idMatch.Groups[1].Value] = $blockMatch.Value }
    }
}

function Set-Description([string]$Block, [string[]]$Paragraphs) {
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("`t`t`tdescription: [")
    foreach ($paragraph in $Paragraphs) { $lines.Add("`t`t`t`t`"$(Escape-Snbt $paragraph)`"") }
    $lines.Add("`t`t`t]")
    $replacement = ($lines -join "`r`n") + "`r`n"
    return [regex]::Replace($Block, '(?ms)^\t\t\tdescription:\s*\[\r?\n.*?^\t\t\t\]\r?\n', $replacement, 1)
}

function Set-Title([string]$Block, [string]$Title) {
    return [regex]::Replace(
        $Block,
        '(?m)^\t\t\ttitle:\s*"(?:\\.|[^"])*"\s*$',
        "`t`t`ttitle: `"$(Escape-Snbt $Title)`"",
        1
    )
}

function Normalize-RewardItems([string]$Block) {
    $rewardSection = [regex]::Match($Block, '(?ms)^\t\t\trewards:\s*(.*?)(?=^\t\t\t(?:subtitle|tasks):)')
    if (-not $rewardSection.Success) { return $Block }
    $rewardText = [regex]::Replace(
        $rewardSection.Value,
        '(?ms)^(\t\t\trewards:\s*)\[\{\r?\n.*?^\t\t\t\}\]\r?\n',
        {
            param($match)
            if ($match.Value -notmatch '(?m)^\s*type:\s*"item"') { return $match.Value }
            $id = [regex]::Match($match.Value, '(?m)^\s*id:\s*"([0-9A-F]{16})"').Groups[1].Value
            return @(
                "$($match.Groups[1].Value)[{",
                "`t`t`t`tid: `"$id`"",
                "`t`t`t`ttype: `"xp`"",
                "`t`t`t`txp: 2",
                "`t`t`t}]",
                ''
            ) -join "`r`n"
        }
    )
    $body = [regex]::Replace(
        $rewardText,
        '(?ms)^([^\S\r\n]*)\{\r?\n.*?^\1\}',
        {
            param($match)
            if ($match.Value -notmatch '(?m)^\s*type:\s*"item"') { return $match.Value }
            $id = [regex]::Match($match.Value, '(?m)^\s*id:\s*"([0-9A-F]{16})"').Groups[1].Value
            $indent = $match.Groups[1].Value
            return @(
                "${indent}{",
                "${indent}`tid: `"$id`"",
                "${indent}`ttype: `"xp`"",
                "${indent}`txp: 2",
                "${indent}}"
            ) -join "`r`n"
        }
    )
    return $Block.Substring(0, $rewardSection.Index) + $body + $Block.Substring($rewardSection.Index + $rewardSection.Length)
}

function Set-QuestLayout([string]$Block, [string[]]$Dependencies, [double]$X, [double]$Y, [bool]$Optional) {
    $result = $Block.Replace("`n", "`n")
    $result = [regex]::Replace($result, '(?ms)^\t\t\tdependencies:\s*\[\s*\r?\n.*?^\t\t\t\]\s*\r?\n', '')
    $result = [regex]::Replace($result, '(?m)^\t\t\tdependencies:\s*\[[^\r\n]*\]\s*\r?\n', '')
    $result = [regex]::Replace($result, '(?m)^\t\t\tsubtitle:\s*"(?:\\.|[^"])*"\s*\r?\n', '')
    $result = [regex]::Replace($result, '(?m)^\t\t\tx:\s*[-0-9.]+d\s*$', "`t`t`tx: $($X.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture))d")
    $result = [regex]::Replace($result, '(?m)^\t\t\ty:\s*[-0-9.]+d\s*$', "`t`t`ty: $($Y.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture))d")
    if ($Dependencies.Count -gt 0) {
        $depText = ($Dependencies | ForEach-Object { '"' + $_ + '"' }) -join ', '
        $result = [regex]::Replace($result, '(?m)^\t\t\{\r?$', "`t`t{`r`n`t`t`tdependencies: [$depText]", 1)
    }
    if ($Optional) {
        $result = [regex]::Replace($result, '(?m)^(\t\t\ttasks:)', "`t`t`tsubtitle: `"[OPTIONAL SIDE QUEST]`"`r`n`$1", 1)
    }
    return $result
}

function New-LessonBlock([string]$ChapterKey, [object]$Lesson, [string[]]$Dependencies, [double]$X, [double]$Y) {
    $questId = Get-StableId "$ChapterKey|$($Lesson.Key)|quest"
    $taskId = Get-StableId "$ChapterKey|$($Lesson.Key)|task"
    $rewardId = Get-StableId "$ChapterKey|$($Lesson.Key)|reward"
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("`t`t{")
    if ($Dependencies.Count -gt 0) {
        $depText = ($Dependencies | ForEach-Object { '"' + $_ + '"' }) -join ', '
        $lines.Add("`t`t`tdependencies: [$depText]")
    }
    $lines.Add("`t`t`tdescription: [")
    foreach ($paragraph in $Lesson.Description) { $lines.Add("`t`t`t`t`"$(Escape-Snbt $paragraph)`"") }
    $lines.Add("`t`t`t]")
    $lines.Add("`t`t`tid: `"$questId`"")
    if ($Lesson.Xp -gt 0) {
        $lines.Add("`t`t`trewards: [{")
        $lines.Add("`t`t`t`tid: `"$rewardId`"")
        $lines.Add("`t`t`t`ttype: `"xp`"")
        $lines.Add("`t`t`t`txp: $($Lesson.Xp)")
        $lines.Add("`t`t`t}]")
    }
    if ($Lesson.Optional) { $lines.Add("`t`t`tsubtitle: `"[OPTIONAL SIDE QUEST]`"") }
    $lines.Add("`t`t`ttasks: [{")
    $lines.Add("`t`t`t`tid: `"$taskId`"")
    $lines.Add("`t`t`t`ttitle: `"I read this lesson and checked the installed pack`"")
    $lines.Add("`t`t`t`ttype: `"checkmark`"")
    $lines.Add("`t`t`t}]")
    $lines.Add("`t`t`ttitle: `"$(Escape-Snbt $Lesson.Title)`"")
    $lines.Add("`t`t`tx: $($X.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture))d")
    $lines.Add("`t`t`ty: $($Y.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture))d")
    $lines.Add("`t`t}")
    return [pscustomobject]@{ Id = $questId; Block = ($lines -join "`r`n") }
}

function New-ReplacementBlock([string]$ChapterKey, [object]$Lesson, [string[]]$Dependencies, [double]$X, [double]$Y) {
    if (-not $legacyBlocks.ContainsKey($Lesson.SourceId)) {
        throw "Missing replacement source quest block: $($Lesson.SourceId)"
    }
    $questId = Get-StableId "$ChapterKey|$($Lesson.Key)|quest"
    $block = Set-QuestLayout $legacyBlocks[$Lesson.SourceId] $Dependencies $X $Y $Lesson.Optional
    $block = [regex]::Replace(
        $block,
        '(?m)^(\s*)id:\s*"([0-9A-F]{16})"\s*$',
        {
            param($match)
            $replacementId = if ($match.Groups[1].Value -eq "`t`t`t") {
                $questId
            }
            else {
                Get-StableId "$ChapterKey|$($Lesson.Key)|definition|$($match.Groups[2].Value)"
            }
            return "$($match.Groups[1].Value)id: `"$replacementId`""
        }
    )
    if ($descriptionOverrides.ContainsKey($Lesson.SourceId)) {
        $block = Set-Description $block $descriptionOverrides[$Lesson.SourceId]
    }
    if ($titleOverrides.ContainsKey($Lesson.SourceId)) {
        $block = Set-Title $block $titleOverrides[$Lesson.SourceId]
    }
    return [pscustomobject]@{ Id = $questId; Block = $block }
}

if (Test-Path -LiteralPath $stageRoot) {
    $resolvedStage = [IO.Path]::GetFullPath($stageRoot)
    $expectedStage = [IO.Path]::GetFullPath((Join-Path $projectRootResolved 'build\beginner-questbook'))
    if (-not $resolvedStage.Equals($expectedStage, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to replace unexpected stage path: $resolvedStage"
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}
New-Item -ItemType Directory -Path $chapterRoot -Force | Out-Null

$data = @'
{
	default_autoclaim_rewards: "disabled"
	default_consume_items: false
	default_quest_disable_jei: false
	default_quest_shape: "circle"
	default_reward_team: false
	detection_delay: 20
	disable_gui: false
	drop_book_on_death: false
	drop_loot_crates: false
	emergency_items_cooldown: 300
	grid_scale: 0.7d
	hide_excluded_quests: false
	icon: "minecraft:writable_book"
	lock_message: "Read the connected lesson first. Recipes are never gated."
	loot_crate_no_drop: { boss: 0, monster: 600, passive: 4000 }
	pause_game: false
	progression_mode: "flexible"
	show_lock_icons: true
	title: "MilkyJ Vanilla+ Beginner Field Guide"
	version: 14
}
'@
[IO.File]::WriteAllText((Join-Path $stageRoot 'data.snbt'), ($data.Trim() + "`r`n"), $utf8)

$groupIds = @{}
$groupLines = [Collections.Generic.List[string]]::new()
$groupLines.Add('{')
$groupLines.Add("`tchapter_groups: [")
foreach ($group in $groups) {
    $groupIds[$group.Key] = Get-StableId "group|$($group.Key)"
    $groupLines.Add("`t`t{ id: `"$($groupIds[$group.Key])`", title: `"$(Escape-Snbt $group.Title)`" }")
}
$groupLines.Add("`t]")
$groupLines.Add('}')
[IO.File]::WriteAllLines((Join-Path $stageRoot 'chapter_groups.snbt'), $groupLines, $utf8)

$selectedExistingIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$chapterCounts = [Collections.Generic.List[object]]::new()
$allSelectedQuestIds = [Collections.Generic.List[string]]::new()
$chapterUnlockDependencies = @{
    first_days       = @('18C0AF7F5C17CAB7')
    homestead        = @('18C0AF7F5C17CAB7')
    create_basics    = @('18C0AF7F5C17CAB7')
    travel_storage   = @('18C0AF7F5C17CAB7')
    new_horizons     = @('18C0AF7F5C17CAB7')
    archaeology      = @('18C0AF7F5C17CAB7')
    vehicles         = @('18C0AF7F5C17CAB7')
    endgame          = @('18C0AF7F5C17CAB7')
}
$compatibilityQuestIds = @('1885CF9658AB663D', '22B69CA315389C48')

for ($chapterIndex = 0; $chapterIndex -lt $chapters.Count; $chapterIndex++) {
    $chapter = $chapters[$chapterIndex]
    $chapterId = if ($chapter.SourceChapter -and $legacyChapterIds.ContainsKey($chapter.SourceChapter)) {
        $legacyChapterIds[$chapter.SourceChapter]
    } else { Get-StableId "chapter|$($chapter.Key)" }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('{')
    $lines.Add("`tdefault_hide_dependency_lines: false")
    $lines.Add("`tdefault_quest_shape: `"`"")
    $lines.Add("`tfilename: `"$($chapter.Key)`"")
    $lines.Add("`tgroup: `"$($groupIds[$chapter.Group])`"")
    $lines.Add("`ticon: `"$($chapter.Icon)`"")
    $lines.Add("`tid: `"$chapterId`"")
    $lines.Add("`torder_index: $($chapterIndex + 1)")
    $lines.Add("`tprogression_mode: `"flexible`"")
    $lines.Add("`tquest_links: [ ]")
    $lines.Add("`ttitle: `"$(Escape-Snbt $chapter.Title)`"")
    $lines.Add("`tquests: [")

    $previousRequired = ''
    for ($entryIndex = 0; $entryIndex -lt $chapter.Entries.Count; $entryIndex++) {
        $entry = $chapter.Entries[$entryIndex]
        $row = [math]::Floor($entryIndex / 6)
        $column = $entryIndex % 6
        $xColumn = if (($row % 2) -eq 0) { $column } else { 5 - $column }
        $x = [double]($xColumn * 2)
        $y = [double]($row * 2)
        $dependencies = if ($previousRequired) {
            @($previousRequired)
        }
        elseif ($chapterUnlockDependencies.ContainsKey($chapter.Key)) {
            @($chapterUnlockDependencies[$chapter.Key])
        }
        else { @() }

        if ($entry.Kind -eq 'existing') {
            if (-not $legacyBlocks.ContainsKey($entry.Id)) { throw "Missing legacy quest block: $($entry.Id)" }
            if (-not $selectedExistingIds.Add($entry.Id)) { throw "Quest selected twice: $($entry.Id)" }
            $block = $legacyBlocks[$entry.Id]
            $block = Set-QuestLayout $block $dependencies $x $y $entry.Optional
            $questId = $entry.Id
        }
        elseif ($entry.Kind -eq 'replacement') {
            $created = New-ReplacementBlock $chapter.Key $entry $dependencies $x $y
            $block = $created.Block
            $questId = $created.Id
        }
        else {
            $created = New-LessonBlock $chapter.Key $entry $dependencies $x $y
            $block = $created.Block
            $questId = $created.Id
        }
        if ($questId -notin $compatibilityQuestIds) {
            if ($descriptionOverrides.ContainsKey($questId)) { $block = Set-Description $block $descriptionOverrides[$questId] }
            if ($titleOverrides.ContainsKey($questId)) { $block = Set-Title $block $titleOverrides[$questId] }
        }
        $lines.Add($block)
        $allSelectedQuestIds.Add($questId)
        if (-not $entry.Optional) { $previousRequired = $questId }
    }
    $lines.Add("`t]")
    $lines.Add('}')
    [IO.File]::WriteAllLines((Join-Path $chapterRoot "$($chapter.Key).snbt"), $lines, $utf8)
    $chapterCounts.Add([pscustomobject]@{ Chapter = $chapter.Title; File = "$($chapter.Key).snbt"; Quests = $chapter.Entries.Count })
}

# Validate IDs, dependencies, descriptions, count, graph shape, and preservation
# of every definition ID in the local v1.0.0 baseline.
$questIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$allIds = [Collections.Generic.List[string]]::new()
$dependencies = [Collections.Generic.List[string]]::new()
$taskIds = [Collections.Generic.List[string]]::new()
$rewardIds = [Collections.Generic.List[string]]::new()
$questDependencyMap = @{}
$manualQuests = 0
$automaticQuests = 0
$itemIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($file in Get-ChildItem -LiteralPath $stageRoot -Recurse -File -Filter '*.snbt') {
    $text = [IO.File]::ReadAllText($file.FullName)
    foreach ($match in [regex]::Matches($text, '(?m)^\t\t\tid:\s*"([0-9A-F]{16})"')) { [void]$questIds.Add($match.Groups[1].Value) }
    foreach ($match in [regex]::Matches($text, '(?m)^\s*id:\s*"([0-9A-F]{16})"')) { $allIds.Add($match.Groups[1].Value) }
    foreach ($match in [regex]::Matches($text, '(?m)^\t\t\tdependencies:\s*\[([^\]]*)\]')) {
        foreach ($dependency in [regex]::Matches($match.Groups[1].Value, '"([0-9A-F]{16})"')) { $dependencies.Add($dependency.Groups[1].Value) }
    }
    foreach ($match in [regex]::Matches($text, '(?m)^\s*item:\s*"([a-z0-9_.-]+:[a-z0-9_./-]+)"')) { [void]$itemIds.Add($match.Groups[1].Value) }
    if ($file.Directory.Name -eq 'chapters') {
        foreach ($block in [regex]::Matches($text, '(?ms)^\t\t\{\r?\n.*?^\t\t\}')) {
            $questIdMatch = [regex]::Match($block.Value, '(?m)^\t\t\tid:\s*"([0-9A-F]{16})"')
            $blockDependencies = @(
                [regex]::Matches($block.Value, '(?m)^\t\t\tdependencies:\s*\[([^\]]*)\]') |
                    ForEach-Object { [regex]::Matches($_.Groups[1].Value, '"([0-9A-F]{16})"') } |
                    ForEach-Object { $_.Groups[1].Value }
            )
            if ($questIdMatch.Success) { $questDependencyMap[$questIdMatch.Groups[1].Value] = $blockDependencies }

            $taskArea = [regex]::Match($block.Value, '(?ms)^\t\t\ttasks:\s*(.*?)(?=^\t\t\ttitle:)')
            foreach ($match in [regex]::Matches($taskArea.Value, '(?m)^\s*id:\s*"([0-9A-F]{16})"')) {
                $taskIds.Add($match.Groups[1].Value)
            }
            $rewardArea = [regex]::Match($block.Value, '(?ms)^\t\t\trewards:\s*(.*?)(?=^\t\t\t(?:subtitle|tasks):)')
            foreach ($match in [regex]::Matches($rewardArea.Value, '(?m)^\s*id:\s*"([0-9A-F]{16})"')) {
                $rewardIds.Add($match.Groups[1].Value)
            }
            if ($taskArea.Value -match 'type:\s*"checkmark"') { $manualQuests++ } else { $automaticQuests++ }
        }
    }
}

$duplicateIds = @($allIds | Group-Object | Where-Object Count -gt 1)
$duplicateQuestIds = @($questIds | Group-Object | Where-Object Count -gt 1)
$duplicateTaskIds = @($taskIds | Group-Object | Where-Object Count -gt 1)
$duplicateRewardIds = @($rewardIds | Group-Object | Where-Object Count -gt 1)
$unsafeIds = @($allIds | Where-Object { $_ -match '^[89A-F]' })
$missingDependencies = @($dependencies | Where-Object { -not $questIds.Contains($_) } | Select-Object -Unique)
$chapterFiles = @(Get-ChildItem -LiteralPath $chapterRoot -File -Filter '*.snbt')
if ($chapterFiles.Count -ne 9) { throw "Expected 9 chapters, found $($chapterFiles.Count)." }
if ($questIds.Count -ne 118) { throw "Expected 118 quests, found $($questIds.Count)." }
if ($duplicateIds.Count -gt 0) { throw "Duplicate IDs: $($duplicateIds.Name -join ', ')" }
if ($duplicateQuestIds.Count -gt 0) { throw "Duplicate quest IDs: $($duplicateQuestIds.Name -join ', ')" }
if ($duplicateTaskIds.Count -gt 0) { throw "Duplicate task IDs: $($duplicateTaskIds.Name -join ', ')" }
if ($duplicateRewardIds.Count -gt 0) { throw "Duplicate reward IDs: $($duplicateRewardIds.Name -join ', ')" }
if ($unsafeIds.Count -gt 0) { throw "FTB-unsafe signed IDs: $($unsafeIds -join ', ')" }
if ($missingDependencies.Count -gt 0) { throw "Unresolved dependencies: $($missingDependencies -join ', ')" }

# Kahn's algorithm: if every quest is visited, the dependency graph is acyclic
# and every quest is reachable from at least one visible root.
$inDegree = @{}
$dependents = @{}
foreach ($questId in $questIds) { $inDegree[$questId] = 0; $dependents[$questId] = [Collections.Generic.List[string]]::new() }
foreach ($questId in $questIds) {
    foreach ($dependency in @($questDependencyMap[$questId])) {
        if (-not $questIds.Contains($dependency)) { continue }
        $inDegree[$questId]++
        $dependents[$dependency].Add($questId)
    }
}
$queue = [Collections.Generic.Queue[string]]::new()
foreach ($questId in $questIds) { if ($inDegree[$questId] -eq 0) { $queue.Enqueue($questId) } }
$visitedQuestIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
while ($queue.Count -gt 0) {
    $questId = $queue.Dequeue()
    if (-not $visitedQuestIds.Add($questId)) { continue }
    foreach ($dependent in $dependents[$questId]) {
        $inDegree[$dependent]--
        if ($inDegree[$dependent] -eq 0) { $queue.Enqueue($dependent) }
    }
}
$cyclicOrUnreachable = @($questIds | Where-Object { -not $visitedQuestIds.Contains($_) })
if ($cyclicOrUnreachable.Count -gt 0) { throw "Cyclic or unreachable quests: $($cyclicOrUnreachable -join ', ')" }

$newDefinitionIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($id in $allIds) { [void]$newDefinitionIds.Add($id) }

# Preserve every quest/chapter/group/task/reward ID from the local v1.0.0 tag.
# This is deliberately Git-based: validation never opens the production world or
# reads live FTB Quests team/player progress.
$baselineDefinitionIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$baselineComparison = 'v1.0.0 tag not available'
$tag = @(& git -C $projectRootResolved tag --list 'v1.0.0' 2>$null)
if ($tag.Count -gt 0) {
    $baselinePaths = @(& git -C $projectRootResolved ls-tree -r --name-only 'v1.0.0' -- 'payload/both/config/ftbquests/quests' 2>$null)
    foreach ($path in $baselinePaths) {
        if ($path -notlike '*.snbt') { continue }
        $baselineText = (@(& git -C $projectRootResolved show "v1.0.0:$path" 2>$null) -join "`n")
        foreach ($match in [regex]::Matches($baselineText, '(?m)^\s*id:\s*"([0-9A-F]{16})"')) {
            [void]$baselineDefinitionIds.Add($match.Groups[1].Value)
        }
    }
    $baselineComparison = 'compared with local v1.0.0 tag'
}
$missingBaselineIds = @($baselineDefinitionIds | Where-Object { -not $newDefinitionIds.Contains($_) })
$intentionallyRemovedBaselineIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if ($tag.Count -gt 0) {
    $removedPaths = @('payload/both/config/ftbquests/quests/chapters/tinkers_deferred.snbt')
    foreach ($removedPath in $removedPaths) {
        $removedText = (@(& git -C $projectRootResolved show "v1.0.0:$removedPath" 2>$null) -join "`n")
        foreach ($match in [regex]::Matches($removedText, '(?m)^\s*id:\s*"([0-9A-F]{16})"')) {
            [void]$intentionallyRemovedBaselineIds.Add($match.Groups[1].Value)
        }
    }
    $homesteadText = (@(& git -C $projectRootResolved show 'v1.0.0:payload/both/config/ftbquests/quests/chapters/homestead.snbt' 2>$null) -join "`n")
    $botanyBlock = [regex]::Match($homesteadText, '(?ms)^\t\t\{\r?\n.*?^\t\t\}')
    foreach ($candidateBlock in [regex]::Matches($homesteadText, '(?ms)^\t\t\{\r?\n.*?^\t\t\}')) {
        if ($candidateBlock.Value -notmatch 'id:\s*"4DC3990D720C9351"') { continue }
        $botanyBlock = $candidateBlock
        foreach ($match in [regex]::Matches($botanyBlock.Value, '(?m)^\s*id:\s*"([0-9A-F]{16})"')) {
            [void]$intentionallyRemovedBaselineIds.Add($match.Groups[1].Value)
        }
    }
}
$unexpectedMissingBaselineIds = @($missingBaselineIds | Where-Object { -not $intentionallyRemovedBaselineIds.Contains($_) })
if ($unexpectedMissingBaselineIds.Count -gt 0) {
    throw "Unexpected v1.0.0 quest definition IDs would be lost: $($unexpectedMissingBaselineIds -join ', ')"
}

$existingQuestIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($id in $legacyBlocks.Keys) { [void]$existingQuestIds.Add($id) }
$removedLegacyQuestIds = @($existingQuestIds | Where-Object { -not $selectedExistingIds.Contains($_) })

$report = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    source = 'audit/questbook-legacy-1.8.0'
    chapterCount = $chapterFiles.Count
    questCount = $questIds.Count
    taskIdCount = @($taskIds | Select-Object -Unique).Count
    rewardIdCount = @($rewardIds | Select-Object -Unique).Count
    manualCheckmarkQuests = $manualQuests
    automaticDetectionQuests = $automaticQuests
    existingQuestBlocksRetained = $selectedExistingIds.Count
    legacyQuestBlocksRemovedFromVisibleGuide = $removedLegacyQuestIds.Count
    baselineIdComparison = $baselineComparison
    baselineDefinitionIdsFound = $baselineDefinitionIds.Count
    baselineDefinitionIdsPreserved = $baselineDefinitionIds.Count - $missingBaselineIds.Count
    intentionallyRemovedBaselineIds = $missingBaselineIds.Count
    unexpectedMissingBaselineIds = $unexpectedMissingBaselineIds.Count
    duplicateIds = $duplicateIds.Count
    duplicateQuestIds = $duplicateQuestIds.Count
    duplicateTaskIds = $duplicateTaskIds.Count
    duplicateRewardIds = $duplicateRewardIds.Count
    unsafeSignedIds = $unsafeIds.Count
    unresolvedDependencies = $missingDependencies.Count
    cyclicOrUnreachableQuests = $cyclicOrUnreachable.Count
    referencedItemIds = $itemIds.Count
    chapters = @($chapterCounts)
    absentModTutorialContentRemoved = @('Botany Pots', 'Botany Trees', "Tinkers' Construct")
    explicitlyNotAdded = @(
        'Immersive Engineering',
        'Create Crafts & Additions',
        'Create Diesel Generators',
        "Create Tinkers' Compat",
        'Create Contraption Terminals',
        'Bells & Whistles'
    )
}
[IO.File]::WriteAllText((Join-Path $projectRootResolved 'audit\questbook-validation.json'), (($report | ConvertTo-Json -Depth 8) + "`r`n"), $utf8)
[IO.File]::WriteAllLines((Join-Path $projectRootResolved 'audit\questbook-item-ids.txt'), @($itemIds | Sort-Object), $utf8)

$chapterDefaultMods = @{
    welcome = 'guide'; first_days = 'minecraft'; homestead = 'farmersdelight + integrations'
    create_basics = 'create + installed addons'
    travel_storage = 'mixed storage'; new_horizons = 'mixed exploration'
    archaeology = 'betterarcheology + separate optional systems'; vehicles = 'mixed transport'
    endgame = 'mixed adventure'
}
$questAuditRows = [Collections.Generic.List[object]]::new()
foreach ($chapter in $chapters) {
    $chapterPath = Join-Path $chapterRoot "$($chapter.Key).snbt"
    $chapterText = [IO.File]::ReadAllText($chapterPath)
    foreach ($block in [regex]::Matches($chapterText, '(?ms)^\t\t\{\r?\n.*?^\t\t\}')) {
        $questId = [regex]::Match($block.Value, '(?m)^\t\t\tid:\s*"([0-9A-F]{16})"').Groups[1].Value
        $title = [regex]::Match($block.Value, '(?m)^\t\t\ttitle:\s*"((?:\\.|[^"])*)"').Groups[1].Value
        $dependencyText = [regex]::Match($block.Value, '(?m)^\t\t\tdependencies:\s*\[([^\]]*)\]').Groups[1].Value
        $dependencyIds = @([regex]::Matches($dependencyText, '"([0-9A-F]{16})"') | ForEach-Object { $_.Groups[1].Value })
        $taskArea = [regex]::Match($block.Value, '(?ms)^\t\t\ttasks:\s*(.*?)(?=^\t\t\ttitle:)').Value
        $taskTypes = @([regex]::Matches($taskArea, '(?m)^\s*type:\s*"([a-z0-9_.-]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        $taskTargets = @([regex]::Matches($taskArea, '(?m)^\s*(?:item|advancement|dimension|entity|tag):\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        $targetNamespaces = @($taskTargets | Where-Object { $_ -match ':' } | ForEach-Object { ($_ -split ':', 2)[0] } | Select-Object -Unique)
        $rewardArea = [regex]::Match($block.Value, '(?ms)^\t\t\trewards:\s*(.*?)(?=^\t\t\t(?:subtitle|tasks):)').Value
        $rewardTypes = @([regex]::Matches($rewardArea, '(?m)^\s*type:\s*"([a-z0-9_.-]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        $rewardItems = @([regex]::Matches($rewardArea, '(?m)^\s*item:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        $verification = if ($chapter.Key -eq 'tinkers_deferred') {
            'deferred_not_installed'
        }
        elseif ($taskTypes -contains 'checkmark') {
            'definition_valid; manual_client_completion_required'
        }
        else {
            'definition_valid; automated_task_target_pending_runtime_client_test'
        }
        $notes = if ($chapter.Key -eq 'archaeology' -and $taskTypes -contains 'checkmark') {
            'Keep namespaces separate; manual recipe/progression confirmation retained.'
        }
        elseif ($block.Value -match '\[OPTIONAL SIDE QUEST\]') { 'Optional side quest.' }
        else { 'Core guidance quest; recipes are not gated.' }
        $questAuditRows.Add([pscustomobject][ordered]@{
            chapter = $chapter.Title
            quest_id = $questId
            title = $title.Replace('\"', '"')
            mod_id = if ($targetNamespaces.Count -gt 0) { $targetNamespaces -join ' + ' } else { $chapterDefaultMods[$chapter.Key] }
            task_type = if ($taskTypes.Count -gt 0) { $taskTypes -join ' + ' } else { 'none' }
            task_target = $taskTargets -join ' + '
            dependencies = $dependencyIds -join ' + '
            optional = [bool]($block.Value -match '\[OPTIONAL SIDE QUEST\]')
            reward = (@($rewardTypes) + @($rewardItems) | Where-Object { $_ }) -join ' + '
            verification_status = $verification
            notes = $notes
        })
    }
}
$questAuditCsv = @($questAuditRows | ConvertTo-Csv -NoTypeInformation)
[IO.File]::WriteAllLines((Join-Path $projectRootResolved 'audit\quests.csv'), $questAuditCsv, $utf8)

if ($Deploy) {
    $payloadQuestRoot = [IO.Path]::GetFullPath((Join-Path $projectRootResolved 'payload\both\config\ftbquests\quests'))
    $metadataQuestRoot = [IO.Path]::GetFullPath((Join-Path $projectRootResolved 'packwiz\config\ftbquests\quests'))
    $expectedPayload = [IO.Path]::GetFullPath((Join-Path $projectRootResolved 'payload\both\config\ftbquests\quests'))
    $expectedMetadata = [IO.Path]::GetFullPath((Join-Path $projectRootResolved 'packwiz\config\ftbquests\quests'))
    if (-not $payloadQuestRoot.Equals($expectedPayload, [StringComparison]::OrdinalIgnoreCase) -or
        -not $metadataQuestRoot.Equals($expectedMetadata, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing to deploy outside the managed FTB Quests paths.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'data.snbt'))) {
        throw 'Refusing to replace the managed quest book without its preserved backup.'
    }
    if (Test-Path -LiteralPath $payloadQuestRoot) { Remove-Item -LiteralPath $payloadQuestRoot -Recurse -Force }
    if (Test-Path -LiteralPath $metadataQuestRoot) { Remove-Item -LiteralPath $metadataQuestRoot -Recurse -Force }
    Copy-Item -LiteralPath $stageRoot -Destination $payloadQuestRoot -Recurse

    $settings = Get-Content -LiteralPath (Join-Path $projectRootResolved 'project-settings.json') -Raw | ConvertFrom-Json
    $rawBase = ([string]$settings.rawRepositoryBaseUrl).TrimEnd('/')
    foreach ($file in Get-ChildItem -LiteralPath $payloadQuestRoot -Recurse -File -Filter '*.snbt') {
        $relative = $file.FullName.Substring($payloadQuestRoot.Length).TrimStart('\').Replace('\', '/')
        $destination = "config/ftbquests/quests/$relative"
        $payloadRelative = "both/$destination"
        $encoded = (($payloadRelative -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
        $metadataPath = Join-Path $metadataQuestRoot (($relative + '.pw.toml').Replace('/', '\'))
        New-Item -ItemType Directory -Path (Split-Path -Parent $metadataPath) -Force | Out-Null
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $metadata = @(
            "name = `"Managed config: ftbquests/quests/$relative`"",
            "filename = `"$([IO.Path]::GetFileName($relative))`"",
            'side = "both"',
            '',
            '[download]',
            "url = `"$rawBase/payload/$encoded`"",
            'hash-format = "sha256"',
            "hash = `"$hash`""
        ) -join "`n"
        [IO.File]::WriteAllText($metadataPath, ($metadata + "`n"), $utf8)
    }
    & (Join-Path $PSScriptRoot 'Update-PackMetadata.ps1') -ProjectRoot $projectRootResolved

    $managedAuditPath = Join-Path $projectRootResolved 'audit\managed-files.csv'
    if (Test-Path -LiteralPath $managedAuditPath -PathType Leaf) {
        $managedRows = @(
            Import-Csv -LiteralPath $managedAuditPath |
                Where-Object { $_.Path -notlike 'config/ftbquests/quests/*' }
        )
        foreach ($file in Get-ChildItem -LiteralPath $payloadQuestRoot -Recurse -File -Filter '*.snbt') {
            $relative = $file.FullName.Substring($payloadQuestRoot.Length).TrimStart('\').Replace('\', '/')
            $managedRows += [pscustomobject]@{
                Path = "config/ftbquests/quests/$relative"
                Side = 'both'
                Source = 'generated by scripts/Build-BeginnerQuestBook.ps1'
                Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                Reason = 'Pack-specific FTB Quests definitions; required on server and client for synchronized guidance.'
            }
        }
        $csvLines = @($managedRows | Sort-Object Path | ConvertTo-Csv -NoTypeInformation)
        [IO.File]::WriteAllLines($managedAuditPath, $csvLines, $utf8)
    }

    $summaryPath = Join-Path $projectRootResolved 'audit\summary.json'
    if (Test-Path -LiteralPath $summaryPath -PathType Leaf) {
        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
        $summary.generatedAt = (Get-Date).ToString('o')
        $summary.managedPayloadFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRootResolved 'payload') -Recurse -File).Count
        [IO.File]::WriteAllText($summaryPath, (($summary | ConvertTo-Json -Depth 10) + "`r`n"), $utf8)
    }
}

$report | ConvertTo-Json -Depth 8
