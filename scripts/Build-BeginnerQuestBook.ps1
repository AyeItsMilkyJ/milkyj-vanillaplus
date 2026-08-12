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
$liveProgressRoot = 'C:\Users\MilkyJ\Desktop\Minecraft Server\world\ftbquests'

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

# These are the 120 useful quests shown to players. Existing blocks retain their
# quest/task/reward IDs so every saved individual quest completion still matches.
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
        (Existing '1885CF9658AB663D')
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
        (Existing '22B69CA315389C48'),
        (NewLesson 'botany_deferred' 'Botany Pots and Botany Trees: Not Installed Yet' @(
            'What this is: Botany Pots and Botany Trees are separate content mods that can grow crops or trees inside special pots. They are not installed in this release, even though an old config or online video may mention them.',
            'Why it matters: JEI cannot show recipes for a mod that is not present. Do not waste time searching for a missing pot, hopping bonsai, soil tier, or tree pot.',
            'How to begin now: use ordinary fields, Farmer''s Delight crops, bees, and the Serene Seasons guidance in this chapter. Search JEI with an at-sign followed by the mod name to confirm what is really loaded.',
            'What comes next: this branch remains optional until the group deliberately approves and tests those mods in a later content update.'
        ) $true 0)
    )),
    (Chapter 'tinkers_deferred' "Tinkers' Construct for Absolute Idiots" 'minecraft:lava_bucket' 'systems' '' @(
        (NewLesson 'not_installed' "Tinkers' Construct Is Not Installed" @(
            'What this is: Tinkers'' Construct is a modular tool and foundry mod. Mantle is installed as a library for other content, but the Tinkers'' Construct mod jar itself is not in this pack.',
            'Why it matters: leftover tconstruct config files do not create tool stations, grout, melters, smelteries, casts, modifiers, or recipes. A tutorial for another pack will therefore lead to items that do not exist here.',
            'How to check: clear JEI, search for at-tconstruct, and confirm that no Tinkers item group appears. Do not build a multiblock from an old video and assume the server is broken.',
            'What comes next: use the ordinary tool, enchanting, relic, and Create paths until a future update explicitly adds and validates Tinkers.'
        ) $false 0),
        (NewLesson 'old_configs' 'Old Configs Are Not a Mod' @(
            'What this is: configuration files can remain after a mod is removed. They are harmless text until the matching mod is loaded.',
            'Why it matters: this pack preserves uncertain files instead of deleting them automatically, so a tconstruct config is evidence of history, not evidence of current gameplay.',
            'How to begin troubleshooting: trust the Mods screen and JEI first, then the mods folder. A missing jar means there are no valid Tinkers item IDs or recipes to put into automatic quests.',
            'What comes next: this chapter intentionally uses checkmarks and zero rewards so nobody is sent hunting for impossible materials.'
        ) $false 0),
        (NewLesson 'future_validation' 'What Must Be Tested Before Tinkers Returns' @(
            'What this is: a release checklist for any later Tinkers proposal: a Forge 1.20.1 build, its matching Mantle dependency, server and client startup, JEI recipes, world-safe ore generation, and multiplayer casting.',
            'Why it matters: grout, fuel, faucets, casting tables, smeltery controllers, tool parts, repairs, and modifiers change between versions. A quest must describe the installed recipes, not a remembered version.',
            'How to begin later: test the melter first, then a minimum smeltery, one cast, one metal tool, repairs, and one modifier in a disposable world before the live server receives anything.',
            'What comes next: only after those checks pass should this parked chapter become real progression.'
        ) $false 0)
    )),
    (Chapter 'create_basics' 'Create Without Having a Brain Aneurysm' 'create:large_cogwheel' 'systems' 'create_basics' @(
        (Existing '4201CE5BFBBC062D'),
        (Existing '1AC77EEB81F556DC'),
        (Existing '09CB7E54442B5B87'),
        (Existing '2250D40C885B51F2'),
        (Existing '0D9196F06BAA6EB5'),
        (Existing '653A5307BAFA7BE8'),
        (Existing '4164748FA85EDE6A'),
        (Existing '3119C51ADD982ABF'),
        (Existing '449599EDF06A1DB9'),
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

$descriptionOverrides = @{
    '18C0AF7F5C17CAB7' = @(
        'What this is: the Field Guide explains progression, JEI explains recipes, Jade identifies the block in front of you, and Patchouli manuals provide the deep reference written by a mod author.',
        'Why it matters: hover an item and read the mod name in its tooltip before searching. In JEI, type an at-sign followed by that mod name to isolate its items and avoid mixing similarly named systems.',
        'How to begin: open a Patchouli manual like the Aether Book of Lore or Alex''s Caves Cave Book from your inventory and use its contents or search page. Manuals are ordinary items, not another keybind-only screen.',
        'What comes next: use the quest book for order, JEI for exact recipes, Patchouli for reference, Jade for live state, and Create Ponder for animated machinery.'
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
    $lines.Add("`tquests: [")

    $previousRequired = ''
    for ($entryIndex = 0; $entryIndex -lt $chapter.Entries.Count; $entryIndex++) {
        $entry = $chapter.Entries[$entryIndex]
        $row = [math]::Floor($entryIndex / 6)
        $column = $entryIndex % 6
        $xColumn = if (($row % 2) -eq 0) { $column } else { 5 - $column }
        $x = [double]($xColumn * 2)
        $y = [double]($row * 2)
        $dependencies = if ($previousRequired) { @($previousRequired) } else { @() }

        if ($entry.Kind -eq 'existing') {
            if (-not $legacyBlocks.ContainsKey($entry.Id)) { throw "Missing legacy quest block: $($entry.Id)" }
            if (-not $selectedExistingIds.Add($entry.Id)) { throw "Quest selected twice: $($entry.Id)" }
            $block = $legacyBlocks[$entry.Id]
            if ($descriptionOverrides.ContainsKey($entry.Id)) { $block = Set-Description $block $descriptionOverrides[$entry.Id] }
            $block = Set-QuestLayout $block $dependencies $x $y $entry.Optional
            $questId = $entry.Id
        }
        else {
            $created = New-LessonBlock $chapter.Key $entry $dependencies $x $y
            $block = $created.Block
            $questId = $created.Id
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

# Validate IDs, dependencies, descriptions, count, and preservation of all saved
# progress IDs that belonged to individual legacy quest blocks.
$questIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$allIds = [Collections.Generic.List[string]]::new()
$dependencies = [Collections.Generic.List[string]]::new()
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
            $taskArea = [regex]::Match($block.Value, '(?ms)^\t\t\ttasks:\s*\[(.*?)^\t\t\t\]')
            if (-not $taskArea.Success) { $taskArea = [regex]::Match($block.Value, '(?ms)^\t\t\ttasks:\s*\[(.*?)\]\s*$') }
            if ($taskArea.Value -match 'type:\s*"checkmark"') { $manualQuests++ } else { $automaticQuests++ }
        }
    }
}

$duplicateIds = @($allIds | Group-Object | Where-Object Count -gt 1)
$unsafeIds = @($allIds | Where-Object { $_ -match '^[89A-F]' })
$missingDependencies = @($dependencies | Where-Object { -not $questIds.Contains($_) } | Select-Object -Unique)
$chapterFiles = @(Get-ChildItem -LiteralPath $chapterRoot -File -Filter '*.snbt')
if ($chapterFiles.Count -ne 10) { throw "Expected 10 chapters, found $($chapterFiles.Count)." }
if ($questIds.Count -ne 120) { throw "Expected 120 quests, found $($questIds.Count)." }
if ($duplicateIds.Count -gt 0) { throw "Duplicate IDs: $($duplicateIds.Name -join ', ')" }
if ($unsafeIds.Count -gt 0) { throw "FTB-unsafe signed IDs: $($unsafeIds -join ', ')" }
if ($missingDependencies.Count -gt 0) { throw "Unresolved dependencies: $($missingDependencies -join ', ')" }

$progressIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if (Test-Path -LiteralPath $liveProgressRoot -PathType Container) {
    foreach ($file in Get-ChildItem -LiteralPath $liveProgressRoot -File -Filter '*.snbt') {
        foreach ($match in [regex]::Matches([IO.File]::ReadAllText($file.FullName), '(?m)^\s*([0-9A-F]{16}):')) {
            [void]$progressIds.Add($match.Groups[1].Value)
        }
    }
}
$legacyQuestBlockIdsWithProgress = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($legacyBlock in $legacyBlocks.Values) {
    $blockIds = @([regex]::Matches($legacyBlock, '(?m)^\s*id:\s*"([0-9A-F]{16})"') | ForEach-Object { $_.Groups[1].Value })
    if (@($blockIds | Where-Object { $progressIds.Contains($_) }).Count -gt 0) {
        foreach ($id in $blockIds) { if ($progressIds.Contains($id)) { [void]$legacyQuestBlockIdsWithProgress.Add($id) } }
    }
}
$newDefinitionIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($id in $allIds) { [void]$newDefinitionIds.Add($id) }
$missingProgressIds = @($legacyQuestBlockIdsWithProgress | Where-Object { -not $newDefinitionIds.Contains($_) })
if ($missingProgressIds.Count -gt 0) { throw "Saved quest/task progress IDs would be lost: $($missingProgressIds -join ', ')" }

$existingQuestIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($id in $legacyBlocks.Keys) { [void]$existingQuestIds.Add($id) }
$removedLegacyQuestIds = @($existingQuestIds | Where-Object { -not $selectedExistingIds.Contains($_) })

$report = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    source = $sourceRoot
    chapterCount = $chapterFiles.Count
    questCount = $questIds.Count
    manualCheckmarkQuests = $manualQuests
    automaticDetectionQuests = $automaticQuests
    existingQuestBlocksRetained = $selectedExistingIds.Count
    legacyQuestBlocksRemovedFromVisibleGuide = $removedLegacyQuestIds.Count
    savedQuestAndTaskProgressIdsFound = $legacyQuestBlockIdsWithProgress.Count
    savedQuestAndTaskProgressIdsPreserved = $legacyQuestBlockIdsWithProgress.Count - $missingProgressIds.Count
    duplicateIds = $duplicateIds.Count
    unsafeSignedIds = $unsafeIds.Count
    unresolvedDependencies = $missingDependencies.Count
    referencedItemIds = $itemIds.Count
    chapters = @($chapterCounts)
    deferredBecauseNotInstalled = @('Botany Pots', 'Botany Trees', "Tinkers' Construct")
    explicitlyNotAdded = @('Immersive Engineering', 'Create Crafts & Additions')
}
[IO.File]::WriteAllText((Join-Path $projectRootResolved 'audit\questbook-validation.json'), (($report | ConvertTo-Json -Depth 8) + "`r`n"), $utf8)
[IO.File]::WriteAllLines((Join-Path $projectRootResolved 'audit\questbook-item-ids.txt'), @($itemIds | Sort-Object), $utf8)

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
